//
//  PreviewManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 5/2/26.
//

import CoreGraphics
import Foundation

@Observable
class PreviewManager {
    
    static let shared = PreviewManager()

    var previews: [pid_t : PathPreview] = [:]
    
    private init() {}
    
    func registerPath(processID: pid_t) {
        if previews[processID] == nil {
            previews[processID] = PathPreview()
        }
    }
    
    func addPreview(_ screenshotImage: CGImage, _ cachedImage: CGImage, _ processID: pid_t) {
        var preview = previews[processID] ?? PathPreview()
        preview.screenshotImage = screenshotImage
        preview.cachedImage = cachedImage
        previews[processID] = preview
    }
    
    func resetPreview(processID: pid_t) {
        var preview = previews[processID] ?? PathPreview()
        preview.screenshotImage = nil
        previews[processID] = preview
    }
    
    func getPreview(processID: pid_t) -> PathPreview? {
        return previews[processID]
    }
    
    func removePath(processID: pid_t) {
        previews[processID] = nil
    }
}
