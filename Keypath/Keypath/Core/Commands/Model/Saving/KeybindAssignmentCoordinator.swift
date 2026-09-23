//
//  KeybindAssignmentCoordinator.swift
//  Keypath
//

import AppKit
import Foundation
import Observation

struct KeybindConflictOwner: Identifiable, Equatable {
    let recordID: UUID
    let appName: String
    let bundleID: String?

    var id: UUID { recordID }

    var displayName: String {
        if let bundleID {
            return "\(appName) (\(bundleID))"
        }
        return appName
    }
}

struct PendingKeybindConflict: Identifiable, Equatable {
    let id: UUID
    let targetAppName: String
    let targetBundleID: String?
    let key: String
    let conflictingOwners: [KeybindConflictOwner]

    var ownerNames: [String] {
        conflictingOwners.map(\.displayName)
    }
}

struct SavedKeybindDestination: Equatable, Sendable {
    let appName: String
    let bundleID: String?
}

/// Serializes keybind changes so the saved table and the visible HUD paths change together.
@MainActor
@Observable
final class KeybindAssignmentCoordinator {
    static let shared = KeybindAssignmentCoordinator(dataManager: .shared)

    private(set) var pendingConflict: PendingKeybindConflict?
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?
    private(set) var isUndoFocused = false

    var undoAvailable: Bool {
        guard let undoState else { return false }
        return Date() < undoState.expiresAt
    }

    var undoDescription: String? {
        guard undoAvailable else { return nil }
        return undoState?.description
    }

    @ObservationIgnored private let dataManager: DataManager
    private var pendingAssignment: PendingAssignment?
    private var undoState: UndoState?
    @ObservationIgnored private var undoExpirationTask: Task<Void, Never>?

    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    /// Assigns the pressed key to the selected app, or exposes a conflict for confirmation.
    func requestAssignment(appName: String, bundleID: String?, key: String) {
        errorMessage = nil
        statusMessage = nil
        isUndoFocused = false
        pendingAssignment = nil
        pendingConflict = nil

        let normalizedKey = key.uppercased()
        guard Self.validKeys.contains(normalizedKey) else {
            errorMessage = "Keypath could not save that key. Choose a letter or number key."
            return
        }

        let paths = KeypathCommandManager.shared.currentPaths
        let selectedPath = selectedPath(named: appName, bundleID: bundleID, from: paths)
        guard selectedPath != nil || paths.isEmpty else {
            errorMessage = "Keypath could not find the selected app. Try assigning its key again."
            return
        }

        let target = PendingAssignment(
            appName: selectedPath?.appName ?? appName,
            bundleID: selectedPath?.application.bundleIdentifier ?? bundleID,
            key: normalizedKey
        )
        pendingAssignment = target

        let records: [SavedKeybindSnapshot]
        do {
            records = try dataManager.savedKeybindSnapshots()
        } catch {
            pendingAssignment = nil
            errorMessage = "Could not read saved keybinds: \(error.localizedDescription)"
            return
        }
        let conflicts = conflictingRecords(for: target, in: records, paths: paths)
        guard !conflicts.isEmpty else {
            commitAssignment(target, clearing: [], records: records, paths: paths)
            return
        }

        pendingConflict = makeConflict(for: target, owners: conflicts)
    }

    func confirmPendingAssignment() {
        guard let target = pendingAssignment else { return }
        let paths = KeypathCommandManager.shared.currentPaths
        let records: [SavedKeybindSnapshot]
        do {
            records = try dataManager.savedKeybindSnapshots()
        } catch {
            errorMessage = "Could not read saved keybinds: \(error.localizedDescription)"
            return
        }
        let conflicts = conflictingRecords(for: target, in: records, paths: paths)
        commitAssignment(target, clearing: conflicts, records: records, paths: paths)
    }

    func cancelPendingAssignment() {
        pendingAssignment = nil
        pendingConflict = nil
        errorMessage = nil
    }

    /// Restores the exact prior saved-key row when a key has one unique match.
    func savedDestination(matchingKey key: String) -> SavedKeybindDestination? {
        let normalizedKey = key.uppercased()
        let records: [SavedKeybindSnapshot]
        do {
            records = try dataManager.savedKeybindSnapshots()
        } catch {
            errorMessage = "Could not read saved keybinds: \(error.localizedDescription)"
            return nil
        }
        let matches = records.filter { snapshot in
            guard case let .letter(letter) = snapshot.keybind.key2 else { return false }
            return letter.uppercased() == normalizedKey
        }

        guard matches.count == 1, let match = matches.first else { return nil }
        return SavedKeybindDestination(appName: match.appName, bundleID: match.bundleID)
    }

    /// Resolves all running paths from a single read and commits any unambiguous legacy
    /// backfills together. Keys are indexed by process ID for direct application to paths.
    func savedKeybinds(for paths: [Keypath]) -> [pid_t: Keybind] {
        let records: [SavedKeybindSnapshot]
        do {
            records = try dataManager.savedKeybindSnapshots()
        } catch {
            errorMessage = "Could not read saved keybinds: \(error.localizedDescription)"
            return existingPathBindings(in: paths)
        }

        var updatedRecords = records
        var assignments: [pid_t: Keybind] = [:]
        var didBackfill = false

        for path in paths {
            let bundleID = path.application.bundleIdentifier
            if let bundleID {
                let canonicalRows = records.filter { $0.bundleID == bundleID }
                if canonicalRows.count == 1, let canonical = canonicalRows.first {
                    assignments[path.id] = canonical.keybind
                    continue
                }
                guard canonicalRows.isEmpty else { continue }
            }

            let legacyRows = records.filter { $0.bundleID == nil && $0.appName == path.appName }
            guard legacyRows.count == 1,
                  let legacy = legacyRows.first,
                  isUniqueRunningIdentity(named: path.appName, bundleID: bundleID, in: paths) else {
                continue
            }

            assignments[path.id] = legacy.keybind
            guard let bundleID,
                  let index = updatedRecords.firstIndex(where: { $0.id == legacy.id }) else {
                continue
            }
            updatedRecords[index].bundleID = bundleID
            didBackfill = true
        }

        guard didBackfill else { return assignments }
        do {
            try dataManager.replaceAllSavedKeybinds(with: updatedRecords)
            return assignments
        } catch {
            errorMessage = "Could not update saved app identities: \(error.localizedDescription)"
            return existingPathBindings(in: paths)
        }
    }

    /// Called only after the user confirms Reset in Settings.
    func resetAllKeybinds() {
        errorMessage = nil
        statusMessage = nil
        pendingAssignment = nil
        pendingConflict = nil

        let paths = KeypathCommandManager.shared.currentPaths
        let records: [SavedKeybindSnapshot]
        do {
            records = try dataManager.savedKeybindSnapshots()
        } catch {
            errorMessage = "Could not read saved keybinds: \(error.localizedDescription)"
            return
        }
        guard !records.isEmpty else {
            statusMessage = "There are no saved keybinds to reset."
            return
        }

        let previousPaths = paths.map(PathBindingState.init)
        do {
            try dataManager.replaceAllSavedKeybinds(with: [])
            paths.forEach { $0.keybind = nil }
            setUndoState(
                UndoState(
                    records: records,
                    pathBindings: previousPaths,
                    description: "Undo Reset",
                    expiresAt: Date().addingTimeInterval(30)
                )
            )
            statusMessage = "Keybinds reset. Undo is available in the HUD for 30 seconds."
        } catch {
            errorMessage = "Could not reset keybinds: \(error.localizedDescription)"
        }
    }

    func undoLastChange() {
        guard let undoState, Date() < undoState.expiresAt else {
            clearUndoState()
            return
        }

        errorMessage = nil
        isUndoFocused = false

        do {
            try dataManager.replaceAllSavedKeybinds(with: undoState.records)
            restoreVisiblePathBindings(from: undoState, currentPaths: KeypathCommandManager.shared.currentPaths)
            clearUndoState()
            statusMessage = "The last keybind change was undone."
        } catch {
            errorMessage = "Could not undo the keybind change: \(error.localizedDescription)"
        }
    }

    func setUndoFocused(_ focused: Bool) {
        isUndoFocused = focused && undoAvailable
    }

    func clearError() {
        errorMessage = nil
    }

    func clearStatus() {
        statusMessage = nil
    }

    private func commitAssignment(
        _ target: PendingAssignment,
        clearing conflicts: [SavedKeybindSnapshot],
        records: [SavedKeybindSnapshot],
        paths: [Keypath]
    ) {
        let targetRecords = records.filter { isTarget($0, for: target, paths: paths) }
        let conflictIDs = Set(conflicts.map(\.id))
        let targetIDs = Set(targetRecords.map(\.id))
        var updated = records.filter { !conflictIDs.contains($0.id) && !targetIDs.contains($0.id) }

        let newKeybind = Keybind(key1: .symbol(".superKeyLight"), key2: .letter(target.key))
        let targetRecord = SavedKeybindSnapshot(
            id: targetRecords.first?.id ?? UUID(),
            appName: target.appName,
            bundleID: target.bundleID,
            keybind: newKeybind
        )
        updated.append(targetRecord)

        let previousPaths = paths.map(PathBindingState.init)
        do {
            try dataManager.replaceAllSavedKeybinds(with: updated)

            for path in paths {
                if conflicts.contains(where: { isSameApp(path, as: $0, paths: paths) }) {
                    path.keybind = nil
                }
                if isSameApp(path, as: target) {
                    path.keybind = newKeybind
                }
            }

            let ownerNames = Array(Set(conflicts.map(\.appName))).sorted()
            setUndoState(
                UndoState(
                    records: records,
                    pathBindings: previousPaths,
                    description: "Undo keybind for \(target.appName)",
                    expiresAt: Date().addingTimeInterval(30)
                )
            )
            statusMessage = ownerNames.isEmpty
                ? "Keybind saved for \(target.appName). Undo is available in the HUD for 30 seconds."
                : "Keybind moved to \(target.appName). Undo is available in the HUD for 30 seconds."
            pendingAssignment = nil
            pendingConflict = nil
            KeypathCommandManager.shared.hasUpdatedKeybinds.toggle()
        } catch {
            errorMessage = "Could not save the keybind: \(error.localizedDescription)"
        }
    }

    private func conflictingRecords(
        for target: PendingAssignment,
        in records: [SavedKeybindSnapshot],
        paths: [Keypath]
    ) -> [SavedKeybindSnapshot] {
        records.filter { record in
            guard case let .letter(letter) = record.keybind.key2,
                  letter.uppercased() == target.key else { return false }
            return !isTarget(record, for: target, paths: paths)
        }
    }

    private func makeConflict(for target: PendingAssignment, owners: [SavedKeybindSnapshot]) -> PendingKeybindConflict {
        PendingKeybindConflict(
            id: UUID(),
            targetAppName: target.appName,
            targetBundleID: target.bundleID,
            key: target.key,
            conflictingOwners: owners.map {
                KeybindConflictOwner(recordID: $0.id, appName: $0.appName, bundleID: $0.bundleID)
            }
        )
    }

    private func selectedPath(named appName: String, bundleID: String?, from paths: [Keypath]) -> Keypath? {
        if let bundleID {
            return paths.first { $0.application.bundleIdentifier == bundleID }
        }

        let manager = KeypathCommandManager.shared
        if paths.indices.contains(manager.currentIndex) {
            let selected = paths[manager.currentIndex]
            if selected.appName == appName {
                return selected
            }
        }

        let matches = paths.filter { $0.appName == appName }
        guard Set(matches.map { $0.application.bundleIdentifier ?? "process:\($0.id)" }).count == 1 else { return nil }
        return matches.first
    }

    private func isTarget(_ record: SavedKeybindSnapshot, for target: PendingAssignment, paths: [Keypath]) -> Bool {
        if let bundleID = target.bundleID, let savedBundleID = record.bundleID {
            return bundleID == savedBundleID
        }
        guard record.bundleID == nil else { return false }
        guard record.appName == target.appName else { return false }
        return isUniqueRunningIdentity(named: target.appName, bundleID: target.bundleID, in: paths)
    }

    private func isSameApp(_ path: Keypath, as target: PendingAssignment) -> Bool {
        if let bundleID = target.bundleID {
            return path.application.bundleIdentifier == bundleID
        }
        return path.appName == target.appName
    }

    private func isSameApp(_ path: Keypath, as record: SavedKeybindSnapshot, paths: [Keypath]) -> Bool {
        if let bundleID = record.bundleID {
            return path.application.bundleIdentifier == bundleID
        }
        return path.appName == record.appName && isUniqueRunningIdentity(named: record.appName, bundleID: path.application.bundleIdentifier, in: paths)
    }

    private func isUniqueRunningIdentity(named appName: String, bundleID: String?, in paths: [Keypath]) -> Bool {
        let matchingPaths = paths.filter { $0.appName == appName }
        let identities = Set(matchingPaths.map { path in
            path.application.bundleIdentifier ?? "process:\(path.id)"
        })
        guard identities.count == 1 else { return false }
        guard let bundleID else { return true }
        return identities.contains(bundleID)
    }

    private func restoreVisiblePathBindings(from state: UndoState, currentPaths: [Keypath]) {
        for oldState in state.pathBindings {
            oldState.path.keybind = oldState.keybind
        }

        for path in currentPaths {
            if let matchingState = state.pathBindings.first(where: { $0.matches(path, among: currentPaths) }) {
                path.keybind = matchingState.keybind
                continue
            }
            path.keybind = savedBinding(for: path, in: state.records, among: currentPaths)
        }
    }

    private func savedBinding(for path: Keypath, in records: [SavedKeybindSnapshot], among paths: [Keypath]) -> Keybind? {
        if let bundleID = path.application.bundleIdentifier,
           let exact = records.first(where: { $0.bundleID == bundleID }) {
            return exact.keybind
        }

        let legacy = records.filter { $0.bundleID == nil && $0.appName == path.appName }
        guard legacy.count == 1,
              isUniqueRunningIdentity(named: path.appName, bundleID: path.application.bundleIdentifier, in: paths) else {
            return nil
        }
        return legacy.first?.keybind
    }

    private func existingPathBindings(in paths: [Keypath]) -> [pid_t: Keybind] {
        Dictionary(uniqueKeysWithValues: paths.compactMap { path in
            path.keybind.map { (path.id, $0) }
        })
    }

    private func setUndoState(_ state: UndoState) {
        undoExpirationTask?.cancel()
        undoState = state
        isUndoFocused = false

        let token = state.token
        undoExpirationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, let self, self.undoState?.token == token else { return }
            self.undoState = nil
            self.isUndoFocused = false
            self.statusMessage = nil
        }
    }

    private func clearUndoState() {
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
        undoState = nil
        isUndoFocused = false
    }

    private static let validKeys = Set("1234567890QWERTYUIOPASDFGHJKLZXCVBNM".map(String.init))

    private struct PendingAssignment {
        let appName: String
        let bundleID: String?
        let key: String
    }

    private struct PathBindingState {
        let path: Keypath
        let appName: String
        let bundleID: String?
        let keybind: Keybind?

        init(_ path: Keypath) {
            self.path = path
            appName = path.appName
            bundleID = path.application.bundleIdentifier
            keybind = path.keybind
        }

        func matches(_ path: Keypath, among paths: [Keypath]) -> Bool {
            if let bundleID { return bundleID == path.application.bundleIdentifier }
            return appName == path.appName && paths.filter { $0.appName == appName }.count == 1
        }
    }

    private struct UndoState {
        let token = UUID()
        let records: [SavedKeybindSnapshot]
        let pathBindings: [PathBindingState]
        let description: String
        let expiresAt: Date
    }
}
