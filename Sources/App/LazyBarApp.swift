/// 应用入口，负责创建状态栏控制器并把依赖注入到对应的 ViewModel。
import SwiftUI

@main
struct LazyBarApp: App {
    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var menuBarSettingsViewModel: MenuBarSettingsViewModel
    private let settingsWindowController: SettingsWindowController
    private let statusBarController: StatusBarController

    init() {
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(
            provider: dependencies.quoteProvider,
            settingsStore: dependencies.menuBarSettingsStore
        )
        let menuBarSettingsViewModel = MenuBarSettingsViewModel(
            store: dependencies.menuBarSettingsStore
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
            settingsStore: dependencies.menuBarSettingsStore,
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
