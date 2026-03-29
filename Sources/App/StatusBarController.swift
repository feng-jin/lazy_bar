/// 管理状态栏按钮、左键股票列表面板与右键系统菜单。
/// 设置入口保持纯 AppKit `NSMenu`，因此不使用 SwiftUI `SettingsLink`。
import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: MenuBarSettingsStore
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private var hostedLabelView: MouseTransparentHostingView<MenuBarLabelView>?
    private var quotesPanelController: QuotesPanelController?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(
        menuBarViewModel: MenuBarViewModel,
        settingsStore: MenuBarSettingsStore,
        openSettingsWindow: @escaping () -> Void
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.settingsStore = settingsStore
        self.openSettingsWindowHandler = openSettingsWindow
        let initialWidth = menuBarViewModel.columnLayout(settings: settingsStore.settings).itemWidth
        statusItem = NSStatusBar.system.statusItem(withLength: initialWidth)
        super.init()

        configureStatusItem()
        observeWidthChanges()
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
        updateStatusItemWidth()
    }

    private func observeWidthChanges() {
        menuBarViewModel.$displayQuotes
            .sink { [weak self] _ in
                self?.updateStatusItemWidth()
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .sink { [weak self] _ in
                self?.updateStatusItemWidth()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemWidth() {
        let layout = menuBarViewModel.columnLayout(settings: settingsStore.settings)
        statusItem.length = layout.itemWidth
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggleQuotesPanel()
        }
    }

    private func toggleQuotesPanel() {
        guard let button = statusItem.button else { return }

        if quotesPanelController?.isVisible == true {
            closeQuotesPanel()
            return
        }

        let panelController = QuotesPanelController(
            contentSize: quotesPanelSize(
            quoteCount: menuBarViewModel.displayQuotes.count,
            isLoading: menuBarViewModel.isLoading
        ),
            rootView: AnyView(
                QuotesPopoverView(
                viewModel: menuBarViewModel,
                settingsStore: settingsStore
            )
        )
        )
        panelController.show(relativeTo: button)
        quotesPanelController = panelController
        installClickMonitors()
    }

    private func closeQuotesPanel() {
        quotesPanelController?.close()
        quotesPanelController = nil
        removeClickMonitors()
    }

    private func quotesPanelSize(quoteCount: Int, isLoading: Bool) -> NSSize {
        let width = menuBarViewModel.columnLayout(settings: settingsStore.settings).itemWidth

        guard !isLoading, quoteCount > 0 else {
            return NSSize(width: width, height: 68)
        }

        let rowHeight: CGFloat = 38
        let verticalPadding: CGFloat = 18
        let height = min(360, verticalPadding + CGFloat(quoteCount) * rowHeight)
        return NSSize(width: width, height: height)
    }

    private func installClickMonitors() {
        removeClickMonitors()

        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            guard self.quotesPanelController?.isVisible == true else { return event }
            guard !self.isEventInsideQuotesPanelOrStatusItem(event) else { return event }
            self.closeQuotesPanel()
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            guard self.quotesPanelController?.isVisible == true else { return }
            let mouseLocation = NSEvent.mouseLocation
            guard !self.isPointInsideQuotesPanelOrStatusItem(mouseLocation) else { return }
            self.closeQuotesPanel()
        }
    }

    private func removeClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }

        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    private func isEventInsideQuotesPanelOrStatusItem(_ event: NSEvent) -> Bool {
        let pointOnScreen: NSPoint

        if let window = event.window {
            pointOnScreen = window.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
        } else {
            pointOnScreen = NSEvent.mouseLocation
        }

        return isPointInsideQuotesPanelOrStatusItem(pointOnScreen)
    }

    private func isPointInsideQuotesPanelOrStatusItem(_ point: NSPoint) -> Bool {
        if let panelFrame = quotesPanelController?.frame, panelFrame.contains(point) {
            return true
        }

        guard let button = statusItem.button else { return false }
        return statusItemButtonFrame(for: button).contains(point)
    }

    private func statusItemButtonFrame(for button: NSStatusBarButton) -> NSRect {
        guard let window = button.window else { return .zero }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        closeQuotesPanel()

        let menu = NSMenu()
        menu.delegate = self
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
    }

    func menuDidClose(_ menu: NSMenu) {
        if statusItem.menu === menu {
            statusItem.menu = nil
        }
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

private final class QuotesPanelController: NSWindowController {
    private enum Metrics {
        static let verticalGap: CGFloat = 4
        static let screenInset: CGFloat = 8
    }

    private let panel: QuotesPanel

    var isVisible: Bool {
        panel.isVisible
    }

    var frame: NSRect {
        panel.frame
    }

    init(contentSize: NSSize, rootView: AnyView) {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        panel = QuotesPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true
        panel.setContentSize(contentSize)

        super.init(window: panel)

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace]
        panel.isReleasedWhenClosed = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard let window = button.window else { return }

        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = NSPoint(
            x: buttonFrame.minX,
            y: buttonFrame.minY - panel.frame.height - Metrics.verticalGap
        )

        if let screen = window.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame.insetBy(
                dx: Metrics.screenInset,
                dy: Metrics.screenInset
            )
            origin.x = min(
                max(origin.x, visibleFrame.minX),
                visibleFrame.maxX - panel.frame.width
            )
            origin.y = max(origin.y, visibleFrame.minY)
        }

        panel.setFrameOrigin(origin)
        panel.setContentSize(panel.frame.size)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    override func close() {
        panel.orderOut(nil)
    }
}

private final class QuotesPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
