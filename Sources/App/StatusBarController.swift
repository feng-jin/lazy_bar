/// 管理状态栏按钮、左键股票弹层和右键系统菜单。
/// 当前右键入口保持纯 AppKit `NSMenu`，因此不使用 SwiftUI `SettingsLink`。
import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private let quotesPopover: NSPopover
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
        quotesPopover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        bindState()
        updateStatusItemTitle()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        quotesPopover.behavior = .transient
        quotesPopover.contentSize = NSSize(width: 320, height: 220)
        quotesPopover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: menuBarViewModel)
        )
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
            showContextMenu(with: event)
        default:
            toggleQuotesPopover(sender)
        }
    }

    private func toggleQuotesPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if quotesPopover.isShown {
            quotesPopover.performClose(sender)
        } else {
            quotesPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            quotesPopover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(with event: NSEvent) {
        guard let button = statusItem.button else { return }

        quotesPopover.performClose(nil)

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

        NSMenu.popUpContextMenu(menu, with: event, for: button)
        button.highlight(false)
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
