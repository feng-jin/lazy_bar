/// 管理状态栏按钮、左键股票列表 popover 与右键系统菜单。
/// 设置入口保持纯 AppKit `NSMenu`，因此不使用 SwiftUI `SettingsLink`。
import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private var hostedLabelView: MouseTransparentHostingView<MenuBarLabelView>?
    private var quotesPopover: NSPopover?

    init(
        menuBarViewModel: MenuBarViewModel,
        settingsStore: MenuBarSettingsStore,
        openSettingsWindow: @escaping () -> Void
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.settingsStore = settingsStore
        self.openSettingsWindowHandler = openSettingsWindow
        statusItem = NSStatusBar.system.statusItem(withLength: MenuBarMetrics.itemWidth)
        super.init()

        configureStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.title = ""
        button.image = nil

        let labelView = MouseTransparentHostingView(
            rootView: MenuBarLabelView(
                viewModel: menuBarViewModel,
                settingsStore: settingsStore
            )
        )
        labelView.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(labelView)
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(
                equalTo: button.leadingAnchor,
                constant: MenuBarMetrics.horizontalInset
            ),
            labelView.trailingAnchor.constraint(
                equalTo: button.trailingAnchor,
                constant: -MenuBarMetrics.horizontalInset
            ),
            labelView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            labelView.heightAnchor.constraint(equalToConstant: MenuBarMetrics.contentHeight)
        ])

        hostedLabelView = labelView
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggleQuotesPopover()
        }
    }

    private func toggleQuotesPopover() {
        guard let button = statusItem.button else { return }

        if quotesPopover?.isShown == true {
            quotesPopover?.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = quotesPopoverSize(
            quoteCount: menuBarViewModel.displayQuotes.count,
            isLoading: menuBarViewModel.isLoading
        )
        popover.contentViewController = NSHostingController(
            rootView: QuotesPopoverView(
                viewModel: menuBarViewModel,
                settingsStore: settingsStore
            )
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        quotesPopover = popover
    }

    private func quotesPopoverSize(quoteCount: Int, isLoading: Bool) -> NSSize {
        let width: CGFloat = 280

        guard !isLoading, quoteCount > 0 else {
            return NSSize(width: width, height: 72)
        }

        let rowHeight: CGFloat = 54
        let verticalPadding: CGFloat = 20
        let height = min(360, verticalPadding + CGFloat(quoteCount) * rowHeight)
        return NSSize(width: width, height: height)
    }

    private func showContextMenu() {
        guard statusItem.button != nil else { return }
        quotesPopover?.performClose(nil)

        let menu = NSMenu()
        menu.addItem(
            withTitle: "设置 Settings",
            action: #selector(openSettingsWindow),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出 Quit Lazy Bar",
            action: #selector(quitApp),
            keyEquivalent: ""
        ).target = self

        statusItem.popUpMenu(menu)
        statusItem.button?.highlight(false)
    }

    @objc
    private func openSettingsWindow() {
        openSettingsWindowHandler()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

private final class MouseTransparentHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
