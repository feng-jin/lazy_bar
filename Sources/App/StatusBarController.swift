/// 管理状态栏按钮，以及左右键统一使用的系统菜单。
/// 当前菜单入口保持纯 AppKit `NSMenu`，因此不使用 SwiftUI `SettingsLink`。
import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private var hostedLabelView: MouseTransparentHostingView<MenuBarLabelView>?

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
            showQuotesMenu()
        }
    }

    private func showQuotesMenu() {
        guard statusItem.button != nil else { return }

        let menu = makeQuotesMenu()
        statusItem.popUpMenu(menu)
        statusItem.button?.highlight(false)
    }

    private func makeQuotesMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        populateQuotesMenu(menu)
        return menu
    }

    private func populateQuotesMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        if menuBarViewModel.isLoading {
            let item = NSMenuItem(title: "加载中...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        if menuBarViewModel.displayQuotes.isEmpty {
            let item = NSMenuItem(title: "暂无股票", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for quote in menuBarViewModel.displayQuotes {
            let item = NSMenuItem(
                title: quote.menuListSummaryText,
                action: #selector(ignoreMenuSelection),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
        }
    }

    private func showContextMenu() {
        guard statusItem.button != nil else { return }

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
    private func ignoreMenuSelection() {}

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
