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
    static let pickerWidth: CGFloat = 590
    static let maximumPickerHeight: CGFloat = 465

    private static let cardRowHeight: CGFloat = 184
    private static let cardRowSpacing: CGFloat = 10
    private static let pickerVerticalPadding: CGFloat = 14
    private static let footerSpacing: CGFloat = 10
    private static let footerHeight: CGFloat = 18

    static func pageCount(for windowCount: Int) -> Int {
        max(1, (windowCount + windowsPerPage - 1) / windowsPerPage)
    }

    static func windowIndex(keyNumber: Int, pageIndex: Int, windowCount: Int) -> Int? {
        guard (1...windowsPerPage).contains(keyNumber), pageIndex >= 0 else { return nil }
        let index = pageIndex * windowsPerPage + keyNumber - 1
        return index < windowCount ? index : nil
    }

    static func pickerHeight(for visibleWindowCount: Int) -> CGFloat {
        let rowCount = max(1, (max(0, visibleWindowCount) + 1) / 2)
        let gridHeight: CGFloat
        if visibleWindowCount == 0 {
            gridHeight = 116
        } else {
            gridHeight = CGFloat(rowCount) * cardRowHeight
                + CGFloat(max(0, rowCount - 1)) * cardRowSpacing
        }

        let naturalHeight = pickerVerticalPadding * 2
            + gridHeight
            + footerSpacing
            + footerHeight
        return min(maximumPickerHeight, max(210, naturalHeight))
    }

    private(set) var isVisible = false
    private(set) var application: NSRunningApplication?
    private(set) var keybind: Keybind?
    private(set) var windows: [AccessibleWindow] = []
    private(set) var pageIndex = 0
    private(set) var errorMessage: String?
    private(set) var windowPreviews: [Int: CGImage] = [:]

    private var previousApplication: NSRunningApplication?
    private var errorClearTask: Task<Void, Never>?
    private var previewCaptureTask: Task<Void, Never>?
    private var previewCaptureGeneration = 0

    var pageCount: Int {
        Self.pageCount(for: windows.count)
    }

    var visibleWindows: [AccessibleWindow] {
        let startIndex = pageIndex * Self.windowsPerPage
        let endIndex = min(startIndex + Self.windowsPerPage, windows.count)
        guard startIndex < endIndex else { return [] }
        return Array(windows[startIndex..<endIndex])
    }

    var panelContentSize: CGSize {
        CGSize(width: Self.pickerWidth, height: Self.pickerHeight(for: visibleWindows.count))
    }

    private init() {}

    func begin(
        for application: NSRunningApplication,
        windows: [AccessibleWindow],
        keybind: Keybind?,
        returningTo previousApplication: NSRunningApplication?
    ) {
        clearState()
        self.application = application
        self.windows = windows
        self.keybind = keybind
        self.previousApplication = previousApplication
        isVisible = true
        schedulePreviewCapture()
    }

    func movePage(by offset: Int) {
        let updatedPageIndex = min(max(pageIndex + offset, 0), pageCount - 1)
        guard updatedPageIndex != pageIndex else { return }
        pageIndex = updatedPageIndex
        errorMessage = nil
        schedulePreviewCapture()
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
        schedulePreviewCapture()
    }

    private func schedulePreviewCapture() {
        previewCaptureTask?.cancel()
        previewCaptureGeneration += 1
        let generation = previewCaptureGeneration
        let page = pageIndex
        let pageWindows = visibleWindows
        guard isVisible, let application else {
            windowPreviews = [:]
            return
        }

        windowPreviews = [:]
        previewCaptureTask = Task { @MainActor [weak self] in
            let previews = await WindowPreviewCaptureService.capturePreviews(
                for: application,
                windows: pageWindows
            )
            guard let self,
                  !Task.isCancelled,
                  self.isVisible,
                  self.previewCaptureGeneration == generation,
                  self.pageIndex == page else {
                return
            }

            self.windowPreviews = previews
            self.previewCaptureTask = nil
        }
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
        previewCaptureTask?.cancel()
        previewCaptureTask = nil
        previewCaptureGeneration += 1
        errorClearTask?.cancel()
        errorClearTask = nil
        isVisible = false
        application = nil
        keybind = nil
        windows = []
        pageIndex = 0
        errorMessage = nil
        windowPreviews = [:]
        previousApplication = nil
    }
}
