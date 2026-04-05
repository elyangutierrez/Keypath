//
//  SavedKeybind.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/29/26.
//

import Foundation
import SwiftData

@Model
class SavedKeybind: Comparable {
    var id = UUID()
    var appName: String
    var keybind: Keybind
    
    init(appName: String, keybind: Keybind) {
        self.appName = appName
        self.keybind = keybind
    }
    
    // go by the last key number or letter
    static func < (lhs: SavedKeybind, rhs: SavedKeybind) -> Bool {
        let leftKey3 = lhs.keybind.key3
        let rightKey3 = rhs.keybind.key3
        
        if case let .letter(leftString) = leftKey3, case let .letter(rightString) = rightKey3 {
            return leftString < rightString
        }
        
        return false
    }
}
