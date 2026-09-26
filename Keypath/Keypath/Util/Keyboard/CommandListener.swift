//
//  CommandListener.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Observation
import OSLog
import SwiftUI

/// Core Graphics delivers the event on the main run loop where the tap source is installed.
/// This wrapper lets that synchronous callback enter MainActor without pretending CGEvent
/// itself is generally safe to transfer between executors.
private struct MainRunLoopCGEvent: @unchecked Sendable {
    let value: CGEvent
}

enum KeyboardRouteAction: Equatable {
    case toggleHUD
    case toggleCommands
    case toggleSelectionMode
    case showAllKeybinds
    case beginKeybindAssignment
    case assignKeybind(String)
    case moveSelection(by: Int)
    case activateAppKeybind(String)
    case lookupSavedAppKeybind(String)
    case openRecentAppPicker
    case cycleRecentApps(by: Int)
    case activateRecentApp
    case cancelRecentAppPicker
    case moveWindowSelection(by: Int)
    case activateSelectedWindow
    case consumeRecognizedInput
    case selectWindow(number: Int)
    case cancelWindowPicker
    case focusUndo
    case activateUndo
    case cancelKeybindAssignment
    case closeHUD
}

enum KeyboardRouteDecision: Equatable {
    case passThrough
    case handle(KeyboardRouteAction)
}

struct KeyboardModifiers: Equatable {
    var shift = false
    var command = false
    var control = false
    var option = false
    var function = false
    var capsLock = false

    var hasUnsupportedModifier: Bool {
        command || control || option || function || capsLock
    }
}

struct KeyboardRouteContext {
    var settingsAreVisible = false
    var activationChordIsPrimed = false
    var recentAppPickerIsVisible = false
    var windowPickerIsVisible = false
    var keyboardActionIsInProgress = false
    var windowPickerWindowCount = 0
    var keybindAssignmentIsActive = false
    var selectedAppCanReceiveKeybind = false
    var hudIsVisible = false
    var selectionModeIsActive = false
    var commandsAreVisible = false
    var keybindsAreVisible = false
    var undoIsAvailable = false
    var undoIsFocused = false
    var gridColumnCount = 2
    var runningAppKeybinds: Set<String> = []
    var savedAppKeybinds: Set<String> = []
}

/// Pure key-down classification used by both the event listener and routing tests.
struct KeyboardEventRouter {
    func decision(
        for keyCode: Int,
        modifiers: KeyboardModifiers = KeyboardModifiers(),
        context: KeyboardRouteContext
    ) -> KeyboardRouteDecision {
        if context.keyboardActionIsInProgress {
            var idleContext = context
            idleContext.keyboardActionIsInProgress = false
            if case .handle = decision(for: keyCode, modifiers: modifiers, context: idleContext) {
                return .handle(.consumeRecognizedInput)
            }
            return .passThrough
        }

        guard !context.settingsAreVisible else { return .passThrough }

        if context.windowPickerIsVisible {
            return windowPickerDecision(
                for: keyCode,
                modifiers: modifiers,
                windowCount: context.windowPickerWindowCount
            )
        }

        // Some compact keyboards report Fn with navigation keys. During HUD
        // selection, accept Shift/Fn arrow events before general shortcut
        // modifier filtering, while still ignoring Command/Control/Option.
        if context.selectionModeIsActive, !context.recentAppPickerIsVisible,
           !context.keybindAssignmentIsActive,
           !modifiers.command, !modifiers.control, !modifiers.option, !modifiers.capsLock {
            if let offset = selectionOffset(for: keyCode, columns: context.gridColumnCount) {
                return .handle(.moveSelection(by: offset))
            }
        }

        guard !modifiers.hasUnsupportedModifier else { return .passThrough }

        let isPickerReverseCycle = context.recentAppPickerIsVisible &&
            Commands.shortcut(for: .cycleRecentAppsForward).matches(keyCode: keyCode) &&
            modifiers.shift
        guard !modifiers.shift || isPickerReverseCycle else { return .passThrough }

        if context.recentAppPickerIsVisible {
            if Commands.shortcut(for: .cancelRecentAppPicker).matches(keyCode: keyCode) {
                return .handle(.cancelRecentAppPicker)
            }
            if Commands.shortcut(for: .cycleRecentAppsForward).matches(keyCode: keyCode) {
                return .handle(.cycleRecentApps(by: modifiers.shift ? -1 : 1))
            }
            if Commands.shortcut(for: .activateRecentApp).matches(keyCode: keyCode) {
                return .handle(.activateRecentApp)
            }
            return .passThrough
        }

        if context.activationChordIsPrimed {
            if Commands.shortcut(for: .openRecentAppPicker).matches(keyCode: keyCode) {
                return .handle(.openRecentAppPicker)
            }

            if let action = activationChordAction(for: keyCode, context: context) {
                return .handle(action)
            }

            if context.keybindAssignmentIsActive {
                return keybindAssignmentDecision(for: keyCode, context: context)
            }
            return appKeybindDecision(for: keyCode, context: context)
        }

        if context.keybindAssignmentIsActive {
            return keybindAssignmentDecision(for: keyCode, context: context)
        }

        guard context.hudIsVisible else { return .passThrough }

        if Commands.shortcut(for: .closeHUD).matches(keyCode: keyCode) {
            return .handle(.closeHUD)
        }
        if Commands.shortcut(for: .focusUndo).matches(keyCode: keyCode),
           context.undoIsAvailable,
           !context.undoIsFocused {
            return .handle(.focusUndo)
        }
        if Commands.shortcut(for: .activateUndo).matches(keyCode: keyCode),
           context.undoIsAvailable,
           context.undoIsFocused {
            return .handle(.activateUndo)
        }

        return appKeybindDecision(for: keyCode, context: context)
    }

    private func activationChordAction(
        for keyCode: Int,
        context: KeyboardRouteContext
    ) -> KeyboardRouteAction? {
        let matchingShortcut = Commands.shortcuts.first {
            $0.scope == .activationChord && $0.matches(keyCode: keyCode)
        }
        guard let matchingShortcut else { return nil }

        switch matchingShortcut.action {
        case .toggleHUD:
            return .toggleHUD
        case .toggleCommands:
            guard context.hudIsVisible, !context.keybindsAreVisible else { return nil }
            return .toggleCommands
        case .toggleSelectionMode:
            return .toggleSelectionMode
        case .assignAppKeybind:
            guard context.selectedAppCanReceiveKeybind else { return nil }
            return .beginKeybindAssignment
        case .showAllKeybinds:
            guard !context.commandsAreVisible else { return nil }
            return .showAllKeybinds
        case .openRecentAppPicker:
            return .openRecentAppPicker
        default:
            return nil
        }
    }

    private func appKeybindDecision(
        for keyCode: Int,
        context: KeyboardRouteContext
    ) -> KeyboardRouteDecision {
        guard let key = Keymaps.mappings[keyCode]?.uppercased(),
              Keymaps.validKeybindMappings[keyCode] != nil else {
            return .passThrough
        }

        if context.runningAppKeybinds.contains(key) {
            return .handle(.activateAppKeybind(key))
        }
        if context.savedAppKeybinds.contains(key) {
            return .handle(.lookupSavedAppKeybind(key))
        }
        return .passThrough
    }

    private func windowPickerDecision(
        for keyCode: Int,
        modifiers: KeyboardModifiers,
        windowCount: Int
    ) -> KeyboardRouteDecision {
        guard !modifiers.hasUnsupportedModifier else { return .passThrough }

        if Commands.shortcut(for: .cancelWindowPicker).matches(keyCode: keyCode),
           !modifiers.shift {
            return .handle(.cancelWindowPicker)
        }

        // An empty or refreshed picker has no selection to navigate or activate.
        // Escape remains available to close it; all other input passes through.
        guard windowCount > 0 else { return .passThrough }

        if Commands.shortcut(for: .cycleWindowSelection).matches(keyCode: keyCode) {
            return .handle(.moveWindowSelection(by: modifiers.shift ? -1 : 1))
        }
        if !modifiers.shift,
           Commands.shortcut(for: .activateSelectedWindow).matches(keyCode: keyCode) {
            return .handle(.activateSelectedWindow)
        }

        guard !modifiers.shift,
              let digit = Keymaps.mappings[keyCode],
              let number = Int(digit),
              number >= 1,
              number <= min(WindowPickerManager.windowsPerPage, windowCount) else {
            return .passThrough
        }
        return .handle(.selectWindow(number: number))
    }

    private func keybindAssignmentDecision(
        for keyCode: Int,
        context: KeyboardRouteContext
    ) -> KeyboardRouteDecision {
        if Commands.shortcut(for: .cancelKeybindAssignment).matches(keyCode: keyCode) {
            return .handle(.cancelKeybindAssignment)
        }

        guard context.selectedAppCanReceiveKeybind,
              let key = Keymaps.validKeybindMappings[keyCode]?.uppercased() else {
            return .passThrough
        }
        return .handle(.assignKeybind(key))
    }

    private func selectionOffset(for keyCode: Int, columns: Int) -> Int? {
        if Commands.shortcut(for: .shiftSelectionBackward).matches(keyCode: keyCode) { return -1 }
        if Commands.shortcut(for: .shiftSelectionForward).matches(keyCode: keyCode) { return 1 }
        if Commands.shortcut(for: .shiftSelectionUp).matches(keyCode: keyCode) { return -columns }
        if Commands.shortcut(for: .shiftSelectionDown).matches(keyCode: keyCode) { return columns }
        return nil
    }
}

/// Tracks the two left-Option presses and the short command window after them.
struct ActivationChordTracker {
    static let doubleTapInterval: TimeInterval = 0.3
    static let commandTimeout: TimeInterval = 1.5

    private(set) var lastOptionPress: TimeInterval?
    private(set) var expirationTime: TimeInterval?

    mutating func recordLeftOptionPress(at time: TimeInterval) {
        if let lastOptionPress, time >= lastOptionPress,
           time - lastOptionPress <= Self.doubleTapInterval {
            expirationTime = time + Self.commandTimeout
        }
        lastOptionPress = time
    }

    mutating func isPrimed(at time: TimeInterval) -> Bool {
        guard let expirationTime else { return false }
        guard time <= expirationTime else {
            self.expirationTime = nil
            return false
        }
        return true
    }

    mutating func consume() {
        lastOptionPress = nil
        expirationTime = nil
    }
}

enum CommandListenerStatus: Equatable {
    case stopped
    case accessibilityPermissionRequired
    case listening
    case unavailable

    var message: String {
        switch self {
        case .stopped:
            "Keyboard listener is stopped."
        case .accessibilityPermissionRequired:
            "Accessibility permission is needed for global shortcuts."
        case .listening:
            "Keyboard listener is active."
        case .unavailable:
            "Keyboard listener could not start."
        }
    }
}

@Observable
@MainActor
final class CommandListener {
    private let windowDiscoveryLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Keypath",
        category: "WindowDiscovery"
    )

    private(set) var status: CommandListenerStatus = .stopped
    var statusMessage: String { status.message }
    var isListening: Bool { status == .listening }

    var isListeningForPath: Bool = false
    var onKeybindAssignmentRequested: (@MainActor (NSRunningApplication, String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityPermissionRetryTask: Task<Void, Never>?
    private var chordTracker = ActivationChordTracker()
    private var mostRecentExternalApplication: NSRunningApplication?
    private var pendingWindowDiscoveryID: UUID?
    private var windowDiscoveryTask: Task<Void, Never>?

    private let router = KeyboardEventRouter()
    private let commandManager = KeypathCommandManager.shared
    private let navigationManager = NavigationManager.shared
    private let applicationManager = ApplicationManager()
    private let recentAppManager = RecentAppManager.shared
    private let windowPickerManager = WindowPickerManager.shared
    private let assignmentCoordinator = KeybindAssignmentCoordinator.shared

    func start() {
        rememberExternalFrontmostApplication()
        guard eventTap == nil else {
            if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            status = .listening
            return
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            status = .accessibilityPermissionRequired
            retryWhenAccessibilityPermissionIsGranted()
            return
        }

        installEventTap()
    }

    private func installEventTap() {
        accessibilityPermissionRetryTask?.cancel()
        accessibilityPermissionRetryTask = nil

        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<CommandListener>.fromOpaque(refcon).takeUnretainedValue()
                let mainRunLoopEvent = MainRunLoopCGEvent(value: event)
                let shouldSuppressEvent = MainActor.assumeIsolated {
                    listener.handleEvent(proxy: proxy, type: type, event: mainRunLoopEvent.value) == nil
                }
                return shouldSuppressEvent ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            status = .unavailable
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            status = .unavailable
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        status = .listening
    }

    func stop() {
        accessibilityPermissionRetryTask?.cancel()
        accessibilityPermissionRetryTask = nil
        cancelPendingWindowDiscovery()
        chordTracker.consume()

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        status = .stopped
    }

    private func retryWhenAccessibilityPermissionIsGranted() {
        guard accessibilityPermissionRetryTask == nil else { return }

        accessibilityPermissionRetryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard let self,
                      self.status == .accessibilityPermissionRequired else { return }
                guard AXIsProcessTrusted() else { continue }

                self.accessibilityPermissionRetryTask = nil
                self.installEventTap()
                return
            }
        }
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                status = .listening
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            guard navigationManager.route != .settings else {
                cancelPendingWindowDiscovery()
                chordTracker.consume()
                return Unmanaged.passUnretained(event)
            }

            rememberExternalFrontmostApplication()
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == Keymaps.keyCodes["leftoption"], event.flags.contains(.maskAlternate) {
                chordTracker.recordLeftOptionPress(at: Date().timeIntervalSinceReferenceDate)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard navigationManager.route != .settings else {
            cancelPendingWindowDiscovery()
            chordTracker.consume()
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        rememberExternalFrontmostApplication()
        let activationChordIsPrimed = chordTracker.isPrimed(at: Date().timeIntervalSinceReferenceDate)
        let context = makeRoutingContext(
            activationChordIsPrimed: activationChordIsPrimed,
            keyCode: keyCode
        )
        let decision = router.decision(
            for: keyCode,
            modifiers: KeyboardModifiers(
                shift: event.flags.contains(.maskShift),
                command: event.flags.contains(.maskCommand),
                control: event.flags.contains(.maskControl),
                option: event.flags.contains(.maskAlternate),
                function: event.flags.contains(.maskSecondaryFn),
                capsLock: event.flags.contains(.maskAlphaShift)
            ),
            context: context
        )

        if activationChordIsPrimed {
            chordTracker.consume()
        }

        if context.undoIsFocused, decision != .handle(.activateUndo) {
            assignmentCoordinator.setUndoFocused(false)
        }

        guard case let .handle(action) = decision else {
            return Unmanaged.passUnretained(event)
        }
        return handle(action: action, event: event)
    }

    private func makeRoutingContext(activationChordIsPrimed: Bool, keyCode: Int) -> KeyboardRouteContext {
        let runningAppKeybinds = Set(commandManager.currentPaths.compactMap { path -> String? in
            guard let keybind = path.keybind,
                  case let .letter(letter) = keybind.key2 else { return nil }
            return letter.uppercased()
        })
        var savedAppKeybinds = Set<String>()
        if activationChordIsPrimed || isListeningForPath,
           !commandManager.isInKeybindUpdateMode,
           let pressedKey = Keymaps.mappings[keyCode]?.uppercased(),
           Keymaps.validKeybindMappings[keyCode] != nil,
           !runningAppKeybinds.contains(pressedKey),
           assignmentCoordinator.savedDestination(matchingKey: pressedKey) != nil {
            savedAppKeybinds.insert(pressedKey)
        }

        return KeyboardRouteContext(
            settingsAreVisible: navigationManager.route == .settings,
            activationChordIsPrimed: activationChordIsPrimed,
            recentAppPickerIsVisible: recentAppManager.isVisible,
            windowPickerIsVisible: windowPickerManager.isVisible,
            keyboardActionIsInProgress: windowPickerManager.isActivatingWindow,
            windowPickerWindowCount: windowPickerManager.visibleWindows.count,
            keybindAssignmentIsActive: commandManager.isInKeybindUpdateMode,
            selectedAppCanReceiveKeybind: commandManager.currentPaths.indices.contains(commandManager.currentIndex),
            hudIsVisible: isListeningForPath,
            selectionModeIsActive: commandManager.isInSelectionMode,
            commandsAreVisible: commandManager.isShowingCommands,
            keybindsAreVisible: commandManager.isShowingKeybinds,
            undoIsAvailable: assignmentCoordinator.undoAvailable,
            undoIsFocused: assignmentCoordinator.isUndoFocused,
            gridColumnCount: GridLayoutManager.shared.columnCount,
            runningAppKeybinds: runningAppKeybinds,
            savedAppKeybinds: savedAppKeybinds
        )
    }

    private func handle(action: KeyboardRouteAction, event: CGEvent) -> Unmanaged<CGEvent>? {
        if case .activateAppKeybind = action {
            // A new app selection replaces any pending discovery request.
        } else {
            cancelPendingWindowDiscovery()
        }

        switch action {
        case .toggleHUD:
            if isListeningForPath {
                recentAppManager.cancelPicker()
                assignmentCoordinator.setUndoFocused(false)
                commandManager.resetModes()
                commandManager.resetIndex()
                isListeningForPath = false
                withAnimation(.spring(duration: 0.3)) {
                    PathsWindowManager.shared.hide()
                }
            } else {
                isListeningForPath = true
                withAnimation(.spring(duration: 0.3)) {
                    PathsWindowManager.shared.show()
                }
            }
            return nil

        case .toggleCommands:
            withAnimation(.spring(duration: 0.3)) {
                commandManager.isShowingCommands.toggle()
            }
            return nil

        case .toggleSelectionMode:
            withAnimation(.spring(duration: 0.3)) {
                commandManager.isInSelectionMode.toggle()
            }
            if !commandManager.isInSelectionMode {
                commandManager.resetIndex()
            }
            return nil

        case .showAllKeybinds:
            withAnimation(.spring(duration: 0.3)) {
                commandManager.isShowingKeybinds.toggle()
            }
            return nil

        case .beginKeybindAssignment:
            withAnimation(.spring(duration: 0.3)) {
                commandManager.isInKeybindUpdateMode.toggle()
            }
            return nil

        case let .assignKeybind(key):
            guard commandManager.currentPaths.indices.contains(commandManager.currentIndex),
                  let callback = onKeybindAssignmentRequested else {
                return Unmanaged.passUnretained(event)
            }
            callback(commandManager.currentPaths[commandManager.currentIndex].application, key)
            commandManager.isInKeybindUpdateMode = false
            return nil

        case let .moveSelection(offset):
            withAnimation(.spring(duration: 0.3)) {
                commandManager.shiftSelection(by: offset)
            }
            return nil

        case let .activateAppKeybind(key):
            guard let matchedPath = commandManager.currentPaths.first(where: { path in
                guard let keybind = path.keybind,
                      case let .letter(letter) = keybind.key2 else { return false }
                return letter.uppercased() == key
            }) else {
                return Unmanaged.passUnretained(event)
            }

            discoverWindowsAndActivate(matchedPath)
            return nil

        case let .lookupSavedAppKeybind(key):
            guard let destination = assignmentCoordinator.savedDestination(matchingKey: key) else {
                return Unmanaged.passUnretained(event)
            }
            if let application = runningApplication(matching: destination) {
                // The visible paths can briefly lag workspace state. If a
                // saved destination is already running, use the same window
                // discovery and restoration flow as a visible app card.
                discoverWindowsAndActivate(Keypath(application: application))
            } else {
                applicationManager.activateApplication(appName: destination.appName, bundleID: destination.bundleID)
                dismissHUDAfterAppSwitch()
            }
            return nil

        case .openRecentAppPicker:
            guard recentAppManager.beginPicker() else { return Unmanaged.passUnretained(event) }
            commandManager.isShowingCommands = false
            commandManager.isShowingKeybinds = false
            assignmentCoordinator.setUndoFocused(false)
            isListeningForPath = true
            withAnimation(.spring(duration: 0.3)) {
                PathsWindowManager.shared.show()
            }
            return nil

        case let .cycleRecentApps(offset):
            return recentAppManager.moveSelection(by: offset)
                ? nil
                : Unmanaged.passUnretained(event)

        case .activateRecentApp:
            guard recentAppManager.activateSelection() else {
                return Unmanaged.passUnretained(event)
            }
            dismissHUDAfterAppSwitch()
            return nil

        case .cancelRecentAppPicker:
            return recentAppManager.cancelPicker()
                ? nil
                : Unmanaged.passUnretained(event)

        case let .moveWindowSelection(offset):
            windowPickerManager.moveSelection(by: offset)
            PathsWindowManager.shared.setWindowPickerContentSize(windowPickerManager.panelContentSize)
            return nil

        case .activateSelectedWindow:
            activateWindowPickerSelection()
            return nil

        case .consumeRecognizedInput:
            return nil

        case let .selectWindow(number):
            activateWindowPickerSelection(keyNumber: number)
            return nil

        case .cancelWindowPicker:
            windowPickerManager.cancel()
            assignmentCoordinator.setUndoFocused(false)
            commandManager.resetModes()
            commandManager.resetIndex()
            isListeningForPath = false
            withAnimation(.spring(duration: 0.3)) {
                PathsWindowManager.shared.hide()
            }
            return nil

        case .focusUndo:
            guard assignmentCoordinator.undoAvailable else {
                return Unmanaged.passUnretained(event)
            }
            assignmentCoordinator.setUndoFocused(true)
            return nil

        case .activateUndo:
            guard assignmentCoordinator.undoAvailable,
                  assignmentCoordinator.isUndoFocused else {
                return Unmanaged.passUnretained(event)
            }
            assignmentCoordinator.undoLastChange()
            return nil

        case .cancelKeybindAssignment:
            withAnimation(.spring(duration: 0.3)) {
                commandManager.resetModes()
            }
            return nil

        case .closeHUD:
            assignmentCoordinator.setUndoFocused(false)
            commandManager.resetModes()
            commandManager.resetIndex()
            isListeningForPath = false
            withAnimation(.spring(duration: 0.3)) {
                PathsWindowManager.shared.hide()
            }
            return nil
        }
    }

    private func dismissHUDAfterAppSwitch() {
        windowPickerManager.finish()
        assignmentCoordinator.setUndoFocused(false)
        isListeningForPath = false
        commandManager.resetModes()
        commandManager.resetIndex()
        PathsWindowManager.shared.hide()
    }

    private func discoverWindowsAndActivate(_ path: Keypath) {
        cancelPendingWindowDiscovery()
        let discoveryID = UUID()
        pendingWindowDiscoveryID = discoveryID

        let application = path.application
        let keybind = path.keybind
        let returningApplication = returnApplicationAfterKeypath()
        let originalRoute = navigationManager.route
        let hudWasVisible = isListeningForPath

        windowDiscoveryTask = Task { @MainActor [weak self] in
            let discovery = await ApplicationWindowAccessibility.discoverWindows(for: application)
            guard let self,
                  self.pendingWindowDiscoveryID == discoveryID,
                  !Task.isCancelled else {
                return
            }

            guard self.navigationManager.route == originalRoute,
                  originalRoute != .settings,
                  self.isListeningForPath == hudWasVisible,
                  !application.isTerminated else {
                self.finishWindowDiscovery(discoveryID)
                return
            }

            if !discovery.windows.isEmpty {
                self.finishWindowDiscovery(discoveryID)
                self.presentWindows(
                    discovery.windows,
                    for: application,
                    keybind: keybind,
                    returningTo: returningApplication
                )
                return
            }

            // Some apps omit miniaturized windows from AXWindows and do not
            // expose AXMainWindow until they are active. Activate first, then
            // query AX again so any newly exposed minimized target follows the
            // exact-window restoration and focus verification path.
            NSApp.yieldActivation(to: application)
            PathsWindowManager.shared.hide()
            _ = application.unhide()
            let activationRequested = application.activate(options: [.activateAllWindows])
            self.windowDiscoveryLogger.debug(
                "Fallback activation requested=\(activationRequested, privacy: .public)"
            )
            guard self.pendingWindowDiscoveryID == discoveryID,
                  !Task.isCancelled else {
                return
            }
            guard activationRequested else {
                self.finishWindowDiscovery(discoveryID)
                if discovery.hasWindowEvidence {
                    self.presentWindowDiscoveryFailure(
                        for: application,
                        keybind: keybind,
                        returningTo: returningApplication,
                        message: "macOS reported windows for this app but denied activation. Open it from the Dock, then try again."
                    )
                } else {
                    self.dismissHUDAfterAppSwitch()
                }
                return
            }

            let appBecameActive = await ApplicationWindowAccessibility.waitForApplicationActivation(of: application)
            self.windowDiscoveryLogger.debug(
                "Fallback activation status=\(appBecameActive ? "frontmost" : "not-frontmost", privacy: .public)"
            )
            guard self.pendingWindowDiscoveryID == discoveryID,
                  !Task.isCancelled else {
                return
            }
            guard appBecameActive, !application.isTerminated else {
                self.finishWindowDiscovery(discoveryID)
                if discovery.hasWindowEvidence {
                    self.presentWindowDiscoveryFailure(
                        for: application,
                        keybind: keybind,
                        returningTo: returningApplication,
                        message: "macOS reported windows for this app but it did not come to the front. Open it from the Dock, then try again."
                    )
                } else {
                    self.dismissHUDAfterAppSwitch()
                }
                return
            }

            let activatedDiscovery = await ApplicationWindowAccessibility.discoverWindowsAfterActivation(
                for: application
            )
            guard self.pendingWindowDiscoveryID == discoveryID,
                  !Task.isCancelled,
                  !application.isTerminated else {
                return
            }
            guard self.navigationManager.route == originalRoute,
                  self.isListeningForPath == hudWasVisible else {
                self.finishWindowDiscovery(discoveryID)
                return
            }
            self.finishWindowDiscovery(discoveryID)
            if !activatedDiscovery.windows.isEmpty {
                self.presentWindows(
                    activatedDiscovery.windows,
                    for: application,
                    keybind: keybind,
                    returningTo: returningApplication,
                    wasDiscoveredAfterActivation: true
                )
                return
            }

            if discovery.hasWindowEvidence || activatedDiscovery.hasWindowEvidence {
                self.presentWindowDiscoveryFailure(
                    for: application,
                    keybind: keybind,
                    returningTo: returningApplication,
                    message: "macOS reports windows for this app, but Keypath could not access one to restore. Open a window from the Dock, then try again."
                )
            } else {
                // A genuinely windowless app should still open normally.
                self.dismissHUDAfterAppSwitch()
            }
        }
    }

    private func finishWindowDiscovery(_ discoveryID: UUID) {
        guard pendingWindowDiscoveryID == discoveryID else { return }
        pendingWindowDiscoveryID = nil
        windowDiscoveryTask = nil
    }

    private func presentWindows(
        _ windows: [AccessibleWindow],
        for application: NSRunningApplication,
        keybind: Keybind?,
        returningTo returningApplication: NSRunningApplication?,
        wasDiscoveredAfterActivation: Bool = false
    ) {
        if windows.count > 1 {
            windowPickerManager.begin(
                for: application,
                windows: windows,
                keybind: keybind,
                returningTo: returningApplication
            )
            commandManager.resetModes()
            recentAppManager.cancelPicker()
            assignmentCoordinator.setUndoFocused(false)
            isListeningForPath = true
            PathsWindowManager.shared.setWindowPickerContentSize(windowPickerManager.panelContentSize)
            withAnimation(.spring(duration: 0.3)) {
                PathsWindowManager.shared.show()
            }
            return
        }

        guard let window = windows.first else { return }
        if !wasDiscoveredAfterActivation {
            let didMinimize = ApplicationWindowAccessibility.minimizeIfActive(window, in: application)
            windowDiscoveryLogger.debug(
                "Single-window action source=initial-discovery minimize-result=\(didMinimize, privacy: .public)"
            )
            if didMinimize {
                dismissHUDAfterAppSwitch()
                return
            }
        } else {
            windowDiscoveryLogger.debug(
                "Single-window action source=post-activation minimize-attempted=false"
            )
        }

        windowPickerManager.begin(
            for: application,
            windows: [window],
            keybind: keybind,
            returningTo: returningApplication
        )
        activateWindowPickerSelection()
    }

    private func presentWindowDiscoveryFailure(
        for application: NSRunningApplication,
        keybind: Keybind?,
        returningTo returningApplication: NSRunningApplication?,
        message: String
    ) {
        windowPickerManager.begin(
            for: application,
            windows: [],
            keybind: keybind,
            returningTo: returningApplication,
            initialErrorMessage: message
        )
        commandManager.resetModes()
        recentAppManager.cancelPicker()
        assignmentCoordinator.setUndoFocused(false)
        isListeningForPath = true
        PathsWindowManager.shared.setWindowPickerContentSize(windowPickerManager.panelContentSize)
        withAnimation(.spring(duration: 0.3)) {
            PathsWindowManager.shared.show()
        }
    }

    private func runningApplication(matching destination: SavedKeybindDestination) -> NSRunningApplication? {
        let runningApplications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }

        if let bundleID = destination.bundleID {
            return runningApplications.first { $0.bundleIdentifier == bundleID }
        }

        let nameMatches = runningApplications.filter { $0.localizedName == destination.appName }
        return nameMatches.count == 1 ? nameMatches.first : nil
    }

    private func cancelPendingWindowDiscovery() {
        pendingWindowDiscoveryID = nil
        windowDiscoveryTask?.cancel()
        windowDiscoveryTask = nil
    }

    private func activateWindowPickerSelection(keyNumber: Int? = nil) {
        guard let pickerSessionID = windowPickerManager.prepareWindowActivation() else { return }
        Task { @MainActor [weak self] in
            guard let self,
                  windowPickerManager.isVisible,
                  windowPickerManager.pickerSessionID == pickerSessionID else {
                return
            }

            let activationResult: ApplicationWindowAccessibility.ActivationResult
            if let keyNumber {
                activationResult = await windowPickerManager.activateWindow(
                    keyNumber: keyNumber,
                    in: pickerSessionID
                )
            } else {
                activationResult = await windowPickerManager.activateSelectedWindow(in: pickerSessionID)
            }

            guard windowPickerManager.pickerSessionID == pickerSessionID else { return }
            guard activationResult == .activated else {
                if windowPickerManager.isVisible {
                    PathsWindowManager.shared.setWindowPickerContentSize(windowPickerManager.panelContentSize)
                    PathsWindowManager.shared.show()
                }
                return
            }
            dismissHUDAfterAppSwitch()
        }
    }

    private func returnApplicationAfterKeypath() -> NSRunningApplication? {
        rememberExternalFrontmostApplication()
        return mostRecentExternalApplication
    }

    private func rememberExternalFrontmostApplication() {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !frontmostApplication.isTerminated else {
            return
        }
        mostRecentExternalApplication = frontmostApplication
    }
}
