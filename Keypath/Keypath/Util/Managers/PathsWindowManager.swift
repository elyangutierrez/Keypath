//
//  PathsWindowManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import Foundation
import SwiftUI

class PathsWindowManager {
    static let shared = PathsWindowManager()
    
    private var panel: NSPanel?
    
    private init() {} // Prevent multiple instances
    
    func setupPanel<V: View>(with view: V) {
        // Wrap your SwiftUI View in an AppKit ViewController
        let hostingController = NSHostingController(rootView: view)
        
        // Initialize the NSPanel
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 465), // Size of your view
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        if let panel = panel {
            
            // Critical Settings for a HUD/Command Window
            panel.level = .floating // Stays on top of normal windows
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Appears over fullscreen apps!
            panel.isMovableByWindowBackground = true
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            // ... existing panel configuration above ...
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.contentViewController = hostingController

            // 1. Find which screen the user is currently focused on (based on mouse position)
            let mouseLocation = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main

            // 2. Mathematically calculate the dead center of that specific screen
            if let screen = targetScreen {
                let screenRect = screen.frame
                
                // Using the exact dimensions you set in your contentRect
                let panelWidth: CGFloat = 650
                let panelHeight: CGFloat = 425
                
                let x = screenRect.minX + (screenRect.width - panelWidth) / 2
                let y = screenRect.minY + (screenRect.height - panelHeight) / 2
                
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    func show() {
        // Brings the panel to the front and makes it the "key" window to receive text input
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        panel?.orderOut(nil)
    }
}
