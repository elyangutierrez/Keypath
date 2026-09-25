//
//  WindowPickerManager.swift
//  Keypath
//

import AppKit
import Observation

@Observable
@MainActor
final class WindowPickerManager {
    static let shared = WindowPickerManager()
    static let windowsPerPage = 9

    static func pageCount(for windowCount: Int) -> Int {
        max(1, (windowCount + windowsPerPage - 1) / windowsPerPage)
    }

    static func windowIndex(keyNumber: Int, pageIndex: Int, windowCount: Int) -> Int? {
        guard (1...windowsPerPage).contains(keyNumber), pageIndex >= 0 else { return nil }
        let index = pageIndex * windowsPerPage + keyNumber - 1
        return index < windowCount ? index : nil
    }

    private(set) var isVisible = false
    private(set) var application: NSRunningApplication?
    private(set) var windows: [AccessibleWindow] = []
    private(set) var pageIndex = 0
    private(set) var errorMessage: String?

    private var previousApplication: NSRunningApplication?
    private var errorClearTask: Task<Void, Never>?

    var pageCount: Int {
        Self.pageCount(for: windows.count)
    }

    var visibleWindows: [AccessibleWindow] {
        let startIndex = pageIndex * Self.windowsPerPage
        let endIndex = min(startIndex + Self.windowsPerPage, windows.count)
        guard startIndex < endIndex else { return [] }
        return Array(windows[startIndex..<endIndex])
    }

    var visibleWindowRange: ClosedRange<Int>? {
        guard !windows.isEmpty else { return nil }
        let firstNumber = pageIndex * Self.windowsPerPage + 1
        let lastNumber = min(firstNumber + Self.windowsPerPage - 1, windows.count)
        return firstNumber...lastNumber
    }

    private init() {}

    func begin(
        for application: NSRunningApplication,
        windows: [AccessibleWindow],
        returningTo previousApplication: NSRunningApplication?
    ) {
        clearState()
        self.application = application
        self.windows = windows
        self.previousApplication = previousApplication
        isVisible = true
    }

    func movePage(by offset: Int) {
        pageIndex = min(max(pageIndex + offset, 0), pageCount - 1)
        errorMessage = nil
    }

    func activateWindow(keyNumber: Int) -> Bool {
        guard let index = Self.windowIndex(
            keyNumber: keyNumber,
            pageIndex: pageIndex,
            windowCount: windows.count
        ),
              let application else {
            return false
        }

        guard ApplicationWindowAccessibility.activate(windows[index], in: application) else {
            refreshWindows()
            showError("That window is no longer available. The list has been refreshed.")
            return false
        }
        return true
    }

    func cancel() {
        if let previousApplication,
           previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier,
           !previousApplication.isTerminated {
            previousApplication.activate(options: [])
        }
        clearState()
    }

    func finish() {
        clearState()
    }

    private func refreshWindows() {
        guard let application else { return }
        windows = ApplicationWindowAccessibility.windows(for: application)
        pageIndex = min(pageIndex, pageCount - 1)
    }

    private func showError(_ message: String) {
        errorClearTask?.cancel()
        errorMessage = message
        errorClearTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            self?.errorMessage = nil
        }
    }

    private func clearState() {
        errorClearTask?.cancel()
        errorClearTask = nil
        isVisible = false
        application = nil
        windows = []
        pageIndex = 0
        errorMessage = nil
        previousApplication = nil
    }
}
