//
//  Commands.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

enum ShortcutAction: String, CaseIterable, Identifiable, Equatable {
    case toggleHUD
    case toggleCommands
    case toggleSelectionMode
    case shiftSelectionBackward
    case shiftSelectionForward
    case assignAppKeybind
    case showAllKeybinds
    case openRecentAppPicker
    case cycleRecentAppsForward
    case cycleRecentAppsBackward
    case activateRecentApp
    case cancelRecentAppPicker
    case focusUndo
    case activateUndo
    case cancelKeybindAssignment
    case closeHUD

    var id: String { rawValue }
}

enum ShortcutScope: Equatable {
    case activationChord
    case selectionMode
    case recentAppPicker
    case hud
}

struct ShortcutDefinition: Identifiable {
    let action: ShortcutAction
    let title: String
    let icon: String
    let keyNames: [String]
    let keyLabel: String
    let scope: ShortcutScope
    let usesActivationChord: Bool

    var id: ShortcutAction { action }

    var keyCodes: [Int] {
        keyNames.compactMap { Keymaps.keyCodes[$0] }
    }

    func matches(keyCode: Int) -> Bool {
        keyCodes.contains(keyCode)
    }
}

/// The in-app help and the event router both read from this shortcut table.
enum Commands {
    static let activationChordHelpText = "Double-tap left Option, then press the shown key."
    static let contextualShortcutHelpText = "Picker and HUD keys work while those views are open."

    static let shortcuts: [ShortcutDefinition] = [
        .init(action: .toggleHUD, title: "Toggle Keypath", icon: "macwindow",
              keyNames: ["k"], keyLabel: "K", scope: .activationChord, usesActivationChord: true),
        .init(action: .toggleCommands, title: "Toggle Commands", icon: "text.and.command.macwindow",
              keyNames: ["c"], keyLabel: "C", scope: .activationChord, usesActivationChord: true),
        .init(action: .toggleSelectionMode, title: "Toggle Selection Mode", icon: "macwindow.and.pointer.arrow",
              keyNames: ["s"], keyLabel: "S", scope: .activationChord, usesActivationChord: true),
        .init(action: .shiftSelectionBackward, title: "Move Selection Left", icon: "arrow.left",
              keyNames: ["leftarrow"], keyLabel: "←", scope: .selectionMode, usesActivationChord: false),
        .init(action: .shiftSelectionForward, title: "Move Selection Right", icon: "arrow.right",
              keyNames: ["rightarrow"], keyLabel: "→", scope: .selectionMode, usesActivationChord: false),
        .init(action: .assignAppKeybind, title: "Assign App Keybind", icon: "command",
              keyNames: ["u"], keyLabel: "U", scope: .activationChord, usesActivationChord: true),
        .init(action: .showAllKeybinds, title: "Show All Keybinds", icon: "command",
              keyNames: ["/"], keyLabel: "/", scope: .activationChord, usesActivationChord: true),
        .init(action: .openRecentAppPicker, title: "Open Recent App Picker", icon: "clock.arrow.circlepath",
              keyNames: ["tab"], keyLabel: "Tab", scope: .activationChord, usesActivationChord: true),
        .init(action: .cycleRecentAppsForward, title: "Next Recent App", icon: "arrow.right.to.line",
              keyNames: ["tab"], keyLabel: "Tab", scope: .recentAppPicker, usesActivationChord: false),
        .init(action: .cycleRecentAppsBackward, title: "Previous Recent App", icon: "arrow.left.to.line",
              keyNames: ["tab"], keyLabel: "Shift-Tab", scope: .recentAppPicker, usesActivationChord: false),
        .init(action: .activateRecentApp, title: "Select Recent App", icon: "return",
              keyNames: ["return", "enter"], keyLabel: "Return / Enter", scope: .recentAppPicker, usesActivationChord: false),
        .init(action: .cancelRecentAppPicker, title: "Cancel Recent App Picker", icon: "escape",
              keyNames: ["esc"], keyLabel: "Esc", scope: .recentAppPicker, usesActivationChord: false),
        .init(action: .focusUndo, title: "Focus Undo", icon: "arrow.uturn.backward",
              keyNames: ["tab"], keyLabel: "Tab", scope: .hud, usesActivationChord: false),
        .init(action: .activateUndo, title: "Undo Last Keybind Change", icon: "arrow.uturn.backward",
              keyNames: ["return", "enter"], keyLabel: "Return / Enter", scope: .hud, usesActivationChord: false),
        .init(action: .cancelKeybindAssignment, title: "Cancel Keybind Assignment", icon: "escape",
              keyNames: ["esc"], keyLabel: "Esc", scope: .hud, usesActivationChord: false),
        .init(action: .closeHUD, title: "Close Keypath", icon: "escape",
              keyNames: ["esc"], keyLabel: "Esc", scope: .hud, usesActivationChord: false)
    ]

    static func shortcut(for action: ShortcutAction) -> ShortcutDefinition {
        guard let shortcut = shortcuts.first(where: { $0.action == action }) else {
            preconditionFailure("Missing shortcut definition for \(action)")
        }
        return shortcut
    }
}
