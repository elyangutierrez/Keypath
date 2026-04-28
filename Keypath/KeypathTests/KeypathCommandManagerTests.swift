//
//  KeypathCommandManagerTests.swift
//  KeypathTests
//
//  Created by Elyan Gutierrez on 4/28/26.
//

import Testing
import AppKit
@testable import Keypath

@MainActor
struct KeypathCommandManagerTests {

    @Test func test_initialization() async {
        let manager = KeypathCommandManager()
        #expect(manager.currentIndex == 0)
        #expect(manager.isShowingCommands == false)
        #expect(manager.isInSelectionMode == false)
    }
    
    @Test func test_setPaths() async {
        let manager = KeypathCommandManager()
        
        // Mock some apps for Keypath
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        guard !runningApps.isEmpty else { return }
        
        let paths = [
            Keypath(application: runningApps[0]),
            Keypath(application: runningApps[0])
        ]
        
        manager.setPaths(paths)
        #expect(manager.currentPaths.count == 2)
        #expect(manager.currentNumberOfApps == 2)
        #expect(manager.currentIndex == 0)
        
        // Test clamping
        manager.shiftSelectionToRight() // index 1
        manager.setPaths([Keypath(application: runningApps[0])])
        #expect(manager.currentIndex == 0)
        #expect(manager.currentNumberOfApps == 1)
        
        // Test empty
        manager.setPaths([])
        #expect(manager.currentIndex == 0)
        #expect(manager.currentNumberOfApps == 0)
    }
    
    @Test func test_shifting() async {
        let manager = KeypathCommandManager()
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard !runningApps.isEmpty else { return }
        
        let paths = [
            Keypath(application: runningApps[0]),
            Keypath(application: runningApps[0]),
            Keypath(application: runningApps[0])
        ]
        
        manager.setPaths(paths)
        
        manager.shiftSelectionToRight()
        #expect(manager.currentIndex == 1)
        
        manager.shiftSelectionToRight()
        #expect(manager.currentIndex == 2)
        
        manager.shiftSelectionToRight()
        #expect(manager.currentIndex == 2)
        
        manager.shiftSelectionToLeft()
        #expect(manager.currentIndex == 1)
        
        manager.shiftSelectionToLeft()
        #expect(manager.currentIndex == 0)
        
        manager.shiftSelectionToLeft()
        #expect(manager.currentIndex == 0)
    }
    
    @Test func test_resetIndex() async {
        let manager = KeypathCommandManager()
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard !runningApps.isEmpty else { return }
        
        manager.setPaths([Keypath(application: runningApps[0]), Keypath(application: runningApps[0])])
        manager.shiftSelectionToRight()
        #expect(manager.currentIndex == 1)
        
        manager.resetIndex()
        #expect(manager.currentIndex == 0)
    }
}
