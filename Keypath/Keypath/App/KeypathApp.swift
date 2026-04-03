//
//  KeypathApp.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/24/26.
//

import AppKit
import SwiftUI

@main
struct KeypathApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 1. We replace WindowGroup with MenuBarExtra so it lives in the top right!
        MenuBarExtra("Keypath", systemImage: "command.square") {
            
            // 2. Add some basic menu bar controls
            Button("Toggle Keypath HUD") {
                // Manually trigger your HUD from the menu bar as a fallback
                let manager = KeypathCommandManager.shared
                if appDelegate.commandListener.isListeningForPath {
                    PathsWindowManager.shared.hide()
                    manager.isShowingCommands = false
                    appDelegate.commandListener.isListeningForPath = false
                } else {
                    PathsWindowManager.shared.show()
                    appDelegate.commandListener.isListeningForPath = true
                }
            }
            .keyboardShortcut("k", modifiers: [.control, .option])
            
            Divider()
            
            Button("Quit Keypath") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
            
        }
    }
}
