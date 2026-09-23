//
//  Keymaps.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import Foundation

struct Keymaps {
    static let mappings: [Int: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9", 29: "0",
        12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
        32: "u", 34: "i", 31: "o", 35: "p",
        0: "a", 1: "s", 2: "d", 3: "f", 5: "g", 4: "h",
        38: "j", 40: "k", 37: "l",
        6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 45: "n", 46: "m",
        48: "tab", 53: "esc", 123: "leftarrow", 124: "rightarrow",
        125: "downarrow", 126: "uparrow", 76: "enter", 36: "return",
        44: "/", 58: "leftoption"
    ]

    static let keyCodes: [String: Int] = Dictionary(
        uniqueKeysWithValues: mappings.map { ($0.value, $0.key) }
    )

    static let validKeybindMappings: [Int: String] = mappings.filter { keyCode, _ in
        keyCode != 48 && keyCode != 53 && keyCode != 123 && keyCode != 124 &&
        keyCode != 125 && keyCode != 126 && keyCode != 76 && keyCode != 36 &&
        keyCode != 44 && keyCode != 58
    }

    let mappings = Self.mappings
    let keyCodes = Self.keyCodes
    let validKeybindMappings = Self.validKeybindMappings

    var reversed: [String: Int] { keyCodes }
}
