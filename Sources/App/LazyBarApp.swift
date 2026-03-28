/// 应用入口，负责创建菜单栏项并把依赖注入到各个 ViewModel。
import AppKit
import SwiftUI

@main
struct LazyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var detailViewModel: StockDetailViewModel

    init() {
        let dependencies = AppDependencies.live
        _menuBarViewModel = StateObject(
            wrappedValue: MenuBarViewModel(provider: dependencies.quoteProvider)
        )
        _detailViewModel = StateObject(
            wrappedValue: StockDetailViewModel(provider: dependencies.quoteProvider)
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: detailViewModel)
                .frame(width: 320)
                .task {
                    await detailViewModel.loadIfNeeded()
                }
        } label: {
            MenuBarLabelView(viewModel: menuBarViewModel)
                .task {
                    await menuBarViewModel.loadIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
