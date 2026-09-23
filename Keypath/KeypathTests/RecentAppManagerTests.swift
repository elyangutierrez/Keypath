//
//  RecentAppManagerTests.swift
//  KeypathTests
//

import Testing
@testable import Keypath

struct RecentAppManagerTests {
    @Test func activationMovesAnAppToTheFrontAndRemovesDuplicates() {
        var history = RecentAppMRU(processIdentifiers: [10, 20, 30])

        history.recordActivation(20)

        #expect(history.processIdentifiers == [20, 10, 30])
    }

    @Test func terminationRemovesAnAppFromHistory() {
        var history = RecentAppMRU(processIdentifiers: [10, 20, 30])

        history.remove(20)

        #expect(history.processIdentifiers == [10, 30])
    }

    @Test func pickerStartsOnTheMostRecentEligibleAppBeforeFrontmost() {
        let history = RecentAppMRU(processIdentifiers: [10, 20, 30])

        #expect(history.initialSelectionIndex(among: [10, 20, 30], frontmostProcessIdentifier: 10) == 1)
    }

    @Test func pickerFallsBackToTheMostRecentCandidateWhenNoPreviousAppExists() {
        let history = RecentAppMRU(processIdentifiers: [10])

        #expect(history.initialSelectionIndex(among: [10], frontmostProcessIdentifier: 10) == 0)
        #expect(history.initialSelectionIndex(among: [], frontmostProcessIdentifier: 10) == nil)
    }

    @Test func selectionCyclesForwardAndBackwardWithWraparound() {
        let history = RecentAppMRU()

        #expect(history.cycledSelectionIndex(currentIndex: 0, by: 1, candidateCount: 3) == 1)
        #expect(history.cycledSelectionIndex(currentIndex: 2, by: 1, candidateCount: 3) == 0)
        #expect(history.cycledSelectionIndex(currentIndex: 0, by: -1, candidateCount: 3) == 2)
        #expect(history.cycledSelectionIndex(currentIndex: 2, by: -1, candidateCount: 3) == 1)
    }

    @Test func staleSelectionMovesToAValidRemainingCandidate() {
        let history = RecentAppMRU()

        #expect(history.selectionIndexPreserving(20, previousIndex: 1, among: [10, 20, 30]) == 1)
        #expect(history.selectionIndexPreserving(20, previousIndex: 1, among: [10, 30]) == 1)
        #expect(history.selectionIndexPreserving(30, previousIndex: 2, among: [10]) == 0)
        #expect(history.selectionIndexPreserving(20, previousIndex: 1, among: []) == nil)
    }

    @Test func cyclingRejectsAnEmptyListOrInvalidCurrentIndex() {
        let history = RecentAppMRU()

        #expect(history.cycledSelectionIndex(currentIndex: 0, by: 1, candidateCount: 0) == nil)
        #expect(history.cycledSelectionIndex(currentIndex: 3, by: 1, candidateCount: 3) == nil)
    }
}
