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
        Settings {
            EmptyView()
        }
    }
}
