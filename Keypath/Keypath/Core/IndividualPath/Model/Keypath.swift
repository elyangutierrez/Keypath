//
//  Keypath.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import AppKit
import Foundation

@Observable
class Keypath: Identifiable, Hashable, Comparable {
    var id = UUID()
    var application: NSRunningApplication
    var keybind: Keybind?
    
    init(application: NSRunningApplication) {
        self.application = application
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func < (lhs: Keypath, rhs: Keypath) -> Bool {
        return lhs.application.localizedName ?? "" < rhs.application.localizedName ?? ""
    }
    
    static func == (lhs: Keypath, rhs: Keypath) -> Bool {
        return lhs.id == rhs.id
    }
}
