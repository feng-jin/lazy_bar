/// 管理设置窗口的创建、展示和关闭；窗口内容继续复用 SwiftUI `SettingsView`。
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(viewModel: MenuBarSettingsViewModel) {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                viewModel: viewModel,
                onClose: nil
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        hostingController.rootView = SettingsView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.close()
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
