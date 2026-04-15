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
        "IS_AUTO_LAUNCH_ENABLED": false
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
        
        // Synchronize with ServiceManagement
        syncAutoLaunch(isEnabled: newValue)
    }
    
    func getAutoLaunch() -> Bool {
        return (userDictionary()["IS_AUTO_LAUNCH_ENABLED"] as? Bool) ?? false
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
