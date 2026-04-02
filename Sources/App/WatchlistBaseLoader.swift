/// 从 bundle 中读取基础监控列表，作为首次启动和重置时的 base 数据。
import Foundation

struct WatchlistBaseLoader {
    private static let resourceName = "watchlist-base"

    func load() -> [WatchlistEntry] {
        guard
            let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([WatchlistEntry].self, from: data)
        else {
            return MenuBarDisplaySettings.fallbackWatchlist
        }

        let normalizedEntries = entries.compactMap(Self.normalizedEntry(from:))
        return normalizedEntries.isEmpty ? MenuBarDisplaySettings.fallbackWatchlist : normalizedEntries
    }

    private static func normalizedEntry(from entry: WatchlistEntry) -> WatchlistEntry? {
        let symbol = entry.symbol.filter(\.isNumber)
        guard symbol.count == 6 else { return nil }

        let trimmedName = entry.companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return WatchlistEntry(
            symbol: symbol,
            companyName: trimmedName.isEmpty ? symbol : trimmedName
        )
    }
}
