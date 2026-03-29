/// 管理状态栏按钮，以及左右键统一使用的系统菜单。
/// 当前菜单入口保持纯 AppKit `NSMenu`，因此不使用 SwiftUI `SettingsLink`。
import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(
        menuBarViewModel: MenuBarViewModel,
        settingsStore: MenuBarSettingsStore,
        openSettingsWindow: @escaping () -> Void
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.settingsStore = settingsStore
        self.openSettingsWindowHandler = openSettingsWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        bindState()
        updateStatusItemTitle()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func bindState() {
        menuBarViewModel.$displayQuotes
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        menuBarViewModel.$currentDisplayQuote
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        menuBarViewModel.$isLoading
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }

        if let quote = menuBarViewModel.displayQuote {
            button.title = quote.menuBarSummaryText(settings: settingsStore.settings)
        } else if menuBarViewModel.isLoading {
            button.title = "加载中..."
        } else {
            button.title = "行情不可用"
        }

        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.lineBreakMode = .byTruncatingTail
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
