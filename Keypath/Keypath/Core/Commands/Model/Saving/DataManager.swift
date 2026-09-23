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
            // Coordinator transactions save explicitly so a failed save can roll back before
            // any UI-facing paths are updated.
            context.autosaveEnabled = false
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }
    
    // Helper function to easily find an existing save by app name
    func fetchSavedKeybind(for appName: String) -> SavedKeybind? {
        let descriptor = FetchDescriptor<SavedKeybind>(predicate: #Predicate { $0.appName == appName })
        return try? context.fetch(descriptor).first
    }

    func fetchSavedKeybinds(named appName: String) -> [SavedKeybind] {
        let descriptor = FetchDescriptor<SavedKeybind>(predicate: #Predicate { $0.appName == appName })
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func fetchAllSavedKeybinds() -> [SavedKeybind] {
        (try? fetchAllSavedKeybindsThrowing()) ?? []
    }
    
    func fetchAllSavedKeybindsThrowing() throws -> [SavedKeybind] {
        try context.fetch(FetchDescriptor<SavedKeybind>())
    }

    func savedKeybindSnapshots() throws -> [SavedKeybindSnapshot] {
        try fetchAllSavedKeybindsThrowing().map { SavedKeybindSnapshot($0) }
    }

    /// Replaces the complete binding table with one explicit save. On failure the context is
    /// rolled back, leaving persisted and in-memory model state at the last successful save.
    func replaceAllSavedKeybinds(with snapshots: [SavedKeybindSnapshot]) throws {
        do {
            for keybind in try fetchAllSavedKeybindsThrowing() {
                context.delete(keybind)
            }

            for snapshot in snapshots {
                context.insert(SavedKeybind(snapshot: snapshot))
            }

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func removeAllSavedKeybinds() {
        do {
            try replaceAllSavedKeybinds(with: [])
        } catch {
            print("Failed to remove all saved keybinds: \(error)")
        }
    }
}
