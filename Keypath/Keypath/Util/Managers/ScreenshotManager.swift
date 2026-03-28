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
    func getApplicationImage(app: NSRunningApplication) async -> CGImage? {
        do {
            let avaliableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // only gets the apps that are running where Keypath is running
            guard let appWindow = avaliableContent.windows.first(where: { $0.owningApplication?.bundleIdentifier == app.bundleIdentifier }) else {
                return nil
            }
            
            guard appWindow.isOnScreen else {
                return nil
            }
            
            let filter = SCContentFilter(desktopIndependentWindow: appWindow)
            
            let configuration = SCScreenshotConfiguration()
            let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
            
            let image = output.sdrImage
            
            return image
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        return nil
    }
}
