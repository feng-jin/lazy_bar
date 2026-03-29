/// 应用入口，负责创建菜单栏状态项并把依赖注入到对应的 ViewModel。
import AppKit
import SwiftUI

@main
@available(macOS 15.0, *)
struct LazyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let menuBarStatusItemController: MenuBarStatusItemController
    private let menuBarSettingsViewModel: MenuBarSettingsViewModel

    init() {
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(provider: dependencies.quoteProvider)
        menuBarSettingsViewModel = MenuBarSettingsViewModel(store: dependencies.menuBarSettingsStore)
        menuBarStatusItemController = MenuBarStatusItemController(
            viewModel: menuBarViewModel,
            settingsStore: dependencies.menuBarSettingsStore
        )
    }

    var body: some Scene {
        Settings {
            SettingsView(viewModel: menuBarSettingsViewModel)
        }
    }
}
