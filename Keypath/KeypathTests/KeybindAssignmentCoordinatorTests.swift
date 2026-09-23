//
//  KeybindAssignmentCoordinatorTests.swift
//  KeypathTests
//

import Testing
@testable import Keypath

@MainActor
struct KeybindAssignmentCoordinatorTests {
    @Test func conflictCancellationPreservesEverySavedBinding() throws {
        let manager = try dataManager([
            record("Mail", "com.example.mail", "M"),
            record("Notes", "com.example.notes", "N")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.requestAssignment(appName: "Browser", bundleID: "com.example.browser", key: "M")

        #expect(coordinator.pendingConflict?.targetAppName == "Browser")
        #expect(coordinator.pendingConflict?.conflictingOwners.map(\.appName) == ["Mail"])
        #expect(try manager.savedKeybindSnapshots().count == 2)

        coordinator.cancelPendingAssignment()

        #expect(coordinator.pendingConflict == nil)
        #expect(try manager.savedKeybindSnapshots().map(\.appName).sorted() == ["Mail", "Notes"])
        #expect(coordinator.undoAvailable == false)
    }

    @Test func confirmationMovesKeyAndUndoRestoresPreviousOwner() throws {
        let manager = try dataManager([
            record("Mail", "com.example.mail", "M"),
            record("Notes", "com.example.notes", "N")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.requestAssignment(appName: "Browser", bundleID: "com.example.browser", key: "M")
        coordinator.confirmPendingAssignment()

        let moved = try manager.savedKeybindSnapshots()
        #expect(moved.count == 2)
        #expect(moved.first(where: { $0.appName == "Mail" }) == nil)
        #expect(moved.first(where: { $0.bundleID == "com.example.browser" })?.keybind.key2 == .letter("M"))
        #expect(coordinator.undoAvailable)

        coordinator.undoLastChange()

        let restored = try manager.savedKeybindSnapshots()
        #expect(restored.count == 2)
        #expect(restored.first(where: { $0.bundleID == "com.example.mail" })?.keybind.key2 == .letter("M"))
        #expect(restored.first(where: { $0.bundleID == "com.example.browser" }) == nil)
        #expect(coordinator.undoAvailable == false)
    }

    @Test func detectsConflictsAcrossAllSavedRows() throws {
        let manager = try dataManager([
            record("Mail", "com.example.mail", "M"),
            record("Music", "com.example.music", "M")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.requestAssignment(appName: "Browser", bundleID: "com.example.browser", key: "M")

        #expect(coordinator.pendingConflict?.conflictingOwners.count == 2)
        #expect(try manager.savedKeybindSnapshots().count == 2)
    }

    @Test func bundleIDKeepsSameNamedAppsSeparate() throws {
        let manager = try dataManager([
            record("Editor", "com.first.editor", "A"),
            record("Editor", "com.second.editor", "B")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.requestAssignment(appName: "Editor", bundleID: "com.second.editor", key: "C")

        let saved = try manager.savedKeybindSnapshots()
        #expect(saved.count == 2)
        #expect(saved.first(where: { $0.bundleID == "com.first.editor" })?.keybind.key2 == .letter("A"))
        #expect(saved.first(where: { $0.bundleID == "com.second.editor" })?.keybind.key2 == .letter("C"))
        #expect(coordinator.pendingConflict == nil)
    }

    @Test func appWithoutBundleIDDoesNotTakeOverCanonicalSameNameRecord() throws {
        let manager = try dataManager([
            record("Editor", "com.example.editor", "A")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.requestAssignment(appName: "Editor", bundleID: nil, key: "B")

        let saved = try manager.savedKeybindSnapshots()
        #expect(saved.count == 2)
        #expect(saved.first(where: { $0.bundleID == "com.example.editor" })?.keybind.key2 == .letter("A"))
        #expect(saved.first(where: { $0.bundleID == nil })?.keybind.key2 == .letter("B"))
    }

    @Test func savedDestinationRequiresAnExactUniqueKeyMatch() throws {
        let manager = try dataManager([
            record("Mail", "com.example.mail", "M"),
            record("Maps", "com.example.maps", "A")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        #expect(coordinator.savedDestination(matchingKey: "A")?.bundleID == "com.example.maps")
        #expect(coordinator.savedDestination(matchingKey: "MA") == nil)

        try manager.replaceAllSavedKeybinds(with: [
            record("Mail", "com.example.mail", "M"),
            record("Maps", "com.example.maps", "M")
        ])
        #expect(coordinator.savedDestination(matchingKey: "M") == nil)
    }

    @Test func resetIsUndoable() throws {
        let manager = try dataManager([
            record("Mail", "com.example.mail", "M")
        ])
        let coordinator = KeybindAssignmentCoordinator(dataManager: manager)

        coordinator.resetAllKeybinds()

        #expect(try manager.savedKeybindSnapshots().isEmpty)
        #expect(coordinator.undoAvailable)
        #expect(coordinator.undoDescription == "Undo Reset")

        coordinator.undoLastChange()

        #expect(try manager.savedKeybindSnapshots().map(\.appName) == ["Mail"])
    }

    private func dataManager(_ records: [SavedKeybindSnapshot]) throws -> DataManager {
        KeypathCommandManager.shared.currentPaths = []
        KeypathCommandManager.shared.currentIndex = 0
        let manager = DataManager(isStoredInMemoryOnly: true)
        try manager.replaceAllSavedKeybinds(with: records)
        return manager
    }

    private func record(_ appName: String, _ bundleID: String?, _ key: String) -> SavedKeybindSnapshot {
        SavedKeybindSnapshot(
            appName: appName,
            bundleID: bundleID,
            keybind: Keybind(key1: .symbol(".superKeyLight"), key2: .letter(key))
        )
    }
}
