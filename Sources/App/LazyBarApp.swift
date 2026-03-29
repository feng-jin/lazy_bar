/// 应用入口，负责创建菜单栏状态项并把依赖注入到对应的 ViewModel。
import AppKit
import SwiftUI

@main
struct LazyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let menuBarStatusItemController: MenuBarStatusItemController

    init() {
        let dependencies = AppDependencies.live
        let menuBarViewModel = MenuBarViewModel(provider: dependencies.quoteProvider)
        menuBarStatusItemController = MenuBarStatusItemController(viewModel: menuBarViewModel)
    }

    var body: some Scene {
        Settings {
            SettingsPlaceholderView()
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.title2.weight(.semibold))
            Text("当前版本仅提供设置入口，具体配置项会在后续版本补充。")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
    }
}
