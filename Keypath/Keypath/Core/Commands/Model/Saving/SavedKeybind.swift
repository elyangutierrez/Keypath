//
//  SavedKeybind.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/29/26.
//

import Foundation
import SwiftData

@Model
class SavedKeybind {
    var id = UUID()
    var appName: String
    var keybind: Keybind
    
    init(appName: String, keybind: Keybind) {
        self.appName = appName
        self.keybind = keybind
    }
}
