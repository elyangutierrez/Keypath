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
            key1: .symbol("control"), key2: .symbol("option"), key3: .letter("K")
        )),
        KeypathCommand(icon: "text.and.command.macwindow", name: "Toggle Commands", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .letter("C")
        )),
        KeypathCommand(icon: "macwindow.and.pointer.arrow", name: "Toggle Selection Mode", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .letter("S")
        )),
        KeypathCommand(icon: "arrow.right", name: "Shift Selection To The Right", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .symbol("chevron.backward")
        )),
        KeypathCommand(icon: "arrow.left", name: "Shift Selection To The Left", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .symbol("chevron.forward")
        )),
    ]
}

