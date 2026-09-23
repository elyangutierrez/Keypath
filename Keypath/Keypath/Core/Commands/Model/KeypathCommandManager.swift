//
//  KeypathCommandManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

@Observable
final class KeypathCommandManager {
    static let shared = KeypathCommandManager()
    
    var isShowingCommands: Bool = false
    var isInSelectionMode: Bool = false
    var isInKeybindUpdateMode: Bool = false
    var isShowingKeybinds: Bool = false
    var hasUpdatedKeybinds: Bool = false
    
    var currentIndex: Int = 0
    var currentNumberOfApps: Int = 0
    var currentPaths: [Keypath] = []
    
    init() {}
    
    func setPaths(_ paths: [Keypath]) {
        currentPaths = paths
        currentNumberOfApps = paths.count
        
        if currentIndex >= currentNumberOfApps && currentNumberOfApps > 0 {
            currentIndex = currentNumberOfApps - 1
        } else if currentNumberOfApps == 0 {
            currentIndex = 0
        }
    }
    
    func shiftSelectionToLeft() {
        shiftSelection(by: -1)
    }
    
    func shiftSelectionToRight() {
        shiftSelection(by: 1)
    }

    func shiftSelection(by offset: Int) {
        guard currentNumberOfApps > 0 else { return }
        currentIndex = min(max(currentIndex + offset, 0), currentNumberOfApps - 1)
    }
    
    func resetIndex() {
        currentIndex = 0
    }
    
    func resetModes() {
        isInSelectionMode = false
        isInKeybindUpdateMode = false
        isShowingCommands = false
        isShowingKeybinds = false
    }
}
