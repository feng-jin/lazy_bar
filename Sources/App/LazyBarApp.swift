/// 应用入口，负责创建菜单栏场景并把依赖注入到对应的 ViewModel。
import SwiftUI

@main
struct LazyBarApp: App {
    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var menuBarSettingsViewModel: MenuBarSettingsViewModel

    init() {
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(provider: dependencies.quoteProvider)

        _menuBarViewModel = StateObject(
            wrappedValue: menuBarViewModel
        )
        _menuBarSettingsViewModel = StateObject(
            wrappedValue: MenuBarSettingsViewModel(store: dependencies.menuBarSettingsStore)
        )

        Task {
            await menuBarViewModel.loadIfNeeded()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            MenuBarLabelView(
                viewModel: menuBarViewModel,
                settings: menuBarSettingsViewModel.settings
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: menuBarSettingsViewModel)
        }
    }
}
