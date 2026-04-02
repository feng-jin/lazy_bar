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

    static func primaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func secondaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
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
        let layout = viewModel.columnLayout(settings: settingsStore.settings)

        Group {
            let tickerItems = viewModel.menuBarTickerItems(settings: settingsStore.settings)

            if !tickerItems.isEmpty {
                VerticalTickerView(items: tickerItems, layout: layout)
            } else if viewModel.isLoading {
                statusText("加载中...", layout: layout)
            } else {
                statusText("行情不可用", layout: layout)
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarStyle.Metrics.contentHeight,
            alignment: .leading
        )
    }

    private func statusText(_ text: String, layout: MenuBarViewModel.ColumnLayout) -> some View {
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
    let items: [MenuBarViewModel.MenuBarTickerItem]
    let layout: MenuBarViewModel.ColumnLayout

    @State private var currentIndex = 0
    @State private var currentItemID: String?
    @State private var offsetY: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else if items.count == 1 {
                tickerRow(items[0].columns)
            } else {
                VStack(spacing: 0) {
                    tickerRow(items[currentIndex].columns)
                    tickerRow(items[nextIndex].columns)
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
        return (currentIndex + 1) % items.count
    }

    private func tickerRow(_ columns: DisplayQuote.MenuBarColumns) -> some View {
        HStack(spacing: 0) {
            nameColumn(columns: columns)
                .frame(width: nameColumnWidth, alignment: .leading)

            if let symbolText = columns.symbolText {
                Text(symbolText)
                    .font(MenuBarStyle.secondaryTextFont(size: MenuBarStyle.Metrics.secondaryFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: layout.symbolColumnWidth, alignment: .leading)
                    .padding(.leading, layout.columnSpacing)
            }

            if let priceText = columns.priceText {
                Text(priceText)
                    .font(MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.secondaryFontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: layout.priceColumnWidth, alignment: .trailing)
                    .layoutPriority(1)
                    .padding(.leading, layout.columnSpacing)
            }

            if let changeText = columns.changeText {
                Text(changeText)
                    .font(MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.secondaryFontSize))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: layout.changeColumnWidth, alignment: .trailing)
                    .layoutPriority(2)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarStyle.Metrics.contentHeight,
            alignment: .topLeading
        )
        .offset(y: MenuBarStyle.Metrics.verticalTextOffset)
    }

    private var nameColumnWidth: CGFloat {
        let occupiedWidth =
            layout.symbolWidthWithSpacing +
            layout.priceWidthWithSpacing +
            layout.changeWidthWithSpacing
        return max(0, layout.contentWidth - occupiedWidth)
    }

    @ViewBuilder
    private func nameColumn(columns: DisplayQuote.MenuBarColumns) -> some View {
        Text(columns.nameText ?? "")
            .font(MenuBarStyle.primaryTextFont(size: MenuBarStyle.Metrics.primaryFontSize))
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(3)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                currentItemID = items[currentIndex].id
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
        currentItemID = items[currentIndex].id

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
