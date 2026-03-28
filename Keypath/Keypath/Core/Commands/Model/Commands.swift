//
//  Commands.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

struct Commands {
    var cmds: [KeypathCommand] = [
        KeypathCommand(icon: "macwindow", name: "Open Keypath", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .letter("K")
        )),
        KeypathCommand(icon: "text.and.command.macwindow", name: "Open Commands", keybind: Keybind(
            key1: .symbol("control"), key2: .symbol("option"), key3: .letter("C")
        ))
    ]
}
