//
//  Config.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/15/26.
//

import Foundation

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
        
        configDict["IS_AUTO_LAUNCH_ENABLED"] = !isEnabled
        
        defaults.set(configDict, forKey: key)
    }
    
    func getAutoLaunch() -> Bool {
        return (userDictionary()["IS_AUTO_LAUNCH_ENABLED"] as? Bool) ?? false
    }
}
