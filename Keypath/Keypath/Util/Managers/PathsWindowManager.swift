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

    static let pathsContentSize = NSSize(width: 650, height: 465)
    static let recentAppsContentSize = NSSize(width: 472, height: 372)
    
    private var panel: NSPanel?
    private var isShowingRecentApps = false
    
    private init() {} // Prevent multiple instances
    
    func setupPanel<V: View>(with view: V) {
        // Wrap your SwiftUI View in an AppKit ViewController
        let hostingController = NSHostingController(rootView: view)
        
        // Initialize the NSPanel
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.pathsContentSize),
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
                
                let frame = panel.frame
                let x = screenRect.midX - frame.width / 2
                let y = screenRect.midY - frame.height / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }

    /// Resizes the existing floating panel so the recent-app picker is the only visible content.
    /// The panel keeps its current center while switching between the picker and the main HUD.
    func setRecentAppsMode(_ isShowingRecentApps: Bool) {
        guard self.isShowingRecentApps != isShowingRecentApps,
              let panel else { return }

        self.isShowingRecentApps = isShowingRecentApps
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let contentSize = isShowingRecentApps ? Self.recentAppsContentSize : Self.pathsContentSize
        panel.setContentSize(contentSize)

        let resizedFrame = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: center.x - resizedFrame.width / 2,
            y: center.y - resizedFrame.height / 2
        ))
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
