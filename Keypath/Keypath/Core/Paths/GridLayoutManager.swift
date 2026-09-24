import Foundation

@MainActor
@Observable
final class GridLayoutManager {
    static let shared = GridLayoutManager()

    private let config: Config
    private(set) var columnCount: Int

    init(config: Config = .shared) {
        self.config = config
        columnCount = config.getGridColumnCount()
    }

    func setColumnCount(_ count: Int) {
        guard (2...4).contains(count), columnCount != count else { return }
        config.setGridColumnCount(count)
        columnCount = count
    }
}
