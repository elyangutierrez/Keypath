//
//  DataManagerTests.swift
//  KeypathTests
//
//  Created by Elyan Gutierrez on 4/28/26.
//

import Testing
import SwiftData
@testable import Keypath

@MainActor
struct DataManagerTests {

    @Test func test_initialization() async throws {
        let manager = DataManager(isStoredInMemoryOnly: true)
        #expect(manager.fetchAllSavedKeybinds().isEmpty)
    }
    
    @Test func test_save_and_fetch() async throws {
        let manager = DataManager(isStoredInMemoryOnly: true)
        
        let appName = "TestApp"
        let keybind = Keybind(key1: .letter("C"), key2: .letter("K"))
        let savedKeybind = SavedKeybind(appName: appName, keybind: keybind)
        
        manager.context.insert(savedKeybind)
        try manager.context.save()
        
        let fetched = manager.fetchSavedKeybind(for: appName)
        #expect(fetched != nil)
        #expect(fetched?.appName == appName)
        
        if case let .letter(char) = fetched?.keybind.key1 {
            #expect(char == "C")
        }
    }
    
    @Test func test_fetchAllSavedKeybinds() async throws {
        let manager = DataManager(isStoredInMemoryOnly: true)
        
        let kb1 = SavedKeybind(appName: "App1", keybind: Keybind(key1: .letter("A"), key2: .letter("1")))
        let kb2 = SavedKeybind(appName: "App2", keybind: Keybind(key1: .letter("A"), key2: .letter("2")))
        
        manager.context.insert(kb1)
        manager.context.insert(kb2)
        try manager.context.save()
        
        let all = manager.fetchAllSavedKeybinds()
        #expect(all.count == 2)
    }
    
    @Test func test_remove_all() async throws {
        let manager = DataManager(isStoredInMemoryOnly: true)
        
        let kb = SavedKeybind(appName: "App1", keybind: Keybind(key1: .letter("A"), key2: .letter("1")))
        manager.context.insert(kb)
        try manager.context.save()
        
        #expect(manager.fetchAllSavedKeybinds().count == 1)
        
        manager.removeAllSavedKeybinds()
        #expect(manager.fetchAllSavedKeybinds().count == 0)
    }
}
