/// 处理不适合放进 SwiftUI 视图里的 macOS 应用级行为。
import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
final class MenuBarStatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let viewModel: MenuBarViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
        configureStatusItem()
        bindViewModel()

        Task {
            await viewModel.loadIfNeeded()
        }
    }

    private func configureStatusItem() {
        statusItem.menu = makeMenu()
        statusItem.button?.appearsDisabled = false
        updateStatusItemTitle(displayQuote: viewModel.displayQuote, isLoading: viewModel.isLoading)
    }

    private func bindViewModel() {
        viewModel.$displayQuote
            .combineLatest(viewModel.$isLoading)
            .sink { [weak self] displayQuote, isLoading in
                self?.updateStatusItemTitle(displayQuote: displayQuote, isLoading: isLoading)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle(displayQuote: DisplayQuote?, isLoading: Bool) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = makeStatusItemTitle(displayQuote: displayQuote, isLoading: isLoading)
    }

    private func makeStatusItemTitle(displayQuote: DisplayQuote?, isLoading: Bool) -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        if let quote = displayQuote {
            let title = NSMutableAttributedString()
            title.append(
                NSAttributedString(
                    string: "\(quote.menuBarNameText) \(quote.menuBarPriceText) ",
                    attributes: baseAttributes
                )
            )
            title.append(
                NSAttributedString(
                    string: quote.changePercentText,
                    attributes: baseAttributes.merging(
                        [.foregroundColor: quote.change.appKitTintColor],
                        uniquingKeysWith: { _, new in new }
                    )
                )
            )
            return title
        }

        let fallbackText = isLoading ? "加载中..." : "行情不可用"
        return NSAttributedString(string: fallbackText, attributes: baseAttributes)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
