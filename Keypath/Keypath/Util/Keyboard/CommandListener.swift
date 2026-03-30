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

// 1. The C-style callback function required by CoreGraphics
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Retrieve our CommandListener instance from the refcon pointer
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let listener = Unmanaged<CommandListener>.fromOpaque(refcon).takeUnretainedValue()
    
    // Route the event back into our Swift class
    return listener.handleEvent(proxy: proxy, type: type, event: event)
}

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
            callback: eventTapCallback,
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
                    DispatchQueue.main.async { PathsWindowManager.shared.hide() }
                } else {
                    isListeningForPath = true
                    DispatchQueue.main.async { PathsWindowManager.shared.show() }
                }
                
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["c"] && isListeningForPath {
                DispatchQueue.main.async {
                    self.commandManager.isShowingCommands.toggle()
                }
                
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["s"] {
                DispatchQueue.main.async {
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
                DispatchQueue.main.async {
                    self.commandManager.shiftSelectionToLeft()
                }
                return nil
            }
            
            if hasControl && hasOption && commandManager.isInSelectionMode &&
                keyCode == keymaps.reversed["rightarrow"]
            {
                // shift selection by one to right via index
                DispatchQueue.main.async {
                    self.commandManager.shiftSelectionToRight()
                }
                return nil
            }
            
            if hasControl && hasOption && keyCode == keymaps.reversed["u"] {
                DispatchQueue.main.async {
                    self.commandManager.isInKeybindUpdateMode.toggle()
                    print("Listening for new keybind...")
                }
                return nil
            }
            
            if commandManager.isInKeybindUpdateMode {
                
                if keyCode == keymaps.reversed["esc"] {
                    DispatchQueue.main.async {
                        self.commandManager.isInKeybindUpdateMode = false
                        print("Cancelled keybind update.")
                    }
                    return nil
                }
                
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
                
                let newKeyString = String(utf16CodeUnits: chars, count: length).uppercased()
                
                if !newKeyString.isEmpty {
                    // SwiftData requires operations to run on the MainActor, which DispatchQueue.main.async handles!
                    DispatchQueue.main.async {
                        let activeIndex = self.commandManager.currentIndex
                        let context = DataManager.shared.context
                        
                        // --- 1. HANDLE DUPLICATES (STEALING) ---
                        if let duplicateIndex = self.commandManager.currentPaths.firstIndex(where: { path in
                            if let existingBind = path.keybind, case let .letter(existingChar) = existingBind.key3 {
                                return existingChar == newKeyString
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
                            key3: .letter(newKeyString)
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
                        print("Saved '\(newKeyString)' to SwiftData for \(targetAppName)")
                        
                        self.commandManager.isInKeybindUpdateMode = false
                    }
                }
                
                return nil
            }
            
            if isListeningForPath {
                
                if keyCode == keymaps.reversed["esc"] {
                    commandManager.isShowingCommands = false
                    commandManager.resetIndex()
                    isListeningForPath = false
                    DispatchQueue.main.async { PathsWindowManager.shared.hide() }
                    return nil
                }
                
                return nil
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
}
