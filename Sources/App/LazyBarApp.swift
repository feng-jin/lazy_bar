/// 应用入口，负责创建状态栏控制器并把依赖注入到对应的 ViewModel。
import os
import SwiftUI

@main
struct LazyBarApp: App {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "LazyBarApp"
    )

    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var menuBarSettingsViewModel: MenuBarSettingsViewModel
    private let appUpdater: AppUpdater
    private let settingsWindowController: SettingsWindowController
    private let statusBarController: StatusBarController

    init() {
        Self.logger.debug("init start")
        appUpdater = AppUpdater()
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(
            settingsStore: dependencies.menuBarSettingsStore,
            quoteSession: dependencies.quoteSession
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
            checkForUpdates: { [appUpdater] in
                appUpdater.checkForUpdates()
            },
            openSettingsWindow: { [settingsWindowController] in
                settingsWindowController.show()
            }
        )
        Self.logger.debug("init finished wiring controllers and view models")

        Task {
            Self.logger.debug("initial load task started")
            await menuBarViewModel.loadIfNeeded()
            Self.logger.debug("initial load task finished")
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
