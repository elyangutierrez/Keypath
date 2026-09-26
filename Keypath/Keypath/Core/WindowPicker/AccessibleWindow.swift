//
//  AccessibleWindow.swift
//  Keypath
//

import AppKit
import ApplicationServices
import CoreGraphics
import OSLog
import ScreenCaptureKit

struct AccessibleWindow: Identifiable {
    /// Position in the current picker order. This is presentation state, not identity.
    let number: Int
    let title: String
    let captureTitle: String?
    let isMinimized: Bool
    let isOnScreen: Bool?
    let frame: CGRect?
    let windowID: CGWindowID?
    let element: AXUIElement?

    var id: Int { number }
}

struct WindowDiscoveryResult {
    let windows: [AccessibleWindow]
    let accessibilityWindowCount: Int
    let coreGraphicsWindowCount: Int
    let shareableWindowCount: Int?
    var evidenceObservedDuringRetries = false

    var hasWindowEvidence: Bool {
        evidenceObservedDuringRetries
            || accessibilityWindowCount > 0
            || coreGraphicsWindowCount > 0
            || (shareableWindowCount ?? 0) > 0
    }

    static let empty = WindowDiscoveryResult(
        windows: [],
        accessibilityWindowCount: 0,
        coreGraphicsWindowCount: 0,
        shareableWindowCount: 0
    )
}

@MainActor
enum ApplicationWindowAccessibility {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Keypath",
        category: "WindowDiscovery"
    )

    static func windows(for application: NSRunningApplication) async -> [AccessibleWindow] {
        await discoverWindows(for: application).windows
    }

    static func discoverWindows(for application: NSRunningApplication) async -> WindowDiscoveryResult {
        guard !Task.isCancelled, !application.isTerminated else {
            return WindowDiscoveryResult(
                windows: [],
                accessibilityWindowCount: 0,
                coreGraphicsWindowCount: 0,
                shareableWindowCount: nil
            )
        }

        let shareableWindows: [SCWindow]?
        if let shareableContent = try? await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        ) {
            shareableWindows = shareableContent.windows.filter {
                $0.owningApplication?.processID == application.processIdentifier
            }
        } else {
            shareableWindows = nil
        }

        // The process can exit while ScreenCaptureKit is loading its snapshot.
        // Do not surface a stale list for an application that no longer exists.
        guard !Task.isCancelled, !application.isTerminated else {
            return WindowDiscoveryResult(
                windows: [],
                accessibilityWindowCount: 0,
                coreGraphicsWindowCount: 0,
                shareableWindowCount: shareableWindows?.count
            )
        }

        let pid = application.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var axWindowsValue: CFTypeRef?
        var axWindows: [AXUIElement]
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &axWindowsValue
        ) == .success,
           let value = axWindowsValue as? [AXUIElement] {
            axWindows = value
        } else {
            axWindows = []
        }

        // AXWindows should contain the app's windows, but some apps omit a
        // miniaturized main window from that array. AXMainWindow is another
        // supported app-level reference; admit it only when its minimized
        // state and window role identify it as a restorable target.
        var mainWindowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindowValue
        ) == .success,
           let mainWindowValue,
           CFGetTypeID(mainWindowValue) == AXUIElementGetTypeID() {
            let mainWindow = unsafeDowncast(mainWindowValue, to: AXUIElement.self)
            if minimizedState(of: mainWindow) == true,
               canRestoreMinimizedWindow(mainWindow) {
                axWindows.append(mainWindow)
            }
        }

        var focusedWindowValue: CFTypeRef?
        let focusedElement: AXUIElement? = {
            guard AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedWindowAttribute as CFString,
                &focusedWindowValue
            ) == .success,
                  let focusedWindowValue,
                  CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeDowncast(focusedWindowValue, to: AXUIElement.self)
        }()

        var orderedAXWindows = deduplicatedAXWindows(axWindows)
        if let focusedElement, windowKind(of: focusedElement) != .notAWindow {
            if let focusedIndex = orderedAXWindows.firstIndex(where: {
                sameWindow($0, focusedElement)
            }) {
                let focused = orderedAXWindows.remove(at: focusedIndex)
                orderedAXWindows.insert(focused, at: 0)
            } else {
                orderedAXWindows.insert(focusedElement, at: 0)
                orderedAXWindows = deduplicatedAXWindows(orderedAXWindows)
            }
        }

        let accessibilityWindowCount = orderedAXWindows.count
        let cgWindows = CoreGraphicsWindowRecord.windows(for: pid)
        var consumedCGIDs = Set<CGWindowID>()
        var mergedWindowIDs = Set<CGWindowID>()
        var merged: [WindowDraft] = []

        for element in orderedAXWindows {
            let kind = windowKind(of: element)
            guard kind != .notAWindow else { continue }

            let axWindowID = WindowPlatformBridge.windowID(for: element)
            if let axWindowID, mergedWindowIDs.contains(axWindowID) { continue }
            if merged.contains(where: { draft in
                guard let existingElement = draft.element else { return false }
                return CFEqual(existingElement as CFTypeRef, element as CFTypeRef)
            }) {
                continue
            }
            let title = titleAttribute(of: element)
            let frame = frameAttribute(of: element)
            let minimized = minimizedAttribute(of: element)

            let matchingCGWindow = axWindowID.flatMap { id in
                cgWindows.first(where: { $0.windowID == id && !consumedCGIDs.contains($0.windowID) })
            } ?? uniquelyMatchingCGWindow(
                title: title,
                frame: frame,
                minimized: minimized,
                in: cgWindows,
                excluding: consumedCGIDs
            )

            if kind == .confirmedWindowWithoutSubrole && minimized {
                // A minimized AXWindow remains a strong window signal even
                // when Terminal omits AXSubrole and no window-server record
                // is available for its miniaturized window.
                if let matchingCGWindow {
                    consumedCGIDs.insert(matchingCGWindow.windowID)
                }
                if let windowID = axWindowID ?? matchingCGWindow?.windowID {
                    mergedWindowIDs.insert(windowID)
                }
                merged.append(WindowDraft(
                    title: title ?? matchingCGWindow?.title ?? "Window",
                    captureTitle: title ?? matchingCGWindow?.title,
                    isMinimized: true,
                    isOnScreen: matchingCGWindow?.isOnScreen,
                    frame: frame ?? matchingCGWindow?.frame,
                    windowID: axWindowID ?? matchingCGWindow?.windowID,
                    spaceIDs: (axWindowID ?? matchingCGWindow?.windowID).flatMap {
                        WindowPlatformBridge.managedSpaces(for: $0)
                    },
                    element: element
                ))
                continue
            }

            if kind == .uncertain || kind == .confirmedWindowWithoutSubrole {
                // If AX cannot confirm a standard window subrole, keep the
                // strict cross-API identity and geometry checks unless the
                // minimized state independently confirms a target above.
                guard let axWindowID,
                      let matchingCGWindow,
                      axWindowID == matchingCGWindow.windowID,
                      let frame,
                      let shareableWindows,
                      let shareableWindow = confirmedShareableWindow(
                        for: matchingCGWindow,
                        processIdentifier: pid,
                        in: shareableWindows
                      ),
                      framesMatch(frame, matchingCGWindow.frame),
                      let shareableTitle = nonemptyTitle(shareableWindow.title) else {
                    continue
                }
                mergedWindowIDs.insert(axWindowID)
                consumedCGIDs.insert(matchingCGWindow.windowID)
                merged.append(WindowDraft(
                    title: title ?? shareableTitle,
                    captureTitle: title ?? shareableTitle,
                    isMinimized: minimized,
                    isOnScreen: matchingCGWindow.isOnScreen,
                    frame: frame,
                    windowID: axWindowID,
                    spaceIDs: WindowPlatformBridge.managedSpaces(for: axWindowID),
                    element: element
                ))
                continue
            }

            if let matchingCGWindow {
                consumedCGIDs.insert(matchingCGWindow.windowID)
            }
            if let windowID = axWindowID ?? matchingCGWindow?.windowID {
                mergedWindowIDs.insert(windowID)
            }

            merged.append(WindowDraft(
                title: title ?? matchingCGWindow?.title ?? "Window",
                captureTitle: title ?? matchingCGWindow?.title,
                isMinimized: minimized,
                isOnScreen: matchingCGWindow?.isOnScreen,
                frame: frame ?? matchingCGWindow?.frame,
                windowID: axWindowID ?? matchingCGWindow?.windowID,
                spaceIDs: (axWindowID ?? matchingCGWindow?.windowID).flatMap {
                    WindowPlatformBridge.managedSpaces(for: $0)
                },
                element: element
            ))
        }

        // CG's list is ordered front-to-back. A CG-only window is included only
        // when ScreenCaptureKit confirms its identity and SkyLight confirms it
        // is an ordered-in root window on a managed Space.
        for cgWindow in cgWindows where !consumedCGIDs.contains(cgWindow.windowID) {
            guard !mergedWindowIDs.contains(cgWindow.windowID),
                  let shareableWindows,
                  let shareableWindow = confirmedShareableWindow(
                    for: cgWindow,
                    processIdentifier: pid,
                    in: shareableWindows
                  ),
                  let shareableTitle = nonemptyTitle(shareableWindow.title) else {
                continue
            }

            guard let spaceIDs = WindowPlatformBridge.managedSpaces(for: cgWindow.windowID),
                  WindowPlatformBridge.isOrderedRootWindow(cgWindow.windowID) else {
                continue
            }

            let duplicatesAccessibilityWindow = merged.contains { draft in
                guard draft.captureTitle == shareableTitle,
                      let draftFrame = draft.frame,
                      framesSubstantiallyOverlap(draftFrame, cgWindow.frame),
                      let accessibilitySpaceIDs = draft.spaceIDs else {
                    return false
                }
                return !spaceIDs.isDisjoint(with: accessibilitySpaceIDs)
            }
            guard !duplicatesAccessibilityWindow else { continue }

            consumedCGIDs.insert(cgWindow.windowID)
            mergedWindowIDs.insert(cgWindow.windowID)
            merged.append(WindowDraft(
                title: shareableTitle,
                captureTitle: shareableTitle,
                isMinimized: false,
                isOnScreen: cgWindow.isOnScreen,
                frame: cgWindow.frame,
                windowID: cgWindow.windowID,
                spaceIDs: spaceIDs,
                element: nil
            ))
        }

        guard !Task.isCancelled, !application.isTerminated else {
            return WindowDiscoveryResult(
                windows: [],
                accessibilityWindowCount: accessibilityWindowCount,
                coreGraphicsWindowCount: cgWindows.count,
                shareableWindowCount: shareableWindows?.count
            )
        }

        let windows = merged.enumerated().map { index, window in
            AccessibleWindow(
                number: index + 1,
                title: window.title.isEmpty ? "Window \(index + 1)" : window.title,
                captureTitle: window.captureTitle,
                isMinimized: window.isMinimized,
                isOnScreen: window.isOnScreen,
                frame: window.frame,
                windowID: window.windowID,
                element: window.element
            )
        }

        logger.debug(
            "Window discovery status=complete ax=\(accessibilityWindowCount, privacy: .public) cg=\(cgWindows.count, privacy: .public) sc=\(shareableWindows?.count ?? -1, privacy: .public) included=\(windows.count, privacy: .public) minimized=\(windows.filter(\.isMinimized).count, privacy: .public)"
        )

        return WindowDiscoveryResult(
            windows: windows,
            accessibilityWindowCount: accessibilityWindowCount,
            coreGraphicsWindowCount: cgWindows.count,
            shareableWindowCount: shareableWindows?.count
        )
    }

    static func discoverWindowsAfterActivation(
        for application: NSRunningApplication,
        maximumAttempts: Int = 4,
        pollingInterval: Duration = .milliseconds(180),
        sleep: (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) async -> WindowDiscoveryResult {
        await retryWindowDiscoveryAfterActivation(
            maximumAttempts: maximumAttempts,
            pollingInterval: pollingInterval,
            discover: { await discoverWindows(for: application) },
            sleep: sleep
        )
    }

    static func retryWindowDiscoveryAfterActivation(
        maximumAttempts: Int = 4,
        pollingInterval: Duration = .milliseconds(180),
        discover: () async -> WindowDiscoveryResult,
        sleep: (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) async -> WindowDiscoveryResult {
        let attempts = max(1, maximumAttempts)
        var latest = await discover()
        var observedWindowEvidence = latest.hasWindowEvidence
        logger.debug(
            "Post-activation discovery attempt=1 ax=\(latest.accessibilityWindowCount, privacy: .public) cg=\(latest.coreGraphicsWindowCount, privacy: .public) sc=\(latest.shareableWindowCount ?? -1, privacy: .public) included=\(latest.windows.count, privacy: .public)"
        )

        guard latest.windows.isEmpty else {
            latest.evidenceObservedDuringRetries = observedWindowEvidence
            return latest
        }
        for attempt in 2..<(attempts + 1) {
            guard !Task.isCancelled else { return latest }
            do {
                try await sleep(pollingInterval)
            } catch {
                return latest
            }
            latest = await discover()
            observedWindowEvidence = observedWindowEvidence || latest.hasWindowEvidence
            logger.debug(
                "Post-activation discovery attempt=\(attempt, privacy: .public) ax=\(latest.accessibilityWindowCount, privacy: .public) cg=\(latest.coreGraphicsWindowCount, privacy: .public) sc=\(latest.shareableWindowCount ?? -1, privacy: .public) included=\(latest.windows.count, privacy: .public)"
            )
            if !latest.windows.isEmpty {
                latest.evidenceObservedDuringRetries = observedWindowEvidence
                return latest
            }
        }
        latest.evidenceObservedDuringRetries = observedWindowEvidence
        return latest
    }

    private static func confirmedShareableWindow(
        for cgWindow: CoreGraphicsWindowRecord,
        processIdentifier: pid_t,
        in windows: [SCWindow]
    ) -> SCWindow? {
        let matches = windows.filter { window in
            window.owningApplication?.processID == processIdentifier
                && window.windowID == cgWindow.windowID
                && framesMatch(cgWindow.frame, window.frame)
                && nonemptyTitle(window.title) != nil
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func nonemptyTitle(_ title: String?) -> String? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }
        return title
    }

    private static func sameWindow(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
        if CFEqual(lhs as CFTypeRef, rhs as CFTypeRef) { return true }
        guard let leftID = WindowPlatformBridge.windowID(for: lhs),
              let rightID = WindowPlatformBridge.windowID(for: rhs) else {
            return false
        }
        return leftID == rightID
    }

    private static func deduplicatedAXWindows(_ windows: [AXUIElement]) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var seenIDs = Set<CGWindowID>()

        for window in windows {
            if result.contains(where: { sameWindow($0, window) }) {
                continue
            }
            if let windowID = WindowPlatformBridge.windowID(for: window),
               !seenIDs.insert(windowID).inserted {
                continue
            }
            result.append(window)
        }

        return result
    }

    enum ActivationResult: Equatable {
        case activated
        case applicationActivationDenied
        case applicationDidNotBecomeFrontmost
        case windowMissing
        case focusFailed
        case cancelled
    }

    /// Minimizes the exact window when its application is currently frontmost.
    /// Read AXMinimized live here instead of relying on the HUD's cached path state.
    static func minimizeIfActive(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) -> Bool {
        guard !application.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
              let element = window.element,
              minimizedState(of: element) == false else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            kCFBooleanTrue
        ) == .success
    }

    /// Activates a specific window and confirms that macOS focused that exact
    /// window. Polling is asynchronous so the main actor remains responsive
    /// while the system switches Spaces.
    static func activateAndVerify(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) async -> ActivationResult {
        guard !Task.isCancelled else { return .cancelled }
        guard !application.isTerminated else { return .windowMissing }

        switch windowPresence(window, in: application) {
        case .missing:
            return .windowMissing
        case .unknown:
            return .focusFailed
        case .present:
            break
        }

        // Request restoration before activation when possible. Some apps
        // accept this request without restoring the window until they become
        // active, so check the live state and retry after activation below.
        let initialRestoreRequest = requestRestoreIfMinimized(window)

        let activationResult = await activateApplicationAndWait(application)
        guard activationResult == .activated else {
            return activationResult
        }

        // Always re-read AXMinimized after activation. A setter may report
        // success before the app is active while leaving the window minimized.
        // Retry then wait for the state change before raising or focusing it.
        guard await restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: initialRestoreRequest == .requested,
            cachedMinimized: window.isMinimized,
            minimizedState: {
                guard let element = window.element else { return nil }
                return minimizedState(of: element)
            },
            requestRestore: {
                guard let element = window.element else { return false }
                return AXUIElementSetAttributeValue(
                    element,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanFalse
                ) == .success
            }
        ) else {
            return Task.isCancelled ? .cancelled : .focusFailed
        }
        guard !Task.isCancelled else { return .cancelled }

        guard beginActivation(window, in: application) else {
            if Task.isCancelled { return .cancelled }
            return windowPresence(window, in: application) == .missing
                ? .windowMissing
                : .focusFailed
        }

        if await waitForFocus(of: window, in: application) {
            return .activated
        }
        guard !Task.isCancelled else { return .cancelled }

        // If the private Space switch did not result in exact focus for an AX
        // window, try the public, element-targeted action once and verify again.
        if window.isOnScreen == false,
           let element = window.element,
           activateWithAccessibility(element) {
            if await waitForFocus(of: window, in: application) {
                return .activated
            }
        }

        guard !Task.isCancelled else { return .cancelled }
        return windowPresence(window, in: application) == .missing
            ? .windowMissing
            : .focusFailed
    }

    private static func beginActivation(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) -> Bool {
        if let element = window.element {
            if window.isOnScreen == false,
               let windowID = window.windowID,
               CoreGraphicsWindowRecord.windows(for: application.processIdentifier)
                .contains(where: { $0.windowID == windowID }),
               WindowPlatformBridge.activateWindow(
                   processIdentifier: application.processIdentifier,
                   windowID: windowID
               ) {
                return true
            }
            return activateWithAccessibility(element)
        }

        guard let windowID = window.windowID else { return false }
        guard CoreGraphicsWindowRecord.windows(for: application.processIdentifier)
            .contains(where: { $0.windowID == windowID }) else {
            return false
        }
        return WindowPlatformBridge.activateWindow(
            processIdentifier: application.processIdentifier,
            windowID: windowID
        )
    }

    private static func activateWithAccessibility(_ element: AXUIElement) -> Bool {
        let raiseResult = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return raiseResult == .success || focusResult == .success
    }

    private enum RestoreRequest: Equatable {
        case notNeeded
        case requested
        case failed
    }

    private static func requestRestoreIfMinimized(_ window: AccessibleWindow) -> RestoreRequest {
        requestRestoreIfMinimized(
            cachedMinimized: window.isMinimized,
            minimizedState: {
                guard let element = window.element else { return nil }
                return minimizedState(of: element)
            },
            requestRestore: {
                guard let element = window.element else { return false }
                return AXUIElementSetAttributeValue(
                    element,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanFalse
                ) == .success
            }
        )
    }

    private static func requestRestoreIfMinimized(
        cachedMinimized: Bool,
        minimizedState: () -> Bool?,
        requestRestore: () -> Bool
    ) -> RestoreRequest {
        let currentState = minimizedState()
        guard currentState == true || (currentState == nil && cachedMinimized) else {
            return .notNeeded
        }

        return requestRestore() ? .requested : .failed
    }

    static func restoreIfMinimizedAndWait(
        previouslyAcceptedRestoreRequest: Bool,
        cachedMinimized: Bool,
        minimizedState: () -> Bool?,
        requestRestore: () -> Bool,
        timeout: Duration = .seconds(2),
        pollingInterval: Duration = .milliseconds(60),
        sleep: (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) async -> Bool {
        let request = requestRestoreIfMinimized(
            cachedMinimized: cachedMinimized,
            minimizedState: minimizedState,
            requestRestore: requestRestore
        )
        guard request != .notNeeded else { return true }
        guard request != .failed || previouslyAcceptedRestoreRequest else { return false }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            guard !Task.isCancelled else { return false }
            if minimizedState() == false { return true }
            do {
                try await sleep(pollingInterval)
            } catch {
                return false
            }
        }
        return minimizedState() == false
    }

    private static func activateApplicationAndWait(
        _ application: NSRunningApplication
    ) async -> ActivationResult {
        let requestWasAccepted = application.activate(options: [])
        let initialWait = requestWasAccepted ? Duration.seconds(2) : .milliseconds(250)
        if await waitForApplicationActivation(of: application, timeout: initialWait) {
            return .activated
        }
        guard !Task.isCancelled else { return .cancelled }
        guard !application.isTerminated else { return .windowMissing }

        // Accessory apps such as Keypath can fail to hand off activation from
        // a nonactivating panel. Ask Launch Services to activate the existing
        // app instance, then continue only after that exact PID is frontmost.
        if let applicationURL = application.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration,
                completionHandler: nil
            )

            if await waitForApplicationActivation(of: application) {
                return .activated
            }
            guard !Task.isCancelled else { return .cancelled }
            guard !application.isTerminated else { return .windowMissing }
        }

        return requestWasAccepted ? .applicationDidNotBecomeFrontmost : .applicationActivationDenied
    }

    private static func windowPresence(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) -> WindowPresence {
        let cgWindows = CoreGraphicsWindowRecord.windows(for: application.processIdentifier)
        if let windowID = window.windowID,
           cgWindows.contains(where: { $0.windowID == windowID }) {
            return .present
        }

        // Some apps temporarily omit miniaturized windows from the current
        // window-server snapshot. Accept the captured AX window only when it
        // still identifies itself as a standard window and currently reports
        // its minimized state; cached picker state alone is not enough.
        if isLiveMinimizedAXWindow(window) {
            return .present
        }

        guard let targetElement = window.element else { return .missing }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        ) == .success,
              var currentWindows = windowsValue as? [AXUIElement] else {
            return .unknown
        }

        var mainWindowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindowValue
        ) == .success,
           let mainWindowValue,
           CFGetTypeID(mainWindowValue) == AXUIElementGetTypeID() {
            currentWindows.append(unsafeDowncast(mainWindowValue, to: AXUIElement.self))
        }

        let targetWindowID = window.windowID
        return currentWindows.contains { currentElement in
            if CFEqual(currentElement as CFTypeRef, targetElement as CFTypeRef) {
                return true
            }
            guard let targetWindowID,
                  let currentWindowID = WindowPlatformBridge.windowID(for: currentElement) else {
                return false
            }
            return currentWindowID == targetWindowID
        } ? .present : .missing
    }

    private enum WindowPresence: Equatable {
        case present
        case missing
        case unknown
    }

    private static func isLiveMinimizedAXWindow(_ window: AccessibleWindow) -> Bool {
        guard let element = window.element,
              minimizedState(of: element) == true,
              canRestoreMinimizedWindow(element) else {
            return false
        }

        if let expectedWindowID = window.windowID,
           let currentWindowID = WindowPlatformBridge.windowID(for: element) {
            return currentWindowID == expectedWindowID
        }
        return true
    }

    private static func waitForFocus(
        of window: AccessibleWindow,
        in application: NSRunningApplication
    ) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if isFocused(window, in: application) { return true }
            do {
                try await Task.sleep(for: .milliseconds(70))
            } catch {
                return false
            }
        }
        return false
    }

    static func waitForApplicationActivation(
        of application: NSRunningApplication,
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                return true
            }
            guard !application.isTerminated else { return false }
            do {
                try await Task.sleep(for: .milliseconds(70))
            } catch {
                return false
            }
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }

    private static func isFocused(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
            return false
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return window.windowID.map {
                CoreGraphicsWindowRecord.foremostOnScreenWindowID(for: application.processIdentifier) == $0
            } ?? false
        }

        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
        if let targetElement = window.element,
           CFEqual(focusedElement as CFTypeRef, targetElement as CFTypeRef) {
            return true
        }

        if let focusedWindowID = WindowPlatformBridge.windowID(for: focusedElement),
           let targetWindowID = window.windowID {
            return focusedWindowID == targetWindowID
        }

        // AX may not expose a CG-only target after a Space switch. As a
        // conservative fallback, accept only if its ID is the foremost
        // on-screen normal-level window belonging to the now-frontmost app.
        return window.windowID.map {
            CoreGraphicsWindowRecord.foremostOnScreenWindowID(for: application.processIdentifier) == $0
        } ?? false
    }

    private enum WindowKind: Equatable {
        case standard
        case confirmedWindowWithoutSubrole
        case uncertain
        case notAWindow
    }

    private static func windowKind(of element: AXUIElement) -> WindowKind {
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        guard roleResult == .success,
              let role = roleValue as? String else {
            return .uncertain
        }
        guard role == (kAXWindowRole as String) else {
            return .notAWindow
        }

        var subroleValue: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )
        let subrole = subroleResult == .success ? subroleValue as? String : nil
        guard canRestoreMinimizedWindow(role: role, subrole: subrole) else {
            return .notAWindow
        }
        if subrole == nil {
            return .confirmedWindowWithoutSubrole
        }
        return .standard
    }

    static func canRestoreMinimizedWindow(role: String?, subrole: String?) -> Bool {
        guard role == (kAXWindowRole as String) else { return false }
        return subrole == nil || subrole == (kAXStandardWindowSubrole as String)
    }

    private static func canRestoreMinimizedWindow(_ element: AXUIElement) -> Bool {
        switch windowKind(of: element) {
        case .standard, .confirmedWindowWithoutSubrole:
            return true
        case .uncertain, .notAWindow:
            return false
        }
    }

    private static func titleAttribute(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success,
              let title = value as? String else {
            return nil
        }
        return nonemptyTitle(title)
    }

    private static func frameAttribute(of element: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(kAXPositionAttribute, of: element),
              let size = sizeAttribute(kAXSizeAttribute, of: element) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    private static func minimizedAttribute(of element: AXUIElement) -> Bool {
        minimizedState(of: element) == true
    }

    private static func minimizedState(of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            &value
        ) == .success,
              let value else {
            return nil
        }
        return value as? Bool
    }

    private static func uniquelyMatchingCGWindow(
        title: String?,
        frame: CGRect?,
        minimized: Bool,
        in windows: [CoreGraphicsWindowRecord],
        excluding consumedIDs: Set<CGWindowID>
    ) -> CoreGraphicsWindowRecord? {
        guard !minimized,
              let title,
              let frame else {
            return nil
        }

        let candidates = windows.filter { candidate in
            !consumedIDs.contains(candidate.windowID)
                && candidate.title == title
                && framesMatch(frame, candidate.frame)
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private static func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let positionTolerance: CGFloat = 10
        let sizeTolerance: CGFloat = 12
        let direct = abs(lhs.minX - rhs.minX) <= positionTolerance
            && abs(lhs.minY - rhs.minY) <= positionTolerance
        return direct
            && abs(lhs.width - rhs.width) <= sizeTolerance
            && abs(lhs.height - rhs.height) <= sizeTolerance
    }

    private static func framesSubstantiallyOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        guard lhs.origin.x.isFinite,
              lhs.origin.y.isFinite,
              lhs.width.isFinite,
              lhs.height.isFinite,
              rhs.origin.x.isFinite,
              rhs.origin.y.isFinite,
              rhs.width.isFinite,
              rhs.height.isFinite,
              lhs.width > 0,
              lhs.height > 0,
              rhs.width > 0,
              rhs.height > 0 else {
            return false
        }

        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return false }

        let intersectionArea = intersection.width * intersection.height
        let lhsArea = lhs.width * lhs.height
        let rhsArea = rhs.width * rhs.height
        let smallerArea = min(lhsArea, rhsArea)
        guard intersectionArea > 0, smallerArea > 0 else { return false }

        // Require at least 90% of the smaller frame to overlap and similar
        // dimensions so a small same-titled child surface is not treated as a duplicate.
        let widthSimilarity = min(lhs.width, rhs.width) / max(lhs.width, rhs.width)
        let heightSimilarity = min(lhs.height, rhs.height) / max(lhs.height, rhs.height)
        return intersectionArea / smallerArea >= 0.90
            && widthSimilarity >= 0.90
            && heightSimilarity >= 0.90
    }

    private static func pointAttribute(_ attribute: String, of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(accessibilityValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(_ attribute: String, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        var size = CGSize.zero
        guard AXValueGetValue(accessibilityValue, .cgSize, &size) else { return nil }
        return size
    }
}

private struct WindowDraft {
    let title: String
    let captureTitle: String?
    let isMinimized: Bool
    let isOnScreen: Bool?
    let frame: CGRect?
    let windowID: CGWindowID?
    let spaceIDs: Set<UInt64>?
    let element: AXUIElement?
}

private struct CoreGraphicsWindowRecord {
    private static let minimumDimension: CGFloat = 16
    private static let minimumAlpha = 0.01

    let windowID: CGWindowID
    let title: String?
    let isOnScreen: Bool?
    let frame: CGRect

    static func windows(for processIdentifier: pid_t) -> [CoreGraphicsWindowRecord] {
        guard let rawWindows = windowInfos(options: .optionAll) else {
            return []
        }

        return rawWindows.compactMap { info in
            guard let ownerPID = signed32(info[kCGWindowOwnerPID as String]),
                  ownerPID == processIdentifier,
                  let layer = integer(info[kCGWindowLayer as String]),
                  layer == Int(kCGNormalWindowLevel),
                  let number = unsigned32(info[kCGWindowNumber as String]),
                  number != 0,
                  let frame = windowFrame(info[kCGWindowBounds as String]),
                  frame.width >= minimumDimension,
                  frame.height >= minimumDimension,
                  frame.origin.x.isFinite,
                  frame.origin.y.isFinite,
                  frame.width.isFinite,
                  frame.height.isFinite else {
                return nil
            }

            if let alpha = double(info[kCGWindowAlpha as String]), alpha <= minimumAlpha {
                return nil
            }

            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return CoreGraphicsWindowRecord(
                windowID: number,
                title: title,
                isOnScreen: boolean(info[kCGWindowIsOnscreen as String]),
                frame: frame
            )
        }
    }

    static func foremostOnScreenWindowID(for processIdentifier: pid_t) -> CGWindowID? {
        guard let rawWindows = windowInfos(options: [.optionOnScreenOnly, .excludeDesktopElements]) else {
            return nil
        }

        return rawWindows.first { info in
            signed32(info[kCGWindowOwnerPID as String]) == processIdentifier
                && integer(info[kCGWindowLayer as String]) == Int(kCGNormalWindowLevel)
                && (unsigned32(info[kCGWindowNumber as String]) ?? 0) != 0
        }.flatMap { unsigned32($0[kCGWindowNumber as String]) }
    }

    private static func windowInfos(options: CGWindowListOption) -> [[String: Any]]? {
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) else {
            return nil
        }

        let values = windowList as NSArray
        return values.compactMap { value in
            guard CFGetTypeID(value as CFTypeRef) == CFDictionaryGetTypeID(),
                  let dictionary = value as? NSDictionary else {
                return nil
            }
            return dictionary as? [String: Any]
        }
    }

    private static func cfNumber(_ value: Any?) -> NSNumber? {
        guard let value,
              let number = value as? NSNumber,
              CFGetTypeID(number as CFTypeRef) == CFNumberGetTypeID() else {
            return nil
        }
        return number
    }

    private static func signed32(_ value: Any?) -> Int32? {
        guard let rawValue = cfNumber(value)?.int64Value else { return nil }
        return Int32(exactly: rawValue)
    }

    private static func unsigned32(_ value: Any?) -> UInt32? {
        guard let rawValue = cfNumber(value)?.uint64Value else { return nil }
        return UInt32(exactly: rawValue)
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let rawValue = cfNumber(value)?.int64Value else { return nil }
        return Int(exactly: rawValue)
    }

    private static func double(_ value: Any?) -> Double? {
        cfNumber(value)?.doubleValue
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        let typeID = CFGetTypeID(value as CFTypeRef)
        if typeID == CFBooleanGetTypeID() {
            return value as? Bool
        }
        guard typeID == CFNumberGetTypeID(), let number = value as? NSNumber else {
            return nil
        }
        return number.intValue != 0
    }

    private static func windowFrame(_ value: Any?) -> CGRect? {
        guard let value,
              let dictionary = value as? NSDictionary,
              CFGetTypeID(dictionary as CFTypeRef) == CFDictionaryGetTypeID() else {
            return nil
        }
        return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
    }
}
