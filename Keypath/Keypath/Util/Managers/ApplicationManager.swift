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
    
    func getApplications() -> [ListApplication] {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let fileManager = FileManager.default
        var holder: [ListApplication] = []
        
        do {
            let appURLs = try fileManager.contentsOfDirectory(at: applicationsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for appURL in appURLs {
                if let bundle = Bundle(url: appURL), let bundleId = bundle.bundleIdentifier {
                    holder.append(ListApplication(location: appURL, bundleId: bundleId))
                }
            }
            
            return holder
        } catch {
            print("ERROR: \(error)")
        }
        
        return []
    }
    
    static func getPaths() -> [Keypath] {
        let workspace = NSWorkspace.shared
        let runningApplications = workspace.runningApplications
        
        let regularPolicyApplications = runningApplications.filter { $0.activationPolicy == .regular }
        
        let excludedApplications = Config.shared.getExcludedApps()
        
        let resultingApplications = regularPolicyApplications.filter { !excludedApplications.contains($0.localizedName ?? "") }
        
        var holder: [Keypath] = []
        
        for application in resultingApplications {
            holder.append(
                Keypath(application: application)
            )
        }
        
        return holder.sorted()
    }
}
