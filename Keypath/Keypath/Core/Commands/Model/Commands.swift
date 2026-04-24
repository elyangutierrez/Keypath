//
//  Commands.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

struct Commands {
    var cmds: [KeypathCommand] = [
        KeypathCommand(icon: "macwindow", name: "Toggle Keypath", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .letter("K")
        )),
        KeypathCommand(icon: "text.and.command.macwindow", name: "Toggle Commands", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .letter("C")
        )),
        KeypathCommand(icon: "macwindow.and.pointer.arrow", name: "Toggle Selection Mode", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .letter("S")
        )),
        KeypathCommand(icon: "arrow.right", name: "Shift Selection To The Right", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .symbol("chevron.backward")
        )),
        KeypathCommand(icon: "arrow.left", name: "Shift Selection To The Left", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .symbol("chevron.forward")
        )),
        KeypathCommand(icon: "command", name: "Assign Path Keybind", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .letter("U")
        )),
        KeypathCommand(icon: "command", name: "Show All Keybinds", keybind: Keybind(
            key1: .symbol(".superKeyLight"), key2: .letter("/")
        ))
    ]
}

