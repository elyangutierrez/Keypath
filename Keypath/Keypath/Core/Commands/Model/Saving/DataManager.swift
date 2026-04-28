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
    
    init(isStoredInMemoryOnly: Bool = false) {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
            container = try ModelContainer(for: SavedKeybind.self, configurations: config)
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
    
    func removeAllSavedKeybinds() {
        do {
            try context.delete(model: SavedKeybind.self)
            try context.save()
        } catch {
            print("Failed to remove all saved keybinds: \(error)")
        }
    }
}
