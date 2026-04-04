/// 集中管理依赖注入，方便后续在这里统一切换 mock 和真实数据源。
import Foundation

struct AppDependencies {
    let menuBarSettingsStore: MenuBarSettingsStore
    let quoteSession: QuoteSession

    @MainActor
    static var live: AppDependencies {
        let menuBarSettingsStore = MenuBarSettingsStore()
        let quoteProvider = SinaQuoteProvider()

        return AppDependencies(
            menuBarSettingsStore: menuBarSettingsStore,
            quoteSession: QuoteSession(provider: quoteProvider)
        )
    }
}
