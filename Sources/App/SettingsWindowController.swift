/// 管理设置窗口的创建、展示和关闭；窗口内容继续复用 SwiftUI `SettingsView`。
import AppKit
import Combine
import os
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private enum Metrics {
        static let contentWidth: CGFloat = 500
        static let minimumContentHeight: CGFloat = 320
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "SettingsWindowController"
    )

    private let hostingView: NSHostingView<AnyView>
    private let viewModel: MenuBarSettingsViewModel
    private var rootViewIdentity = UUID()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MenuBarSettingsViewModel) {
        self.viewModel = viewModel
        let rootView = Self.makeRootView(
            viewModel: viewModel,
            rootViewIdentity: rootViewIdentity,
            onClose: nil
        )
        hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.contentWidth, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        let contentView = NSView(
            frame: NSRect(x: 0, y: 0, width: Metrics.contentWidth, height: 320)
        )
        contentView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        window.contentView = contentView
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: Metrics.contentWidth, height: Metrics.minimumContentHeight)
        window.center()

        super.init(window: window)

        hostingView.rootView = Self.makeRootView(
            viewModel: viewModel,
            rootViewIdentity: rootViewIdentity,
            onClose: { [weak self] in
                self?.close()
            }
        )

        bindDebugObservers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            Self.logger.error("show skipped because window is unavailable")
            return
        }

        Self.logger.debug("show settings window")

        NSApp.activate()
        viewModel.beginEditing()
        rootViewIdentity = UUID()
        hostingView.rootView = Self.makeRootView(
            viewModel: viewModel,
            rootViewIdentity: rootViewIdentity,
            onClose: { [weak self] in
                self?.close()
            }
        )

        DispatchQueue.main.async {
            let fittedSize = self.hostingView.fittingSize
            let contentHeight = max(Metrics.minimumContentHeight, ceil(fittedSize.height))
            Self.logger.debug(
                """
                resize settings window \
                fittedHeight=\(fittedSize.height, privacy: .public) \
                contentHeight=\(contentHeight, privacy: .public)
                """
            )
            window.setContentSize(NSSize(width: Metrics.contentWidth, height: contentHeight))

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.center()
            self.showWindow(nil)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
            Self.logger.debug("settings window visible")
        }
    }

    override func close() {
        Self.logger.debug("close settings window")
        super.close()
    }

    private func bindDebugObservers() {
        viewModel.$searchResults
            .sink { [weak self] results in
                self?.logSearchLayout(reason: "searchResults", resultCount: results.count)
            }
            .store(in: &cancellables)

        viewModel.$isSearching
            .sink { [weak self] isSearching in
                self?.logSearchLayout(reason: "isSearching=\(isSearching)")
            }
            .store(in: &cancellables)

        viewModel.$searchStatusMessage
            .sink { [weak self] message in
                self?.logSearchLayout(reason: "searchStatus", status: message)
            }
            .store(in: &cancellables)
    }

    private func logSearchLayout(
        reason: String,
        resultCount: Int? = nil,
        status: String? = nil
    ) {
        let fittedSize = hostingView.fittingSize
        let windowContentSize = window?.contentView?.bounds.size ?? .zero
        let windowFrameSize = window?.frame.size ?? .zero

        Self.logger.debug(
            """
            searchLayout reason=\(reason, privacy: .public) \
            query=\(self.viewModel.searchQuery, privacy: .public) \
            showsSearchResults=\(self.viewModel.showsSearchResults, privacy: .public) \
            resultCount=\(resultCount ?? self.viewModel.searchResults.count, privacy: .public) \
            status=\(status ?? self.viewModel.searchStatusMessage ?? "nil", privacy: .public) \
            fittedWidth=\(fittedSize.width, privacy: .public) \
            fittedHeight=\(fittedSize.height, privacy: .public) \
            contentWidth=\(windowContentSize.width, privacy: .public) \
            contentHeight=\(windowContentSize.height, privacy: .public) \
            frameWidth=\(windowFrameSize.width, privacy: .public) \
            frameHeight=\(windowFrameSize.height, privacy: .public)
            """
        )
    }

    private static func makeRootView(
        viewModel: MenuBarSettingsViewModel,
        rootViewIdentity: UUID,
        onClose: (() -> Void)?
    ) -> AnyView {
        AnyView(
            SettingsView(
                viewModel: viewModel,
                onClose: onClose
            )
            .id(rootViewIdentity)
        )
    }
}
