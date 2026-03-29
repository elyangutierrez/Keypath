//
//  KeypathCommandManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

@Observable
final class KeypathCommandManager {
    static let shared = KeypathCommandManager()
    
    var isShowingCommands: Bool = false
    var isInSelectionMode: Bool = false
    
    private init() {}
}
