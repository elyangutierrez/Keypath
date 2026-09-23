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
    var bundleID: String?
    var keybind: Keybind
    
    init(appName: String, bundleID: String? = nil, keybind: Keybind) {
        self.appName = appName
        self.bundleID = bundleID
        self.keybind = keybind
    }

    init(snapshot: SavedKeybindSnapshot) {
        id = snapshot.id
        appName = snapshot.appName
        bundleID = snapshot.bundleID
        keybind = snapshot.keybind
    }
    
    // go by the last key number or letter
    static func < (lhs: SavedKeybind, rhs: SavedKeybind) -> Bool {
        let leftKey2 = lhs.keybind.key2
        let rightKey2 = rhs.keybind.key2
        
        if case let .letter(leftString) = leftKey2, case let .letter(rightString) = rightKey2 {
            return leftString < rightString
        }
        
        return false
    }
}

/// A value copy of a saved binding that can be safely held while a transaction is prepared.
struct SavedKeybindSnapshot: Identifiable {
    let id: UUID
    var appName: String
    var bundleID: String?
    var keybind: Keybind

    init(id: UUID = UUID(), appName: String, bundleID: String?, keybind: Keybind) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.keybind = keybind
    }

    init(_ savedKeybind: SavedKeybind) {
        id = savedKeybind.id
        appName = savedKeybind.appName
        bundleID = savedKeybind.bundleID
        keybind = savedKeybind.keybind
    }
}
