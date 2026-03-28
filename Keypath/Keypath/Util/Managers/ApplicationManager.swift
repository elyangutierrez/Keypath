//
//  ApplicationManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/27/26.
//

import AppKit
import Foundation

@Observable
final class ApplicationManager {
    let workspace = NSWorkspace.shared
    
    func getRunningApplications() -> [NSRunningApplication] {
        let runningApplications = workspace.runningApplications
        
        let regularPolicyApplications = runningApplications.filter { $0.activationPolicy == .regular }
        
        let excludedApplications = ["Finder"]
        
        let resultingApplications = regularPolicyApplications.filter { !excludedApplications.contains($0.localizedName ?? "") }
        
        return resultingApplications
    }
}
