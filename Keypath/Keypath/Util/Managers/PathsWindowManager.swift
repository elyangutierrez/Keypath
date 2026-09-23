//
//  PathsWindowManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import Foundation
import SwiftUI

private final class KeypathHUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

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
        panel = KeypathHUDPanel(
            contentRect: NSRect(origin: .zero, size: Self.pathsContentSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        if let panel = panel {
            
            // Critical Settings for a HUD/Command Window
            panel.level = .floating // Stays on top of normal windows
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Appears over fullscreen apps!
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.contentViewController = hostingController

            centerPanel(on: screenUnderPointer ?? NSScreen.main)
        }
    }

    /// Resizes the existing floating panel so the recent-app picker is the only visible content.
    /// The panel keeps its current center while switching between the picker and the main HUD.
    func setRecentAppsMode(_ isShowingRecentApps: Bool) {
        guard self.isShowingRecentApps != isShowingRecentApps,
              let panel else { return }

        self.isShowingRecentApps = isShowingRecentApps
        let contentSize = isShowingRecentApps ? Self.recentAppsContentSize : Self.pathsContentSize
        panel.setContentSize(contentSize)
        centerPanel(on: panel.screen ?? screenUnderPointer ?? NSScreen.main)
    }
    
    func show() {
        centerPanel(on: screenUnderPointer ?? NSScreen.main)
        // Brings the panel to the front and makes it the "key" window to receive text input
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        panel?.orderOut(nil)
    }

    private var screenUnderPointer: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func centerPanel(on screen: NSScreen?) {
        guard let panel, let screen else { return }
        let screenFrame = screen.frame
        let panelFrame = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: screenFrame.midX - panelFrame.width / 2,
            y: screenFrame.midY - panelFrame.height / 2
        ))
    }
}
