//
//  Keypath.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import AppKit
import ApplicationServices
import Foundation

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
        
        // 1. Accessibility API Check (Reliable for finding minimized status on current space)
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
           let windows = windowsValue as? [AXUIElement] {
            
            if !windows.isEmpty {
                for window in windows {
                    var minimizedValue: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue)
                    
                    if result == .success, let isMinimized = minimizedValue as? Bool {
                        if !isMinimized {
                            return true // Found a non-minimized window
                        }
                    } else {
                        // Could not verify minimized state, assume visible if it's an accessible window
                        return true
                    }
                }
                
                // If we get here, all accessible windows were minimized
                return false
            }
        }
        
        // 2. CoreGraphics Fallback (Useful if windows are on another space or Accessibility fails)
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid else { continue }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            
            // Ignore fully transparent windows
            if let alpha = window[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0.0 { continue }
            
            // Ignore windows that are too small (tooltips, invisible proxies, etc)
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let height = boundsDict["Height"] as? NSNumber,
               let width = boundsDict["Width"] as? NSNumber {
                if height.intValue <= 50 || width.intValue <= 50 {
                    continue
                }
            }
            
            // If a valid normal window is found, assume the app has a visible window somewhere
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
