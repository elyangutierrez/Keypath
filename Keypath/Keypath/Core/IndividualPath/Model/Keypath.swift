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
    var isFrontmost: Bool = false
    
    init(application: NSRunningApplication) {
        self.application = application
    }
    
    func moveToApp() {
        application.activate()
        
        isFrontmost = true
        
        if let appURL = application.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            
            NSWorkspace.shared.open(appURL, configuration: config) { _, error in
                if let error = error {
                    print("Activation Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func moveFromApp() {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            var windowsValue: CFTypeRef?
            
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
            
            if result == .success, let windows = windowsValue as? [AXUIElement] {
                for window in windows {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                }
                isFrontmost = false
            } else {
                print("Could not find windows to minimize, or app does not support it.")
            }
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
