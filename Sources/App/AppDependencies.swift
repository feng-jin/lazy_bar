/// 集中管理依赖注入，方便后续在这里统一切换 mock 和真实数据源。
import Foundation

struct AppDependencies {
    let quoteProvider: any QuoteProviding
    let menuBarSettingsStore: MenuBarSettingsStore

    @MainActor
    static var live: AppDependencies {
        let menuBarSettingsStore = MenuBarSettingsStore()

        return AppDependencies(
            quoteProvider: SinaQuoteProvider(),
            menuBarSettingsStore: menuBarSettingsStore
        )
    }
}
