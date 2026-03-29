/// 管理状态栏按钮、左键股票弹层和右键操作菜单。
import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(
        menuBarViewModel: MenuBarViewModel,
        settingsStore: MenuBarSettingsStore
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.settingsStore = settingsStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
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
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: menuBarViewModel)
        )
    }

    private func bindState() {
        menuBarViewModel.$displayQuotes
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
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        popover.performClose(nil)

        guard let button = statusItem.button else { return }

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

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
