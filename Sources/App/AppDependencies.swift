/// 集中管理依赖注入，方便后续在这里统一切换 mock 和真实数据源。
import Foundation

struct AppDependencies {
    let quoteProvider: any QuoteProviding
    let menuBarSettingsStore: MenuBarSettingsStore

    @MainActor
    static var live: AppDependencies {
        let baseWatchlist = WatchlistBaseLoader().load()
        let menuBarSettingsStore = MenuBarSettingsStore(baseWatchlist: baseWatchlist)

        return AppDependencies(
            quoteProvider: SinaQuoteProvider(),
            menuBarSettingsStore: menuBarSettingsStore
        )
    }
}
