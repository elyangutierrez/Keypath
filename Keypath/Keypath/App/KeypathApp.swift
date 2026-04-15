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
        
        MenuBarExtra {
            
            Button("Toggle Auto-Launch") {
                let config = Config.shared
                
                config.setAutoLaunch()
            }
            
            Button("Show All Keypaths") {
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

            Divider()
            
            Button("Quit Keypath") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 14
                $0.size.width = 15 / ratio
                return $0
            } (NSImage(resource: .superKeyLight))

            Image(nsImage: image)
        }
        .menuBarExtraStyle(.menu)
    }
}
