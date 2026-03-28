//
//  KeypathCommands.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

@Observable
class KeypathCommand: Identifiable, Comparable {
    var id = UUID()
    var icon: String
    var name: String
    var keybind: Keybind
    var isHovered: Bool
    
    static func == (lhs: KeypathCommand, rhs: KeypathCommand) -> Bool {
        return lhs.name == rhs.name
    }
    
    static func < (lhs: KeypathCommand, rhs: KeypathCommand) -> Bool {
        return lhs.name < rhs.name
    }
    
    init(icon: String, name: String, keybind: Keybind) {
        self.icon = icon
        self.name = name
        self.keybind = keybind
        self.isHovered = false
    }
}
