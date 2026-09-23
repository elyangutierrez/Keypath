//
//  KeyboardEventRouterTests.swift
//  KeypathTests
//

import Testing
@testable import Keypath

@MainActor
struct KeyboardEventRouterTests {
    private let router = KeyboardEventRouter()

    @Test func unmatchedInputPassesThroughInTheHUDAndAfterTheActivationChord() {
        let hudDecision = router.decision(
            for: 2,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(hudIsVisible: true)
        )
        #expect(hudDecision == .passThrough)

        let chordDecision = router.decision(
            for: 2,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(activationChordIsPrimed: true)
        )
        #expect(chordDecision == .passThrough)
    }

    @Test func onlyConfiguredRunningOrSavedAppKeysAreRecognized() {
        let runningDecision = router.decision(
            for: 2,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                hudIsVisible: true,
                runningAppKeybinds: ["D"]
            )
        )
        #expect(runningDecision == .handle(.activateAppKeybind("D")))

        let savedDecision = router.decision(
            for: 2,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                activationChordIsPrimed: true,
                savedAppKeybinds: ["D"]
            )
        )
        #expect(savedDecision == .handle(.lookupSavedAppKeybind("D")))
    }

    @Test func activationChordActionsComeFromTheShortcutTable() {
        #expect(router.decision(
            for: Keymaps.keyCodes["k"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(activationChordIsPrimed: true)
        ) == .handle(.toggleHUD))

        #expect(router.decision(
            for: Keymaps.keyCodes["tab"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(activationChordIsPrimed: true)
        ) == .handle(.openRecentAppPicker))
    }

    @Test func assignmentCaptureConsumesOnlyEscapeOrAValidKeyWithASelectedApp() {
        let validKey = router.decision(
            for: Keymaps.keyCodes["q"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                keybindAssignmentIsActive: true,
                selectedAppCanReceiveKeybind: true
            )
        )
        #expect(validKey == .handle(.assignKeybind("Q")))

        let invalidKey = router.decision(
            for: Keymaps.keyCodes["leftarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                keybindAssignmentIsActive: true,
                selectedAppCanReceiveKeybind: true
            )
        )
        #expect(invalidKey == .passThrough)

        let noSelectedApp = router.decision(
            for: Keymaps.keyCodes["q"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(keybindAssignmentIsActive: true)
        )
        #expect(noSelectedApp == .passThrough)

        #expect(router.decision(
            for: Keymaps.keyCodes["esc"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(keybindAssignmentIsActive: true)
        ) == .handle(.cancelKeybindAssignment))
    }

    @Test func selectionArrowsAreConsumedOnlyInSelectionMode() {
        #expect(router.decision(
            for: Keymaps.keyCodes["leftarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(selectionModeIsActive: true)
        ) == .handle(.moveSelection(by: -1)))

        #expect(router.decision(
            for: Keymaps.keyCodes["rightarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(selectionModeIsActive: true)
        ) == .handle(.moveSelection(by: 1)))

        #expect(router.decision(
            for: Keymaps.keyCodes["leftarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext()
        ) == .passThrough)

        #expect(router.decision(
            for: Keymaps.keyCodes["rightarrow"]!,
            modifiers: KeyboardModifiers(shift: true),
            context: KeyboardRouteContext(selectionModeIsActive: true)
        ) == .handle(.moveSelection(by: 1)))

        #expect(router.decision(
            for: Keymaps.keyCodes["leftarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                activationChordIsPrimed: true,
                selectionModeIsActive: true
            )
        ) == .handle(.moveSelection(by: -1)))

        #expect(router.decision(
            for: Keymaps.keyCodes["uparrow"]!,
            modifiers: KeyboardModifiers(function: true),
            context: KeyboardRouteContext(selectionModeIsActive: true)
        ) == .handle(.moveSelection(by: -2)))
        #expect(router.decision(
            for: Keymaps.keyCodes["downarrow"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(selectionModeIsActive: true)
        ) == .handle(.moveSelection(by: 2)))
    }

    @Test func recentPickerRoutesForwardReverseActivateAndCancelControls() {
        let context = KeyboardRouteContext(recentAppPickerIsVisible: true)
        let tab = Keymaps.keyCodes["tab"]!

        #expect(router.decision(for: tab, modifiers: KeyboardModifiers(), context: context)
                == .handle(.cycleRecentApps(by: 1)))
        #expect(router.decision(for: tab, modifiers: KeyboardModifiers(shift: true), context: context)
                == .handle(.cycleRecentApps(by: -1)))
        #expect(router.decision(for: Keymaps.keyCodes["return"]!, modifiers: KeyboardModifiers(), context: context)
                == .handle(.activateRecentApp))
        #expect(router.decision(for: Keymaps.keyCodes["enter"]!, modifiers: KeyboardModifiers(), context: context)
                == .handle(.activateRecentApp))
        #expect(router.decision(for: Keymaps.keyCodes["esc"]!, modifiers: KeyboardModifiers(), context: context)
                == .handle(.cancelRecentAppPicker))
        #expect(router.decision(for: Keymaps.keyCodes["q"]!, modifiers: KeyboardModifiers(), context: context)
                == .passThrough)
    }

    @Test func modifiedShortcutsPassThrough() {
        let pickerContext = KeyboardRouteContext(recentAppPickerIsVisible: true)
        let hudContext = KeyboardRouteContext(hudIsVisible: true)

        #expect(router.decision(
            for: Keymaps.keyCodes["tab"]!,
            modifiers: KeyboardModifiers(command: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["tab"]!,
            modifiers: KeyboardModifiers(control: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["return"]!,
            modifiers: KeyboardModifiers(control: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["esc"]!,
            modifiers: KeyboardModifiers(option: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["return"]!,
            modifiers: KeyboardModifiers(shift: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["esc"]!,
            modifiers: KeyboardModifiers(shift: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["tab"]!,
            modifiers: KeyboardModifiers(function: true),
            context: pickerContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["q"]!,
            modifiers: KeyboardModifiers(capsLock: true),
            context: hudContext
        ) == .passThrough)
        #expect(router.decision(
            for: Keymaps.keyCodes["k"]!,
            modifiers: KeyboardModifiers(command: true),
            context: KeyboardRouteContext(activationChordIsPrimed: true)
        ) == .passThrough)
    }

    @Test func undoTabFocusAndEnterRequireAnAvailableUndo() {
        let hud = KeyboardRouteContext(hudIsVisible: true)
        let tab = Keymaps.keyCodes["tab"]!
        let enter = Keymaps.keyCodes["return"]!

        #expect(router.decision(for: tab, modifiers: KeyboardModifiers(), context: hud) == .passThrough)
        #expect(router.decision(
            for: tab,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(hudIsVisible: true, undoIsAvailable: true)
        ) == .handle(.focusUndo))
        #expect(router.decision(
            for: tab,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(hudIsVisible: true, undoIsAvailable: true, undoIsFocused: true)
        ) == .passThrough)
        #expect(router.decision(
            for: enter,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(hudIsVisible: true, undoIsAvailable: true, undoIsFocused: true)
        ) == .handle(.activateUndo))
        #expect(router.decision(
            for: enter,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(hudIsVisible: true, undoIsFocused: true)
        ) == .passThrough)
    }

    @Test func settingsRouteAlwaysPassesInputThrough() {
        #expect(router.decision(
            for: Keymaps.keyCodes["k"]!,
            modifiers: KeyboardModifiers(),
            context: KeyboardRouteContext(
                settingsAreVisible: true,
                activationChordIsPrimed: true,
                hudIsVisible: true
            )
        ) == .passThrough)
    }

    @Test func doubleOptionChordExpiresAndResetsAfterUse() {
        var tracker = ActivationChordTracker()
        tracker.recordLeftOptionPress(at: 10)
        tracker.recordLeftOptionPress(at: 10.2)
        let firstCommandWindowIsOpen = tracker.isPrimed(at: 10.2)
        let finalMomentIsOpen = tracker.isPrimed(at: 11.69)
        let commandWindowExpired = !tracker.isPrimed(at: 11.71)
        #expect(firstCommandWindowIsOpen)
        #expect(finalMomentIsOpen)
        #expect(commandWindowExpired)

        tracker.recordLeftOptionPress(at: 20)
        tracker.recordLeftOptionPress(at: 20.2)
        tracker.consume()
        let consumedWindowIsClosed = !tracker.isPrimed(at: 20.3)
        #expect(consumedWindowIsClosed)
    }
}
