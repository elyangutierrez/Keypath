//
//  KeymapsTests.swift
//  KeypathTests
//
//  Created by Elyan Gutierrez on 4/28/26.
//

import Testing
@testable import Keypath

@MainActor
struct KeymapsTests {

    @Test func test_mappings() async {
        let keymaps = Keymaps()
        #expect(keymaps.mappings[18] == "1")
        #expect(keymaps.mappings[12] == "q")
    }
    
    @Test func test_validKeybindMappings() async {
        let keymaps = Keymaps()
        #expect(keymaps.validKeybindMappings[12] == "q")
        #expect(keymaps.validKeybindMappings[53] == nil)
    }
    
    @Test func test_reversed_mappings() async {
        var keymaps = Keymaps()
        let reversed = keymaps.reversed
        #expect(reversed["1"] == 18)
        #expect(reversed["q"] == 12)
    }
}
