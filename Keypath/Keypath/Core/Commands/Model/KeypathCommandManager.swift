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
    
    var currentIndex: Int = 0
    var currentNumberOfApps: Int = 0
    var currentPaths: [Keypath] = []
    
    private init() {}
    
    func setPaths(_ paths: [Keypath]) {
        currentPaths = paths
    }
    
    func shiftSelectionToLeft() {
        guard currentIndex > 0 else {
            return
        }
        
        currentIndex -= 1
    }
    
    func shiftSelectionToRight() {
        guard currentIndex < currentNumberOfApps - 1 else {
            return
        }
        
        currentIndex += 1
    }
    
    func resetIndex() {
        currentIndex = 0
    }
}
