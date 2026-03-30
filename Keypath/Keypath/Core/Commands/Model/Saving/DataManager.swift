//
//  DataManager.swift
//  Keypath
//
//  Created by Elyan Gutierrez on 3/29/26.
//

import Foundation
import SwiftData

@MainActor
class DataManager {
    static let shared = DataManager()
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        do {
            // Initialize the SwiftData container for your SavedKeybind model
            container = try ModelContainer(for: SavedKeybind.self)
            context = ModelContext(container)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }
    
    // Helper function to easily find an existing save by app name
    func fetchSavedKeybind(for appName: String) -> SavedKeybind? {
        let descriptor = FetchDescriptor<SavedKeybind>(predicate: #Predicate { $0.appName == appName })
        return try? context.fetch(descriptor).first
    }
    
    func fetchAllSavedKeybinds() -> [SavedKeybind] {
        let descriptor = FetchDescriptor<SavedKeybind>()
        
        let results = try? context.fetch(descriptor)
        
        return results ?? []
    }
}
