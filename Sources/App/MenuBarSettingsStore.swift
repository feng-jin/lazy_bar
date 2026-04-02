/// 持久化菜单栏展示设置，方便设置页和状态项控制器共享。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsStore: ObservableObject {
    @Published private(set) var settings: MenuBarDisplaySettings

    let baseWatchlist: [WatchlistEntry]

    private let userDefaults: UserDefaults
    private let storageKey = "menuBarDisplaySettings"

    init(
        userDefaults: UserDefaults = .standard,
        baseWatchlist: [WatchlistEntry] = MenuBarDisplaySettings.fallbackWatchlist
    ) {
        self.userDefaults = userDefaults
        self.baseWatchlist = baseWatchlist.isEmpty ? MenuBarDisplaySettings.fallbackWatchlist : baseWatchlist

        if
            let data = userDefaults.data(forKey: storageKey),
            let settings = try? JSONDecoder().decode(MenuBarDisplaySettings.self, from: data)
        {
            self.settings = settings
        } else {
            self.settings = MenuBarDisplaySettings(watchlist: self.baseWatchlist)
        }
    }

    func update(_ settings: MenuBarDisplaySettings) {
        self.settings = settings

        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func resetToBaseWatchlist() {
        update(
            MenuBarDisplaySettings(
                watchlist: baseWatchlist,
                showsSymbol: settings.showsSymbol,
                showsCompanyName: settings.showsCompanyName,
                showsPrice: settings.showsPrice,
                showsChangePercent: settings.showsChangePercent
            )
        )
    }
}
