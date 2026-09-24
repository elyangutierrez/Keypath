//
//  KeypathApp.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/24/26.
//

import AppKit
import CoreGraphics
import SwiftUI

@main
struct KeypathApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 1. We replace WindowGroup with MenuBarExtra so it lives in the top right!
        
        MenuBarExtra {

            Text(appDelegate.commandListener.statusMessage)
                .font(.caption)

            if appDelegate.commandListener.status != .listening {
                Button("Retry Keyboard Listener") {
                    appDelegate.commandListener.start()
                }
                Button("Open Accessibility Settings") {
                    if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
            }

            if !CGPreflightScreenCaptureAccess() {
                Button("Request Screen Recording Access", action: requestScreenRecordingAccess)
                Button("Open Screen Recording Settings", action: openScreenRecordingSettings)
            }

            Divider()

            Button("Toggle Auto-Launch") {
                let config = Config.shared
                config.setAutoLaunch()
            }

            Button("Show All Keypaths") {
                let manager = KeypathCommandManager.shared
                if appDelegate.commandListener.isListeningForPath {
                    RecentAppManager.shared.cancelPicker()
                    KeybindAssignmentCoordinator.shared.setUndoFocused(false)
                    manager.resetModes()
                    manager.resetIndex()
                    PathsWindowManager.shared.hide()
                    appDelegate.commandListener.isListeningForPath = false
                } else {
                    PathsWindowManager.shared.show()
                    appDelegate.commandListener.isListeningForPath = true
                }
            }

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

    private func requestScreenRecordingAccess() {
        _ = CGRequestScreenCaptureAccess()
    }

    private func openScreenRecordingSettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}
