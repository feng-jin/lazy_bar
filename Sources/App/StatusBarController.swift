/// 管理状态栏按钮与左键主面板。
import AppKit
import Combine
import os
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "StatusBarController"
    )

    private let menuBarViewModel: MenuBarViewModel
    private let openSettingsWindowHandler: () -> Void
    private let statusItem: NSStatusItem
    private var hostedLabelView: MouseTransparentHostingView<MenuBarLabelView>?
    private var quotesPanelController: QuotesPanelController?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(
        menuBarViewModel: MenuBarViewModel,
        openSettingsWindow: @escaping () -> Void
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.openSettingsWindowHandler = openSettingsWindow
        let initialWidth = menuBarViewModel.presentation.layout.itemWidth
        statusItem = NSStatusBar.system.statusItem(withLength: initialWidth)
        super.init()

        configureStatusItem()
        observeWidthChanges()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp])
        button.title = ""
        button.image = nil

        let labelView = MouseTransparentHostingView(
            rootView: MenuBarLabelView(
                presentation: menuBarViewModel.presentation
            )
        )
        labelView.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(labelView)
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(
                equalTo: button.leadingAnchor,
                constant: MenuBarStyle.Metrics.statusItemHorizontalInset
            ),
            labelView.trailingAnchor.constraint(
                equalTo: button.trailingAnchor,
                constant: -MenuBarStyle.Metrics.statusItemHorizontalInset
            ),
            labelView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            labelView.heightAnchor.constraint(equalToConstant: MenuBarStyle.Metrics.contentHeight)
        ])

        hostedLabelView = labelView
        refreshStatusItemPresentation(using: menuBarViewModel.presentation)
    }

    private func observeWidthChanges() {
        menuBarViewModel.$presentation
            .sink { [weak self] presentation in
                self?.refreshStatusItemPresentation(using: presentation)
            }
            .store(in: &cancellables)
    }

    private func refreshStatusItemPresentation(using presentation: MenuBarPresentation) {
        Self.logger.debug(
            """
            refreshStatusItemPresentation rows=\(presentation.rows.count, privacy: .public) \
            status=\(presentation.statusText, privacy: .public) \
            itemWidth=\(presentation.layout.itemWidth, privacy: .public) \
            contentWidth=\(presentation.layout.contentWidth, privacy: .public) \
            signature=\(Self.presentationSignature(for: presentation), privacy: .public)
            """
        )
        statusItem.length = presentation.layout.itemWidth

        guard let button = statusItem.button else { return }
        hostedLabelView?.rootView = MenuBarLabelView(
            presentation: presentation
        )
        hostedLabelView?.setFrameSize(
            NSSize(
                width: presentation.layout.contentWidth,
                height: MenuBarStyle.Metrics.contentHeight
            )
        )
        hostedLabelView?.needsLayout = true
        hostedLabelView?.layoutSubtreeIfNeeded()
        hostedLabelView?.needsDisplay = true
        hostedLabelView?.displayIfNeeded()
        button.needsLayout = true
        button.layoutSubtreeIfNeeded()
        button.needsDisplay = true
        button.displayIfNeeded()
    }

    private static func presentationSignature(for presentation: MenuBarPresentation) -> String {
        if presentation.rows.isEmpty {
            return "status:\(presentation.statusText)"
        }

        return presentation.rows
            .map { row in
                [
                    row.id,
                    row.columns.nameText ?? "",
                    row.columns.symbolText ?? "",
                    row.columns.priceText ?? "",
                    row.columns.changeText ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ",")
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        toggleQuotesPanel()
    }

    private func toggleQuotesPanel() {
        guard let button = statusItem.button else { return }

        if quotesPanelController?.isVisible == true {
            closeQuotesPanel()
            return
        }

        let panelController = QuotesPanelController(
            contentWidth: menuBarViewModel.presentation.layout.itemWidth,
            maximumContentHeight: 360,
            rootView: AnyView(
                QuotesPopoverView(
                    viewModel: menuBarViewModel,
                    onOpenSettings: { [weak self] in
                        self?.openSettings()
                    },
                    onQuit: { [weak self] in
                        self?.quitApp()
                    }
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

    @objc
    private func openSettings() {
        closeQuotesPanel()
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
        static let minimumContentHeight: CGFloat = 68
    }

    private let panel: QuotesPanel
    private let hostingView: NSHostingView<AnyView>

    var isVisible: Bool {
        panel.isVisible
    }

    var frame: NSRect {
        panel.frame
    }

    init(contentWidth: CGFloat, maximumContentHeight: CGFloat, rootView: AnyView) {
        hostingView = NSHostingView(rootView: rootView)
        let measuredHeight = Self.measuredContentHeight(
            for: hostingView,
            width: contentWidth,
            maximumContentHeight: maximumContentHeight
        )
        let contentSize = NSSize(width: contentWidth, height: measuredHeight)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        panel = QuotesPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = MenuBarStyle.Metrics.panelCornerRadius
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

    private static func measuredContentHeight(
        for hostingView: NSHostingView<AnyView>,
        width: CGFloat,
        maximumContentHeight: CGFloat
    ) -> CGFloat {
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: maximumContentHeight
        )
        let fittedHeight = hostingView.fittingSize.height
        let clampedHeight = min(
            maximumContentHeight,
            max(Metrics.minimumContentHeight, ceil(fittedHeight))
        )
        return clampedHeight
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
