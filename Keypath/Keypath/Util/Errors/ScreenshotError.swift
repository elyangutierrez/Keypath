//
//  ScreenshotError.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/31/26.
//

import Foundation

enum ScreenshotError: LocalizedError {
    case noScreenshot
    case noWindow
    
    var title: String {
        switch self {
        case .noScreenshot:
            return "No Screenshot"
        case .noWindow:
            return "No Window"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noScreenshot:
            "Failed to get a valid screenshot of the window."
        case .noWindow:
            "Failed to get a valid window to take a screenshot of."
        }
    }
}
