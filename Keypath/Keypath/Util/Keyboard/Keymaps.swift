//
//  Keymaps.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import Foundation

struct Keymaps {
    let mappings: [Int: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9", 29: "0",
        12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
        32: "u", 34: "i", 31: "o", 35: "p",
        0: "a", 1: "s", 2: "d", 3: "f", 5: "g", 4: "h",
        38: "j", 40: "k", 37: "l",
        6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 45: "n", 46: "m",
        53: "esc", 123: "leftarrow", 124: "rightarrow", 125: "downarrow", 126: "uparrow"
    ]

    lazy var reversed: [String: Int] = {
        Dictionary(uniqueKeysWithValues: mappings.map { ($0.value, $0.key) })
    }()
}
