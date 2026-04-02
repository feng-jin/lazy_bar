/// 管理设置窗口的创建、展示和关闭；窗口内容继续复用 SwiftUI `SettingsView`。
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private enum Metrics {
        static let contentWidth: CGFloat = 360
        static let minimumContentHeight: CGFloat = 240
    }

    private let hostingView: NSHostingView<SettingsView>

    init(viewModel: MenuBarSettingsViewModel) {
        hostingView = NSHostingView(
            rootView: SettingsView(
                viewModel: viewModel,
                onClose: nil
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.contentWidth, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        let contentView = NSView(
            frame: NSRect(x: 0, y: 0, width: Metrics.contentWidth, height: 320)
        )
        contentView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        window.contentView = contentView
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: Metrics.contentWidth, height: Metrics.minimumContentHeight)
        window.center()

        super.init(window: window)

        hostingView.rootView = SettingsView(
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
        guard let window else { return }

        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.async {
            let fittedSize = self.hostingView.fittingSize
            let contentHeight = max(Metrics.minimumContentHeight, ceil(fittedSize.height))
            window.setContentSize(NSSize(width: Metrics.contentWidth, height: contentHeight))

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.center()
            self.showWindow(nil)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
        }
    }
}
