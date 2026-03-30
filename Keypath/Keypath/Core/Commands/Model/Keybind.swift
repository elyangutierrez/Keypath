//
//  Keybind.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/28/26.
//

import Foundation

nonisolated
struct Keybind: Codable {
    var key1: CommandType
    var key2: CommandType
    var key3: CommandType
}
