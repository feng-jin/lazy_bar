/// 管理状态栏按钮与左键主面板。
import AppKit
import Combine
import os
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private enum Metrics {
        static let maximumPanelContentHeight: CGFloat = 360
    }

    fileprivate static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "StatusBarController"
    )

    private let menuBarViewModel: MenuBarViewModel
    private let checkForUpdatesHandler: () -> Void
    private let openSettingsWindowHandler: () -> Void
    private let statusItemHost: StatusItemHost
    private let panelCoordinator = QuotesPanelCoordinator()
    private var cancellables: Set<AnyCancellable> = []

    init(
        menuBarViewModel: MenuBarViewModel,
        checkForUpdates: @escaping () -> Void,
        openSettingsWindow: @escaping () -> Void
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.checkForUpdatesHandler = checkForUpdates
        self.openSettingsWindowHandler = openSettingsWindow
        statusItemHost = StatusItemHost(
            initialPresentation: MenuBarPresentation(renderState: menuBarViewModel.renderState)
        )
        super.init()

        statusItemHost.configure(target: self, action: #selector(handleStatusItemClick(_:)))
        observePresentationChanges()
    }

    private func observePresentationChanges() {
        menuBarViewModel.$renderState
            .sink { [weak self] renderState in
                self?.syncPresentation(MenuBarPresentation(renderState: renderState))
            }
            .store(in: &cancellables)
    }

    private func syncPresentation(_ presentation: MenuBarPresentation) {
        Self.logger.debug(
            """
            syncPresentation rows=\(presentation.rows.count, privacy: .public) \
            status=\(presentation.statusText, privacy: .public) \
            itemWidth=\(presentation.layout.itemWidth, privacy: .public) \
            contentWidth=\(presentation.layout.contentWidth, privacy: .public) \
            signature=\(presentation.debugSignature, privacy: .public)
            """
        )
        guard let button = statusItemHost.button else {
            Self.logger.error("syncPresentation skipped because status item button is unavailable")
            return
        }
        statusItemHost.sync(presentation: presentation)
        panelCoordinator.updateLayout(
            contentWidth: presentation.layout.itemWidth,
            maximumContentHeight: Metrics.maximumPanelContentHeight,
            relativeTo: button
        )
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        Self.logger.debug("handleStatusItemClick")
        toggleQuotesPanel()
    }

    private func toggleQuotesPanel() {
        guard let button = statusItemHost.button else {
            Self.logger.error("toggleQuotesPanel skipped because status item button is unavailable")
            return
        }

        let presentation = MenuBarPresentation(renderState: menuBarViewModel.renderState)
        Self.logger.debug(
            """
            toggleQuotesPanel isOpen=\(self.panelCoordinator.isVisible, privacy: .public) \
            rows=\(presentation.rows.count, privacy: .public) \
            status=\(presentation.statusText, privacy: .public)
            """
        )

        panelCoordinator.toggle(
            contentWidth: presentation.layout.itemWidth,
            maximumContentHeight: Metrics.maximumPanelContentHeight,
            relativeTo: button,
            statusItemFrameProvider: { [weak self] in
                self?.statusItemHost.buttonFrameOnScreen() ?? .zero
            },
            rootView: AnyView(
                QuotesPopoverView(
                    viewModel: menuBarViewModel,
                    onCheckForUpdates: { [weak self] in
                        self?.checkForUpdates()
                    },
                    onOpenSettings: { [weak self] in
                        self?.openSettings()
                    },
                    onQuit: { [weak self] in
                        self?.quitApp()
                    }
                )
            )
        )
    }

    @objc
    private func checkForUpdates() {
        Self.logger.debug("checkForUpdates from panel")
        panelCoordinator.close()
        checkForUpdatesHandler()
    }

    @objc
    private func openSettings() {
        Self.logger.debug("openSettings from panel")
        panelCoordinator.close()
        openSettingsWindowHandler()
    }

    @objc
    private func quitApp() {
        Self.logger.debug("quitApp")
        NSApp.terminate(nil)
    }
}

private final class MouseTransparentHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
private final class StatusItemHost {
    let statusItem: NSStatusItem
    private var hostedLabelView: MouseTransparentHostingView<MenuBarLabelView>?
    private var refreshGeneration: UInt = 0

    init(initialPresentation: MenuBarPresentation) {
        statusItem = NSStatusBar.system.statusItem(withLength: initialPresentation.layout.itemWidth)
        installLabelView(initialPresentation: initialPresentation)
        sync(presentation: initialPresentation)
    }

    var button: NSStatusBarButton? {
        statusItem.button
    }

    func configure(target: AnyObject, action: Selector) {
        guard let button = statusItem.button else { return }
        button.target = target
        button.action = action
        button.sendAction(on: [.leftMouseUp])
        button.title = ""
        button.image = nil
    }

    func sync(presentation: MenuBarPresentation) {
        statusItem.length = presentation.layout.itemWidth

        guard let button = statusItem.button else { return }
        hostedLabelView?.rootView = MenuBarLabelView(presentation: presentation)
        hostedLabelView?.setFrameSize(
            NSSize(
                width: presentation.layout.contentWidth,
                height: MenuBarStyle.Metrics.contentHeight
            )
        )
        refreshViewHierarchy(hostedView: hostedLabelView, button: button)
    }

    func buttonFrameOnScreen() -> NSRect {
        guard let button, let window = button.window else { return .zero }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow)
    }

    private func installLabelView(initialPresentation: MenuBarPresentation) {
        guard let button = statusItem.button else { return }

        let labelView = MouseTransparentHostingView(
            rootView: MenuBarLabelView(presentation: initialPresentation)
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
    }

    private func refreshViewHierarchy(
        hostedView: NSView?,
        button: NSStatusBarButton
    ) {
        refreshGeneration &+= 1
        let generation = refreshGeneration

        hostedView?.needsLayout = true
        hostedView?.needsDisplay = true
        button.needsLayout = true
        button.needsDisplay = true

        DispatchQueue.main.async { [weak self, weak hostedView, weak button] in
            guard
                let self,
                self.refreshGeneration == generation,
                let button
            else { return }

            hostedView?.layoutSubtreeIfNeeded()
            hostedView?.displayIfNeeded()
            button.layoutSubtreeIfNeeded()
            button.displayIfNeeded()
        }
    }
}

@MainActor
private final class QuotesPanelCoordinator {
    private var panelController: QuotesPanelController?
    private var outsideClickMonitor: OutsideClickMonitor?

    var isVisible: Bool {
        panelController?.isVisible == true
    }

    func toggle(
        contentWidth: CGFloat,
        maximumContentHeight: CGFloat,
        relativeTo button: NSStatusBarButton,
        statusItemFrameProvider: @escaping () -> NSRect,
        rootView: AnyView
    ) {
        if panelController?.isVisible == true {
            StatusBarController.logger.debug("QuotesPanelCoordinator.toggle -> close existing panel")
            close()
            return
        }

        StatusBarController.logger.debug(
            """
            QuotesPanelCoordinator.toggle -> open panel \
            contentWidth=\(contentWidth, privacy: .public) \
            maximumContentHeight=\(maximumContentHeight, privacy: .public)
            """
        )
        let panelController = QuotesPanelController(
            contentWidth: contentWidth,
            maximumContentHeight: maximumContentHeight,
            rootView: rootView
        )
        panelController.show(relativeTo: button)
        self.panelController = panelController
        outsideClickMonitor = OutsideClickMonitor(
            panelFrameProvider: { [weak panelController] in
                panelController?.frame ?? .zero
            },
            statusItemFrameProvider: statusItemFrameProvider,
            onOutsideClick: { [weak self] in
                self?.close()
            }
        )
    }

    func updateLayout(
        contentWidth: CGFloat,
        maximumContentHeight: CGFloat,
        relativeTo button: NSStatusBarButton
    ) {
        StatusBarController.logger.debug(
            """
            QuotesPanelCoordinator.updateLayout \
            isVisible=\(self.isVisible, privacy: .public) \
            contentWidth=\(contentWidth, privacy: .public)
            """
        )
        panelController?.updateLayout(
            contentWidth: contentWidth,
            maximumContentHeight: maximumContentHeight,
            relativeTo: button
        )
    }

    func close() {
        StatusBarController.logger.debug("QuotesPanelCoordinator.close")
        panelController?.close()
        panelController = nil
        outsideClickMonitor = nil
    }
}

@MainActor
private final class OutsideClickMonitor {
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init(
        panelFrameProvider: @escaping () -> NSRect,
        statusItemFrameProvider: @escaping () -> NSRect,
        onOutsideClick: @escaping () -> Void
    ) {
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { event in
            let point = Self.pointOnScreen(for: event)
            let isInsidePanel = panelFrameProvider().contains(point)
            let isInsideStatusItem = statusItemFrameProvider().contains(point)

            if !isInsidePanel && !isInsideStatusItem {
                onOutsideClick()
            }

            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            let point = NSEvent.mouseLocation
            let isInsidePanel = panelFrameProvider().contains(point)
            let isInsideStatusItem = statusItemFrameProvider().contains(point)

            if !isInsidePanel && !isInsideStatusItem {
                onOutsideClick()
            }
        }
    }

    deinit {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }

        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
    }

    private static func pointOnScreen(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
        }

        return NSEvent.mouseLocation
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

    func updateLayout(
        contentWidth: CGFloat,
        maximumContentHeight: CGFloat,
        relativeTo button: NSStatusBarButton
    ) {
        let measuredHeight = Self.measuredContentHeight(
            for: hostingView,
            width: contentWidth,
            maximumContentHeight: maximumContentHeight
        )
        let contentSize = NSSize(width: contentWidth, height: measuredHeight)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)
        panel.setContentSize(contentSize)

        guard isVisible else { return }
        show(relativeTo: button)
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
