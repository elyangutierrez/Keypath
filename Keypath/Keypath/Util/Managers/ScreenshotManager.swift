//
//  ScreenshotManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import Foundation
import ScreenCaptureKit

@Observable
final class ScreenshotManager {
    func getApplicationImage(app: NSRunningApplication) async throws -> CGImage? {
        let avaliableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let appWindow = avaliableContent.windows.first(where: { $0.owningApplication?.bundleIdentifier == app.bundleIdentifier }) else {
            throw ScreenshotError.noWindow
        }
        
        guard appWindow.isOnScreen else {
            return nil
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: appWindow)
        
        let configuration = SCScreenshotConfiguration()
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        
        guard let sdrImage = output.sdrImage else {
            throw ScreenshotError.noScreenshot
        }
        
        return sdrImage
    }
}
