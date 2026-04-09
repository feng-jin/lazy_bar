/// 应用入口，负责创建状态栏控制器并把依赖注入到对应的 ViewModel。
import SwiftUI

@main
struct LazyBarApp: App {
    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var menuBarSettingsViewModel: MenuBarSettingsViewModel
    private let appUpdater: AppUpdater
    private let settingsWindowController: SettingsWindowController
    private let statusBarController: StatusBarController

    init() {
        appUpdater = AppUpdater()
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(
            settingsStore: dependencies.menuBarSettingsStore,
            quoteSession: dependencies.quoteSession
        )
        let menuBarSettingsViewModel = MenuBarSettingsViewModel(
            store: dependencies.menuBarSettingsStore,
            stockSearchProvider: dependencies.stockSearchProvider
        )

        _menuBarViewModel = StateObject(
            wrappedValue: menuBarViewModel
        )
        _menuBarSettingsViewModel = StateObject(
            wrappedValue: menuBarSettingsViewModel
        )
        settingsWindowController = SettingsWindowController(viewModel: menuBarSettingsViewModel)
        statusBarController = StatusBarController(
            menuBarViewModel: menuBarViewModel,
            checkForUpdates: { [appUpdater] in
                appUpdater.checkForUpdates()
            },
            openSettingsWindow: { [settingsWindowController] in
                settingsWindowController.show()
            }
        )
        Task {
            await menuBarViewModel.loadIfNeeded()
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
