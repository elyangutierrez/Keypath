//
//  Config.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/15/26.
//

import Foundation
import ServiceManagement

class Config {
    
    static let shared = Config()
    
    let defaults = UserDefaults.standard
    let key = "CONFIGDICT"
    
    var configDictionary: [String: Any] = [
        "IS_AUTO_LAUNCH_ENABLED": false,
        "EXCLUDED_APPS": ["Finder", "Preview"]
    ]
    
    init() {}
    
    func userDictionary() -> [String: Any] {
        return defaults.dictionary(forKey: key) ?? configDictionary
    }
    
    func setAutoLaunch() {
        var configDict = userDictionary()
        
        guard let isEnabled = configDict["IS_AUTO_LAUNCH_ENABLED"] as? Bool else { return }
        
        let newValue = !isEnabled
        configDict["IS_AUTO_LAUNCH_ENABLED"] = newValue
        
        defaults.set(configDict, forKey: key)
        
        syncAutoLaunch(isEnabled: newValue)
    }
    
    func getAutoLaunch() -> Bool {
        return (userDictionary()["IS_AUTO_LAUNCH_ENABLED"] as? Bool) ?? false
    }
    
    func getExcludedApps() -> [String] {
        return (userDictionary()["EXCLUDED_APPS"] as? [String]) ?? ["Finder", "Preview"]
    }
    
    func addExcludedApp(_ appName: String) {
        var configDict = userDictionary()
        var excludedApps = getExcludedApps()
        if !excludedApps.contains(appName) {
            excludedApps.append(appName)
            configDict["EXCLUDED_APPS"] = excludedApps
            defaults.set(configDict, forKey: key)
            NotificationCenter.default.post(name: .excludedAppsDidChange, object: nil)
        }
    }
    
    func removeExcludedApp(_ appName: String) {
        var configDict = userDictionary()
        var excludedApps = getExcludedApps()
        if let index = excludedApps.firstIndex(of: appName) {
            excludedApps.remove(at: index)
            configDict["EXCLUDED_APPS"] = excludedApps
            defaults.set(configDict, forKey: key)
            NotificationCenter.default.post(name: .excludedAppsDidChange, object: nil)
        }
    }
    
    func syncAutoLaunch(isEnabled: Bool) {
        let service = SMAppService.mainApp
        
        do {
            if isEnabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("Failed to update auto-launch status: \(error)")
        }
    }
}
extension Notification.Name {
    static let excludedAppsDidChange = Notification.Name("ExcludedAppsDidChange")
}

