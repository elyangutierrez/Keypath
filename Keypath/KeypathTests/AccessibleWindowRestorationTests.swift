//
//  AccessibleWindowRestorationTests.swift
//  KeypathTests
//

import Testing
@testable import Keypath

@MainActor
struct AccessibleWindowRestorationTests {
    @Test func retriesAcceptedRestoreRequestAfterActivationWhenWindowRemainsMinimized() async {
        var minimized = true
        var requestCount = 0
        var pollCount = 0

        let restored = await ApplicationWindowAccessibility.restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: true,
            cachedMinimized: true,
            minimizedState: { minimized },
            requestRestore: {
                requestCount += 1
                return true
            },
            timeout: .seconds(1),
            sleep: { _ in
                pollCount += 1
                minimized = false
            }
        )

        #expect(restored)
        #expect(requestCount == 1)
        #expect(pollCount == 1)
        #expect(!minimized)
    }

    @Test func waitsForPreviouslyAcceptedRequestIfPostActivationRetryIsRejected() async {
        var minimized = true
        var pollCount = 0

        let restored = await ApplicationWindowAccessibility.restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: true,
            cachedMinimized: true,
            minimizedState: { minimized },
            requestRestore: { false },
            timeout: .seconds(1),
            sleep: { _ in
                pollCount += 1
                minimized = false
            }
        )

        #expect(restored)
        #expect(pollCount == 1)
    }

    @Test func retriesAfterRejectedPreActivationRestoreRequest() async {
        var minimized = true
        var requestCount = 0

        let restored = await ApplicationWindowAccessibility.restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: false,
            cachedMinimized: true,
            minimizedState: { minimized },
            requestRestore: {
                requestCount += 1
                minimized = false
                return true
            }
        )

        #expect(restored)
        #expect(requestCount == 1)
    }

    @Test func doesNotRequestRestorationWhenWindowIsAlreadyRestored() async {
        var requestCount = 0

        let restored = await ApplicationWindowAccessibility.restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: false,
            cachedMinimized: true,
            minimizedState: { false },
            requestRestore: {
                requestCount += 1
                return false
            }
        )

        #expect(restored)
        #expect(requestCount == 0)
    }

    @Test func failsWhenWindowRemainsMinimizedAfterRestoreRequest() async {
        var requestCount = 0

        let restored = await ApplicationWindowAccessibility.restoreIfMinimizedAndWait(
            previouslyAcceptedRestoreRequest: true,
            cachedMinimized: true,
            minimizedState: { true },
            requestRestore: {
                requestCount += 1
                return true
            },
            timeout: .milliseconds(0)
        )

        #expect(!restored)
        #expect(requestCount == 1)
    }

    @Test func retriesPostActivationDiscoveryUntilWindowAppears() async {
        var discoveryCount = 0
        var sleepCount = 0

        let result = await ApplicationWindowAccessibility.retryWindowDiscoveryAfterActivation(
            maximumAttempts: 4,
            discover: {
                discoveryCount += 1
                guard discoveryCount == 3 else { return .empty }
                return WindowDiscoveryResult(
                    windows: [AccessibleWindow(
                        number: 1,
                        title: "Window",
                        captureTitle: nil,
                        isMinimized: true,
                        isOnScreen: false,
                        frame: nil,
                        windowID: nil,
                        element: nil
                    )],
                    accessibilityWindowCount: 1,
                    coreGraphicsWindowCount: 0,
                    shareableWindowCount: 0
                )
            },
            sleep: { _ in sleepCount += 1 }
        )

        #expect(discoveryCount == 3)
        #expect(sleepCount == 2)
        #expect(result.windows.count == 1)
        #expect(result.hasWindowEvidence)
    }

    @Test func stopsPostActivationDiscoveryAtConfiguredAttemptLimit() async {
        var discoveryCount = 0
        var sleepCount = 0

        let result = await ApplicationWindowAccessibility.retryWindowDiscoveryAfterActivation(
            maximumAttempts: 3,
            discover: {
                discoveryCount += 1
                let hasTransientEvidence = discoveryCount == 1
                return WindowDiscoveryResult(
                    windows: [],
                    accessibilityWindowCount: hasTransientEvidence ? 1 : 0,
                    coreGraphicsWindowCount: 0,
                    shareableWindowCount: hasTransientEvidence ? nil : 0
                )
            },
            sleep: { _ in sleepCount += 1 }
        )

        #expect(discoveryCount == 3)
        #expect(sleepCount == 2)
        #expect(result.windows.isEmpty)
        #expect(result.hasWindowEvidence)
    }

    @Test func distinguishesWindowEvidenceFromAWindowlessApplication() {
        #expect(!WindowDiscoveryResult.empty.hasWindowEvidence)
        #expect(WindowDiscoveryResult(
            windows: [],
            accessibilityWindowCount: 1,
            coreGraphicsWindowCount: 0,
            shareableWindowCount: nil
        ).hasWindowEvidence)
    }

    @Test func permitsMinimizedWindowWhenAXRoleIsConfirmedAndSubroleIsUnavailable() {
        #expect(ApplicationWindowAccessibility.canRestoreMinimizedWindow(
            role: "AXWindow",
            subrole: nil
        ))
        #expect(ApplicationWindowAccessibility.canRestoreMinimizedWindow(
            role: "AXWindow",
            subrole: "AXStandardWindow"
        ))
        #expect(!ApplicationWindowAccessibility.canRestoreMinimizedWindow(
            role: "AXButton",
            subrole: nil
        ))
        #expect(!ApplicationWindowAccessibility.canRestoreMinimizedWindow(
            role: "AXWindow",
            subrole: "AXDialog"
        ))
    }
}
