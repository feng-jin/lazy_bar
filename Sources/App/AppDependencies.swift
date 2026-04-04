/// 集中管理依赖注入，方便后续在这里统一切换 mock 和真实数据源。
import Foundation
import os

struct AppDependencies {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "AppDependencies"
    )

    let menuBarSettingsStore: MenuBarSettingsStore
    let quoteSession: QuoteSession

    @MainActor
    static var live: AppDependencies {
        let menuBarSettingsStore = MenuBarSettingsStore()
        let quoteProvider = SinaQuoteProvider()
        Self.logger.debug(
            """
            build live dependencies \
            provider=SinaQuoteProvider \
            initialWatchlist=\(menuBarSettingsStore.settings.watchlist.count, privacy: .public)
            """
        )

        return AppDependencies(
            menuBarSettingsStore: menuBarSettingsStore,
            quoteSession: QuoteSession(provider: quoteProvider)
        )
    }
}
