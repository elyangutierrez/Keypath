import Foundation
import Testing
@testable import Keypath

@MainActor
struct GridLayoutManagerTests {
    @Test func gridChoiceDefaultsToTwoAndPersistsWithOtherPreferences() {
        let suite = "GridLayoutManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let config = Config(defaults: defaults)
        #expect(config.getGridColumnCount() == 2)

        defaults.set(["EXCLUDED_APPS": ["Finder"], "IS_AUTO_LAUNCH_ENABLED": true], forKey: config.key)
        let manager = GridLayoutManager(config: config)
        manager.setColumnCount(4)

        #expect(GridLayoutManager(config: config).columnCount == 4)
        #expect(config.getExcludedApps() == ["Finder"])
        #expect(config.getAutoLaunch())
    }

    @Test func invalidSavedCountsFallBackToTwo() {
        let suite = "GridLayoutManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let config = Config(defaults: defaults)
        for invalidCount in [0, 1, 5] {
            defaults.set(["GRID_COLUMN_COUNT": invalidCount], forKey: config.key)
            #expect(config.getGridColumnCount() == 2)
        }

        let manager = GridLayoutManager(config: config)
        manager.setColumnCount(5)
        #expect(manager.columnCount == 2)
    }
}
