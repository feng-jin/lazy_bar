/// 处理不适合放进 SwiftUI 视图里的 macOS 应用级行为。
import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@available(macOS 15.0, *)
@MainActor
final class MenuBarStatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let viewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MenuBarViewModel, settingsStore: MenuBarSettingsStore) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        configureStatusItem()
        configurePopover()
        bindViewModel()

        Task {
            await viewModel.loadIfNeeded()
        }
    }

    private func configureStatusItem() {
        statusItem.button?.appearsDisabled = false
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        updateStatusItemTitle(
            displayQuote: viewModel.displayQuote,
            isLoading: viewModel.isLoading,
            settings: settingsStore.settings
        )
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 180, height: 76)
        popover.contentViewController = NSHostingController(rootView: MenuBarContentView())
    }

    private func bindViewModel() {
        Publishers.CombineLatest3(
            viewModel.$displayQuote,
            viewModel.$isLoading,
            settingsStore.$settings
        )
            .sink { [weak self] displayQuote, isLoading, settings in
                self?.updateStatusItemTitle(
                    displayQuote: displayQuote,
                    isLoading: isLoading,
                    settings: settings
                )
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle(
        displayQuote: DisplayQuote?,
        isLoading: Bool,
        settings: MenuBarDisplaySettings
    ) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = makeStatusItemTitle(
            displayQuote: displayQuote,
            isLoading: isLoading,
            settings: settings
        )
    }

    private func makeStatusItemTitle(
        displayQuote: DisplayQuote?,
        isLoading: Bool,
        settings: MenuBarDisplaySettings
    ) -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        if let quote = displayQuote {
            let title = NSMutableAttributedString(
                string: quote.menuBarSummaryText(settings: settings),
                attributes: baseAttributes
            )

            if settings.usesChangeColor, settings.showsChangePercent {
                let summaryText = title.string as NSString
                let changeRange = summaryText.range(of: quote.changePercentText)

                if changeRange.location != NSNotFound {
                    title.addAttribute(
                        .foregroundColor,
                        value: NSColor(quote.change.tintColor),
                        range: changeRange
                    )
                }
            }

            return title
        }

        let fallbackText = isLoading ? "加载中..." : "行情不可用"
        return NSAttributedString(string: fallbackText, attributes: baseAttributes)
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }
}
