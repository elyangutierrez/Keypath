//
//  RecentAppManager.swift
//  Keypath
//

import AppKit
import Foundation
import Observation

/// Session-only application activation history, ordered most-recent first.
/// Kept separate from NSWorkspace so ordering and wraparound behavior can be tested.
nonisolated struct RecentAppMRU: Equatable {
    private(set) var processIdentifiers: [pid_t]

    init(processIdentifiers: [pid_t] = []) {
        var seen = Set<pid_t>()
        self.processIdentifiers = processIdentifiers.filter { seen.insert($0).inserted }
    }

    mutating func recordActivation(_ processIdentifier: pid_t) {
        processIdentifiers.removeAll { $0 == processIdentifier }
        processIdentifiers.insert(processIdentifier, at: 0)
    }

    mutating func remove(_ processIdentifier: pid_t) {
        processIdentifiers.removeAll { $0 == processIdentifier }
    }

    func initialSelectionIndex(
        among candidateProcessIdentifiers: [pid_t],
        frontmostProcessIdentifier: pid_t?
    ) -> Int? {
        guard !candidateProcessIdentifiers.isEmpty else { return nil }

        if let frontmostProcessIdentifier,
           let previousAppIndex = candidateProcessIdentifiers.firstIndex(where: { $0 != frontmostProcessIdentifier }) {
            return previousAppIndex
        }

        return candidateProcessIdentifiers.indices.first
    }

    func selectionIndexPreserving(
        _ selectedProcessIdentifier: pid_t?,
        previousIndex: Int,
        among candidateProcessIdentifiers: [pid_t]
    ) -> Int? {
        guard !candidateProcessIdentifiers.isEmpty else { return nil }

        if let selectedProcessIdentifier,
           let preservedIndex = candidateProcessIdentifiers.firstIndex(of: selectedProcessIdentifier) {
            return preservedIndex
        }

        return min(max(previousIndex, 0), candidateProcessIdentifiers.count - 1)
    }

    func cycledSelectionIndex(currentIndex: Int, by offset: Int, candidateCount: Int) -> Int? {
        guard candidateCount > 0, (0..<candidateCount).contains(currentIndex) else { return nil }

        let movement = offset % candidateCount
        return (currentIndex + movement + candidateCount) % candidateCount
    }
}

@Observable
@MainActor
final class RecentAppManager {
    static let shared = RecentAppManager()

    private(set) var isVisible = false
    private(set) var candidates: [NSRunningApplication] = []
    private(set) var selectionIndex: Int?

    var selectedApplication: NSRunningApplication? {
        guard let selectionIndex, candidates.indices.contains(selectionIndex) else { return nil }
        return candidates[selectionIndex]
    }

    @ObservationIgnored private var history: RecentAppMRU
    @ObservationIgnored private let workspace: NSWorkspace
    @ObservationIgnored private let excludedAppNamesProvider: () -> [String]
    @ObservationIgnored private var frontmostProcessIdentifier: pid_t?
    @ObservationIgnored private var observerTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var hasStartedObserving = false

    init(
        initialHistory: RecentAppMRU = RecentAppMRU(),
        observesWorkspace: Bool = false,
        workspace: NSWorkspace = .shared,
        excludedAppNamesProvider: @escaping () -> [String] = { Config.shared.getExcludedApps() }
    ) {
        history = initialHistory
        self.workspace = workspace
        self.excludedAppNamesProvider = excludedAppNamesProvider

        if observesWorkspace {
            startObserving()
        }
    }

    /// Starts session history tracking. Safe to call more than once.
    func startObserving() {
        guard !hasStartedObserving else { return }
        hasStartedObserving = true

        let workspaceCenter = workspace.notificationCenter
        observe(
            NSWorkspace.didActivateApplicationNotification,
            on: workspaceCenter,
            payload: { notification in
                (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            }
        ) { [weak self] processIdentifier in
            guard let processIdentifier else { return }
            self?.recordActivation(processIdentifier: processIdentifier)
        }
        observe(
            NSWorkspace.didTerminateApplicationNotification,
            on: workspaceCenter,
            payload: { notification in
                (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            }
        ) { [weak self] processIdentifier in
            guard let processIdentifier else { return }
            self?.recordTermination(processIdentifier: processIdentifier)
        }
        observe(
            NSWorkspace.didLaunchApplicationNotification,
            on: workspaceCenter,
            payload: { _ in () }
        ) { [weak self] _ in
            self?.refreshCandidates(preservingSelection: self?.isVisible == true)
        }
        observe(.excludedAppsDidChange, on: .default, payload: { _ in () }) { [weak self] _ in
            self?.refreshCandidates(preservingSelection: self?.isVisible == true)
        }

        if let frontmostApplication = workspace.frontmostApplication {
            frontmostProcessIdentifier = frontmostApplication.processIdentifier
            if isEligible(frontmostApplication) {
                history.recordActivation(frontmostApplication.processIdentifier)
            }
        }
        refreshCandidates(preservingSelection: false)
    }

    /// Opens the picker, selecting the most recent eligible app before the current frontmost app.
    /// Returns true when the picker is open, including when its empty state is shown.
    @discardableResult
    func beginPicker() -> Bool {
        startObserving()

        if let frontmostApplication = workspace.frontmostApplication {
            frontmostProcessIdentifier = frontmostApplication.processIdentifier
            if isEligible(frontmostApplication) {
                history.recordActivation(frontmostApplication.processIdentifier)
            }
        }

        refreshCandidates(preservingSelection: false)
        let candidateProcessIdentifiers = candidates.map(\.processIdentifier)
        selectionIndex = history.initialSelectionIndex(
            among: candidateProcessIdentifiers,
            frontmostProcessIdentifier: frontmostProcessIdentifier
        )
        isVisible = true
        return true
    }

    /// Moves by `offset` entries, wrapping at either end. Returns false when there is no selection to move.
    @discardableResult
    func moveSelection(by offset: Int) -> Bool {
        guard isVisible,
              let selectionIndex,
              !candidates.isEmpty else { return false }

        guard let nextIndex = history.cycledSelectionIndex(
            currentIndex: selectionIndex,
            by: offset,
            candidateCount: candidates.count
        ) else { return false }
        self.selectionIndex = nextIndex
        return true
    }

    /// Activates the selected app if it is still running and eligible. A valid activation attempt
    /// closes the picker and returns true so the triggering Enter key is consumed.
    @discardableResult
    func activateSelection() -> Bool {
        guard isVisible,
              let application = selectedApplication,
              isEligible(application),
              workspace.runningApplications.contains(where: {
                  $0.processIdentifier == application.processIdentifier && !$0.isTerminated
              }) else {
            refreshCandidates(preservingSelection: true)
            return false
        }

        guard application.activate() else { return false }
        isVisible = false
        return true
    }

    /// Closes the picker without activating the selected app.
    @discardableResult
    func cancelPicker() -> Bool {
        guard isVisible else { return false }
        isVisible = false
        return true
    }

    private func observe<Payload: Sendable>(
        _ name: Notification.Name,
        on center: NotificationCenter,
        payload: @escaping @Sendable (Notification) -> Payload,
        handler: @escaping @MainActor (Payload) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
            let payload = payload(notification)
            MainActor.assumeIsolated {
                handler(payload)
            }
        }
        observerTokens.append(token)
    }

    private func recordActivation(processIdentifier: pid_t) {
        frontmostProcessIdentifier = processIdentifier
        if let application = workspace.runningApplications.first(where: { $0.processIdentifier == processIdentifier }),
           isEligible(application) {
            history.recordActivation(processIdentifier)
        }
        refreshCandidates(preservingSelection: isVisible)
    }

    private func recordTermination(processIdentifier: pid_t) {
        history.remove(processIdentifier)
        if frontmostProcessIdentifier == processIdentifier {
            frontmostProcessIdentifier = workspace.frontmostApplication?.processIdentifier
        }
        refreshCandidates(preservingSelection: isVisible)
    }

    private func refreshCandidates(preservingSelection: Bool) {
        let previousSelectedProcessIdentifier = preservingSelection ? selectedApplication?.processIdentifier : nil
        let previousIndex = selectionIndex ?? 0
        let exclusions = Set(excludedAppNamesProvider())
        let runningApplications = Dictionary(
            workspace.runningApplications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        candidates = history.processIdentifiers.compactMap { processIdentifier in
            guard let application = runningApplications[processIdentifier],
                  isEligible(application, excludedAppNames: exclusions) else { return nil }
            return application
        }

        guard !candidates.isEmpty else {
            selectionIndex = nil
            return
        }

        selectionIndex = history.selectionIndexPreserving(
            previousSelectedProcessIdentifier,
            previousIndex: previousIndex,
            among: candidates.map(\.processIdentifier)
        )
    }

    private func isEligible(_ application: NSRunningApplication) -> Bool {
        isEligible(application, excludedAppNames: Set(excludedAppNamesProvider()))
    }

    private func isEligible(_ application: NSRunningApplication, excludedAppNames: Set<String>) -> Bool {
        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !application.isTerminated,
              application.activationPolicy == .regular else { return false }

        if let keypathBundleIdentifier = Bundle.main.bundleIdentifier,
           application.bundleIdentifier == keypathBundleIdentifier {
            return false
        }

        let appName = application.localizedName ?? "Unknown App"
        return !excludedAppNames.contains(appName)
    }
}
