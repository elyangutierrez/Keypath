//
//  AppState.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

@Observable
final class AppState {
    static let shared = AppState()
    
    var isShowingCommands: Bool = false
    
    private init() {}
}
