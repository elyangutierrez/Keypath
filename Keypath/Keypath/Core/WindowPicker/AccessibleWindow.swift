//
//  AccessibleWindow.swift
//  Keypath
//

import AppKit
import ApplicationServices
import CoreGraphics
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

@MainActor
enum ApplicationWindowAccessibility {
    static func windows(for application: NSRunningApplication) async -> [AccessibleWindow] {
        guard !Task.isCancelled, !application.isTerminated else { return [] }

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
        guard !Task.isCancelled, !application.isTerminated else { return [] }

        let pid = application.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var axWindowsValue: CFTypeRef?
        let axWindows: [AXUIElement]
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

            if kind == .uncertain {
                // AX role/subrole failures are not evidence of a standard
                // window. Keep such an entry only when all three APIs agree
                // on its process/window ID and geometry, and ScreenCaptureKit
                // supplies a useful title.
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
                element: element
            ))
        }

        // CG's list is ordered front-to-back. A CG-only window is included only
        // when ScreenCaptureKit confirms the same process and window ID, the
        // frames agree, and ScreenCaptureKit supplies a nonempty title.
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

            consumedCGIDs.insert(cgWindow.windowID)
            mergedWindowIDs.insert(cgWindow.windowID)
            merged.append(WindowDraft(
                title: shareableTitle,
                captureTitle: shareableTitle,
                isMinimized: false,
                isOnScreen: cgWindow.isOnScreen,
                frame: cgWindow.frame,
                windowID: cgWindow.windowID,
                element: nil
            ))
        }

        guard !Task.isCancelled, !application.isTerminated else { return [] }

        return merged.enumerated().map { index, window in
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

    /// Performs a best-effort activation for existing synchronous callers.
    /// New picker flows should use `activateAndVerify` before dismissing UI.
    static func activate(_ window: AccessibleWindow, in application: NSRunningApplication) -> Bool {
        beginActivation(window, in: application)
    }

    /// Activates a specific window and confirms that macOS focused that exact
    /// window. Polling is asynchronous so the main actor remains responsive
    /// while the system switches Spaces.
    static func activateAndVerify(
        _ window: AccessibleWindow,
        in application: NSRunningApplication
    ) async -> Bool {
        guard beginActivation(window, in: application) else { return false }

        if await waitForFocus(of: window, in: application) {
            return true
        }

        // If the private Space switch did not result in exact focus for an AX
        // window, try the public, element-targeted action once and verify again.
        guard window.isOnScreen == false,
              let element = window.element,
              activateWithAccessibility(element, window: window, in: application) else {
            return false
        }
        return await waitForFocus(of: window, in: application)
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
            return activateWithAccessibility(element, window: window, in: application)
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

    private static func activateWithAccessibility(
        _ element: AXUIElement,
        window: AccessibleWindow,
        in application: NSRunningApplication
    ) -> Bool {
        _ = application.activate(options: [])

        if window.isMinimized {
            let restoreResult = AXUIElementSetAttributeValue(
                element,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard restoreResult == .success else { return false }
        }

        let raiseResult = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return raiseResult == .success || focusResult == .success
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
        if let focusedWindowID = WindowPlatformBridge.windowID(for: focusedElement),
           let targetWindowID = window.windowID {
            return focusedWindowID == targetWindowID
        }

        if let targetElement = window.element {
            return CFEqual(focusedElement as CFTypeRef, targetElement as CFTypeRef)
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
        guard subroleResult == .success,
              let subrole = subroleValue as? String else {
            return .uncertain
        }

        return subrole == (kAXStandardWindowSubrole as String) ? .standard : .notAWindow
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
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            &value
        ) == .success && (value as? Bool == true)
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
