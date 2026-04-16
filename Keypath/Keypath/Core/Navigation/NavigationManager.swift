//
//  NavigationManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 4/16/26.
//

import Foundation

@Observable
class NavigationManager {
    
    static let shared = NavigationManager()
    
    private init() {}
    
    var route: Route = .paths
    
    func setRoute(_ route: Route) {
        self.route = route
    }
}
