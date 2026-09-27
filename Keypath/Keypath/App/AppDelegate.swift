//
//  AppDelegate.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import CoreServices
import Foundation
import ApplicationServices // Required for AX functions
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let commandListener = CommandListener()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Xcode's DerivedData app may not be indexed by Launch Services. TCC needs
        // the Debug bundle ID to resolve to this app for Screen Recording consent.
        let registrationStatus = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        if registrationStatus != noErr {
            print("Failed to register Keypath Debug with Launch Services: \(registrationStatus)")
        }
        #endif

        // Ensure auto-launch status matches user preference
        Config.shared.syncAutoLaunch(isEnabled: Config.shared.getAutoLaunch())
        
        #if DEBUG
            print("App is running invisibly in the background!")
        #endif
        
        PathsWindowManager.shared.setupPanel(with: RootView())

        commandListener.onKeybindAssignmentRequested = { application, key in
            KeybindAssignmentCoordinator.shared.requestAssignment(
                appName: application.localizedName ?? "Unknown App",
                bundleID: application.bundleIdentifier,
                key: key
            )
        }
        RecentAppManager.shared.startObserving()
        commandListener.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        commandListener.stop()
    }
}
