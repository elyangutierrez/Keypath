//
//  AppDelegate.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import Foundation
import ApplicationServices // Required for AX functions

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let commandListener = CommandListener()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App is running invisibly in the background!")
        
       
        guard checkAccessibilityPermissions() else {
            print("Accessibility permissions not granted. Waiting for user to enable them.")
            return
        }
        
        PathsWindowManager.shared.setupPanel(with: PathsView())
        
        commandListener.start()
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        // Create the options dictionary to tell macOS to prompt the user if needed
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptionPrompt: true] as CFDictionary
        
        // This function returns true if we already have permission.
        // If we return false, passing the options dictionary forces the macOS system prompt to appear.
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        return isTrusted
    }
}
