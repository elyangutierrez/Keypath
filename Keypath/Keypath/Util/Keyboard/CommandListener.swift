//
//  CommandListener.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import CoreGraphics
import Foundation
import Observation
import SwiftData

@Observable
final class CommandListener {
    var isComboPrimed = false
    var isListeningForPath = false
    private var eventTap: CFMachPort?
    
    var keymaps = Keymaps()
    
    var commandManager = KeypathCommandManager.shared

    func start() {
        // We want to listen for modifier key changes (Ctrl/Option) and normal key downs
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        
        // Pass 'self' via an Unmanaged pointer so the C-callback can communicate back
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        // Create the tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                
                let listener = Unmanaged<CommandListener>.fromOpaque(refcon).takeUnretainedValue()
                
                return listener.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            print("Failed to create event tap. Make sure you have Accessibility permissions!")
            return
        }
        
        self.eventTap = tap
        
        // Add the tap to the main run loop so it listens constantly in the background
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("CommandListener is actively monitoring keystrokes.")
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown {
            isComboPrimed = false
            
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            
            let hasControl = flags.contains(.maskControl)
            let hasOption = flags.contains(.maskAlternate)
            
            if hasControl && hasOption && keyCode == keymaps.reversed["k"] {
                
                if isListeningForPath {
                    commandManager.isShowingCommands = false
                    isListeningForPath = false
                    Task { @MainActor in
                        PathsWindowManager.shared.hide()
                    }
                } else {
                    isListeningForPath = true
                    Task { @MainActor in
                        PathsWindowManager.shared.show()
                    }
                }
                
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["c"] && isListeningForPath {
                Task { @MainActor in
                    self.commandManager.isShowingCommands.toggle()
                }
                
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["s"] {
                Task { @MainActor in
                    self.commandManager.isInSelectionMode.toggle()
                    
                    if !self.commandManager.isInSelectionMode {
                        self.commandManager.resetIndex()
                    }
                }
                
                return nil
            }
            
            if hasControl && hasOption && commandManager.isInSelectionMode &&
                keyCode == keymaps.reversed["leftarrow"]
            {
                // shift selection by one to left via index
                Task { @MainActor in
                    self.commandManager.shiftSelectionToLeft()
                }
                return nil
            }
            
            if hasControl && hasOption && commandManager.isInSelectionMode &&
                keyCode == keymaps.reversed["rightarrow"]
            {
                // shift selection by one to right via index
                Task { @MainActor in
                    self.commandManager.shiftSelectionToRight()
                }
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["u"] {
                Task { @MainActor in
                    self.commandManager.isInKeybindUpdateMode.toggle()
//                    print("Listening for new keybind...") # DEBUG
                }
                return nil
            }
            
            if commandManager.isInKeybindUpdateMode {
                
                if keyCode == keymaps.reversed["esc"] {
                    Task { @MainActor in
                        self.commandManager.isInKeybindUpdateMode = false
//                        print("Cancelled keybind update.") # DEBUG
                    }
                    return nil
                }
                
                let newKeyString = self.keymaps.validKeybindMappings[keyCode]?.uppercased()
                
                guard let keyString = newKeyString else {
                    return nil
                }
                
                if !keyString.isEmpty {
                    
//                    print("Key string: \(keyString)") # DEBUG
                   
                    Task { @MainActor in
                        let activeIndex = self.commandManager.currentIndex
                        let context = DataManager.shared.context
                        
                        if let duplicateIndex = self.commandManager.currentPaths.firstIndex(where: { path in
                            if let existingBind = path.keybind, case let .letter(existingChar) = existingBind.key3 {
                                return existingChar == keyString
                            }
                            return false
                        }) {
                            if duplicateIndex != activeIndex {
                                self.commandManager.currentPaths[duplicateIndex].keybind = nil
                                let oldAppName = self.commandManager.currentPaths[duplicateIndex].application.localizedName ?? "App"
                                
                                if let stolenSave = DataManager.shared.fetchSavedKeybind(for: oldAppName) {
                                    context.delete(stolenSave)
                                }
                                
                            }
                        }
                        
                        let newBind = Keybind(
                            key1: .symbol("control"),
                            key2: .symbol("option"),
                            key3: .letter(keyString)
                        )
                        
                        self.commandManager.currentPaths[activeIndex].keybind = newBind
                        let targetAppName = self.commandManager.currentPaths[activeIndex].application.localizedName ?? "App"
                        
                        if let existingSave = DataManager.shared.fetchSavedKeybind(for: targetAppName) {
                            existingSave.keybind = newBind
                        } else {
                            let newSave = SavedKeybind(appName: targetAppName, keybind: newBind)
                            context.insert(newSave)
                        }
                        
                        try? context.save()
//                        print("Saved '\(keyString)' to SwiftData for \(targetAppName)") # DEBUG
                        
                        self.commandManager.isInKeybindUpdateMode = false
                    }
                }
                
                return nil
            }
            
            // --- THE LOOKUP AND LAUNCH BLOCK ---
            if hasControl && hasOption && !commandManager.isInKeybindUpdateMode {
                
                // 1. Get the raw string directly from your Keymaps dictionary!
                // We grab the string and immediately uppercase it so 'c' becomes 'C'
                if let pressedString = self.keymaps.mappings[keyCode]?.uppercased() {
                    
                    // 2. Scan the currentPaths array for a match
                    if let matchedPath = self.commandManager.currentPaths.first(where: { path in
                        if let existingBind = path.keybind, case let .letter(existingChar) = existingBind.key3 {
                            return existingChar == pressedString
                        }
                        return false
                    }) {
                        Task { @MainActor in
                            
                            if matchedPath.isWindowOpened && matchedPath.application.isActive {
                                matchedPath.moveFromApp()
                            } else {
                                matchedPath.moveToApp()
                            }
                            
                            self.isListeningForPath = false
                            self.commandManager.isShowingCommands = false
                            self.commandManager.resetIndex()
                            PathsWindowManager.shared.hide()
                        }
                        
                        return nil
                    }
                }
            }
            
            if isListeningForPath {
                
                if keyCode == keymaps.reversed["esc"] {
                    commandManager.isShowingCommands = false
                    commandManager.resetIndex()
                    isListeningForPath = false
                    Task { @MainActor in
                        PathsWindowManager.shared.hide()
                    }
                    return nil
                }
                
                return nil
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
}
