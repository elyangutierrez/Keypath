//
//  ListApplication.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/16/26.
//

import AppKit
import Foundation

@Observable
class ListApplication: Identifiable, Comparable {
    var id: UUID = UUID()
    var location: URL
    var bundleId: String
    var fillState: FillState = .none
    var isSelected: Bool = false
    var icon: NSImage?
    
    var appName: String {
        return location.deletingPathExtension().lastPathComponent
    }
    
    init(location: URL, bundleId: String) {
        self.location = location
        self.bundleId = bundleId
        self.icon = NSWorkspace.shared.icon(forFile: location.path)
    }
    
    static func == (lhs: ListApplication, rhs: ListApplication) -> Bool {
        return lhs.appName == rhs.appName
    }
    
    static func < (lhs: ListApplication, rhs: ListApplication) -> Bool {
        return lhs.appName < rhs.appName
    }
}

