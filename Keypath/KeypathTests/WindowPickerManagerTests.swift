//
//  WindowPickerManagerTests.swift
//  KeypathTests
//

import CoreGraphics
import Testing
@testable import Keypath

@MainActor
struct WindowPickerManagerTests {
    @Test func pageCountAndDigitSelectionHandleEmptySingleAndPagedWindowLists() {
        #expect(WindowPickerManager.pageCount(for: 0) == 1)
        #expect(WindowPickerManager.windowIndex(keyNumber: 1, pageIndex: 0, windowCount: 0) == nil)

        #expect(WindowPickerManager.pageCount(for: 1) == 1)
        #expect(WindowPickerManager.windowIndex(keyNumber: 1, pageIndex: 0, windowCount: 1) == 0)
        #expect(WindowPickerManager.windowIndex(keyNumber: 2, pageIndex: 0, windowCount: 1) == nil)

        #expect(WindowPickerManager.pageCount(for: 3) == 1)
        #expect(WindowPickerManager.windowIndex(keyNumber: 3, pageIndex: 0, windowCount: 3) == 2)

        #expect(WindowPickerManager.pageCount(for: 10) == 2)
        #expect(WindowPickerManager.windowIndex(keyNumber: 1, pageIndex: 1, windowCount: 10) == 9)
        #expect(WindowPickerManager.windowIndex(keyNumber: 2, pageIndex: 1, windowCount: 10) == nil)
        #expect(WindowPickerManager.windowIndex(keyNumber: 0, pageIndex: 1, windowCount: 10) == nil)
    }

    @Test func pickerHeightFitsShortGridsAndCapsLongGrids() {
        #expect(WindowPickerManager.pickerHeight(for: 0) == 210)
        #expect(WindowPickerManager.pickerHeight(for: 1) == 240)
        #expect(WindowPickerManager.pickerHeight(for: 2) == 240)
        #expect(WindowPickerManager.pickerHeight(for: 3) == 434)
        #expect(WindowPickerManager.pickerHeight(for: 9) == 465)
        #expect(WindowPickerManager.pickerHeight(for: 10) == 465)
    }
}
