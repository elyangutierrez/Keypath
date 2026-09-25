//
//  WindowPreviewCaptureService.swift
//  Keypath
//

import AppKit
import ScreenCaptureKit

@MainActor
enum WindowPreviewCaptureService {
    static func capturePreviews(
        for application: NSRunningApplication,
        windows: [AccessibleWindow]
    ) async -> [Int: CGImage] {
        guard !windows.isEmpty,
              let shareableContent = try? await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: false
              ) else {
            return [:]
        }

        let applicationWindows = shareableContent.windows.filter {
            $0.owningApplication?.processID == application.processIdentifier
        }

        var previews: [Int: CGImage] = [:]
        for window in windows {
            guard !Task.isCancelled,
                  !window.isMinimized,
                  let shareableWindow = uniqueMatch(for: window, in: applicationWindows) else {
                continue
            }

            do {
                let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
                let configuration = SCScreenshotConfiguration()
                configuration.showsCursor = false
                configuration.includeChildWindows = true
                configureResolution(configuration, for: shareableWindow)

                if let image = try await SCScreenshotManager.captureScreenshot(
                    contentFilter: filter,
                    configuration: configuration
                ).sdrImage {
                    guard !Task.isCancelled else { return [:] }
                    previews[window.number] = image
                }
            } catch {
                // A missing preview is represented by the card's neutral placeholder.
            }
        }

        return previews
    }

    private static func uniqueMatch(
        for accessibleWindow: AccessibleWindow,
        in shareableWindows: [SCWindow]
    ) -> SCWindow? {
        if let windowID = accessibleWindow.windowID {
            let idMatches = shareableWindows.filter { $0.windowID == windowID }
            if idMatches.count == 1 { return idMatches[0] }
            if !idMatches.isEmpty { return nil }
        }

        guard let accessibilityFrame = accessibleWindow.frame else { return nil }

        let candidates = shareableWindows.filter { shareableWindow in
            if let accessibilityTitle = accessibleWindow.captureTitle,
               shareableWindow.title != accessibilityTitle {
                return false
            }

            return framesMatch(accessibilityFrame, shareableWindow.frame)
        }

        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }

    private static func framesMatch(_ accessibilityFrame: CGRect, _ shareableFrame: CGRect) -> Bool {
        let positionTolerance: CGFloat = 8
        let sizeTolerance: CGFloat = 12
        return abs(accessibilityFrame.minX - shareableFrame.minX) <= positionTolerance
            && abs(accessibilityFrame.minY - shareableFrame.minY) <= positionTolerance
            && abs(accessibilityFrame.width - shareableFrame.width) <= sizeTolerance
            && abs(accessibilityFrame.height - shareableFrame.height) <= sizeTolerance
    }

    private static func configureResolution(
        _ configuration: SCScreenshotConfiguration,
        for window: SCWindow
    ) {
        let frame = window.frame
        guard frame.width > 0, frame.height > 0 else { return }

        let maximumDimension: CGFloat = 1_280
        let scale = min(2, maximumDimension / max(frame.width, frame.height))
        configuration.width = max(1, Int(frame.width * scale))
        configuration.height = max(1, Int(frame.height * scale))
    }
}
