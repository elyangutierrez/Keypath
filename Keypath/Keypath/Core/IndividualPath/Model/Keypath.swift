//
//  Keypath.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import AppKit
import ApplicationServices
import Foundation

// 1. Declare the Private Apple C-Function to bridge Accessibility and CoreGraphics
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ idOut: UnsafeMutablePointer<CGWindowID>) -> AXError

@Observable
class Keypath: Identifiable, Hashable, Comparable {
    var application: NSRunningApplication
    var keybind: Keybind?
    var isWindowOpened: Bool = false
    
    var id: pid_t {
        return application.processIdentifier
    }
    
    var appName: String {
        return application.localizedName ?? "Unknown App"
    }
    
    var hasVisibleWindow: Bool {
        if application.isHidden { return false }
        
        let pid = application.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        
        var knownMinimizedIDs = Set<CGWindowID>()
        var hasUnminimizedWindowOnCurrentSpace = false
        
        // --- STEP 1: Accessibility Check (Current Space & Minimized) ---
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        if result == .success, let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                var isMinimized = false
                var minimizedValue: CFTypeRef?
                
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
                   let min = minimizedValue as? Bool {
                    isMinimized = min
                }
                
                if !isMinimized {
                    // We found an active window right here on the current desktop!
                    hasUnminimizedWindowOnCurrentSpace = true
                } else {
                    // It is minimized! Use the Private API to get its exact hardware Window ID
                    var cgWindowID: CGWindowID = 0
                    if _AXUIElementGetWindow(window, &cgWindowID) == .success {
                        knownMinimizedIDs.insert(cgWindowID)
                    }
                }
            }
        }
        
        // Quick exit if it's open on the current desktop
        if hasUnminimizedWindowOnCurrentSpace {
            return true
        }
        
        // --- STEP 2: Other Spaces Check via CGWindowList ---
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid else { continue }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let alpha = window[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0.0 { continue }
            
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let heightNum = boundsDict["Height"] as? NSNumber,
               let widthNum = boundsDict["Width"] as? NSNumber {
                if heightNum.intValue <= 50 || widthNum.intValue <= 50 {
                    continue
                }
            }
            
            // Get the ID of this CoreGraphics window
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID else { continue }
            
            // --- STEP 3: The Private API Filter ---
            // If this window ID perfectly matches the one we extracted from the Dock, ignore it!
            if knownMinimizedIDs.contains(windowID) {
                continue
            }
            
            if window[kCGWindowName as String] == nil {
                continue // It's a shadow window, kill it!
            }
            
            // If it survives all of this, it is 100% a real, active window on another desktop!
            return true
        }
        
        return false
    }
    
    init(application: NSRunningApplication) {
        self.application = application
    }
    
    func moveToApp() {
        application.activate()
        
        isWindowOpened = true
        
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
                
                isWindowOpened = false
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
