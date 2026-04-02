/// 菜单栏上的紧凑 ticker 标签，在固定宽度内上下循环播放股票摘要。
import SwiftUI

enum MenuBarStyle {
    enum Metrics {
        static let statusItemHorizontalInset: CGFloat = 10
        static let columnSpacing: CGFloat = 4
        static let contentHeight: CGFloat = 16
        static let primaryFontSize: CGFloat = 12
        static let secondaryFontSize: CGFloat = 12
        static let popoverPrimaryFontSize: CGFloat = 12
        static let popoverValueFontSize: CGFloat = 12
        static let verticalTextOffset: CGFloat = 1
        static let verticalHoldDuration: TimeInterval = 1.6
        static let verticalTransitionDuration: TimeInterval = 0.6
        static let panelOuterVerticalPadding: CGFloat = 4
        static let panelRowHorizontalPadding: CGFloat = 10
        static let panelRowVerticalPadding: CGFloat = 7
        static let panelCornerRadius: CGFloat = 14
        static let panelRowCornerRadius: CGFloat = 8
        static let panelBorderOpacity: CGFloat = 0.45
        static let panelDividerLeadingInset: CGFloat = 10
    }

    static let identityTextColor = Color.primary

    static func primaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func identitySecondaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func valueTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func statusTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settingsStore: MenuBarSettingsStore

    var body: some View {
        let settings = settingsStore.settings
        let layout = QuoteColumnLayoutCalculator.layout(
            displayQuotes: viewModel.displayQuotes,
            settings: settings,
            statusText: viewModel.statusText
        )

        Group {
            let tickerItems = viewModel.displayQuotes.map {
                VerticalTickerView.TickerItem(id: $0.symbol, columns: $0.columns(settings: settings))
            }

            if !tickerItems.isEmpty {
                VerticalTickerView(items: tickerItems, layout: layout)
            } else {
                statusText(
                    viewModel.statusText,
                    layout: layout
                )
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarStyle.Metrics.contentHeight,
            alignment: .leading
        )
    }

    private func statusText(_ text: String, layout: QuoteColumnLayout) -> some View {
        Text(text)
            .font(MenuBarStyle.statusTextFont(size: MenuBarStyle.Metrics.primaryFontSize))
            .lineLimit(1)
            .frame(
                width: layout.contentWidth,
                height: MenuBarStyle.Metrics.contentHeight,
                alignment: .leading
            )
    }
}

private struct VerticalTickerView: View {
    struct TickerItem: Equatable, Identifiable {
        let id: String
        let columns: DisplayQuote.QuoteColumns
    }

    let items: [TickerItem]
    let layout: QuoteColumnLayout

    @State private var currentIndex = 0
    @State private var currentItemID: String?
    @State private var offsetY: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else if items.count == 1 {
                if let currentItem {
                    tickerRow(currentItem.columns)
                }
            } else {
                VStack(spacing: 0) {
                    if let currentItem, let nextItem {
                        tickerRow(currentItem.columns)
                        tickerRow(nextItem.columns)
                    }
                }
                .offset(y: offsetY)
                .frame(
                    width: layout.contentWidth,
                    height: MenuBarStyle.Metrics.contentHeight * 2,
                    alignment: .topLeading
                )
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarStyle.Metrics.contentHeight,
            alignment: .topLeading
        )
        .clipped()
        .onAppear {
            restartAnimation()
        }
        .onChange(of: items) {
            syncItemsChange()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private var nextIndex: Int {
        guard !items.isEmpty else { return 0 }
        return (safeCurrentIndex + 1) % items.count
    }

    private var safeCurrentIndex: Int {
        guard !items.isEmpty else { return 0 }
        return min(max(currentIndex, 0), items.count - 1)
    }

    private var nextItem: TickerItem? {
        guard items.count > 1 else { return currentItem }
        return items[nextIndex]
    }

    private var currentItem: TickerItem? {
        guard !items.isEmpty else { return nil }
        return items[safeCurrentIndex]
    }

    private func tickerRow(_ columns: DisplayQuote.QuoteColumns) -> some View {
        QuoteColumnsRowView(
            columns: columns,
            layout: layout,
            typography: .menuBar,
            height: MenuBarStyle.Metrics.contentHeight,
            verticalOffset: MenuBarStyle.Metrics.verticalTextOffset
        )
    }

    private func restartAnimation() {
        animationTask?.cancel()
        animationTask = nil
        currentIndex = 0
        currentItemID = items.first?.id
        offsetY = 0

        guard items.count > 1 else { return }

        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(MenuBarStyle.Metrics.verticalHoldDuration))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: MenuBarStyle.Metrics.verticalTransitionDuration)) {
                    offsetY = -MenuBarStyle.Metrics.contentHeight
                }

                try? await Task.sleep(for: .seconds(MenuBarStyle.Metrics.verticalTransitionDuration))
                guard !Task.isCancelled else { return }

                currentIndex = nextIndex
                currentItemID = currentItem?.id
                offsetY = 0
            }
        }
    }

    private func syncItemsChange() {
        guard !items.isEmpty else {
            animationTask?.cancel()
            animationTask = nil
            currentIndex = 0
            currentItemID = nil
            offsetY = 0
            return
        }

        if let currentItemID,
           let matchedIndex = items.firstIndex(where: { $0.id == currentItemID }) {
            currentIndex = matchedIndex
        } else if currentIndex >= items.count {
            currentIndex = 0
        }
        currentItemID = currentItem?.id

        if items.count == 1 {
            animationTask?.cancel()
            animationTask = nil
            offsetY = 0
            return
        }

        guard animationTask != nil else {
            restartAnimation()
            return
        }
    }
}

#Preview {
    MenuBarLabelView(
        viewModel: PreviewMocks.menuBarViewModel,
        settingsStore: MenuBarSettingsStore()
    )
    .padding()
}
