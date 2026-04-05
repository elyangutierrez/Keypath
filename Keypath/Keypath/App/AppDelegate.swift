//
//  AppDelegate.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import Foundation
import ApplicationServices // Required for AX functions
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let commandListener = CommandListener()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            print("App is running invisibly in the background!")
            
            PathsWindowManager.shared.setupPanel(with: PathsView())
            KeybindsListWindowManager.shared.setupPanel(with: KeybindsListView())
            
            commandListener.start()
        #endif
    }
}
