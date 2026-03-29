/// 菜单栏上的紧凑 ticker 标签，在固定宽度内上下循环播放股票摘要。
import SwiftUI

enum MenuBarMetrics {
    static let horizontalInset: CGFloat = 10
    static let contentHeight: CGFloat = 16
    static let fontSize: CGFloat = 12
    static let verticalTextOffset: CGFloat = 1
    static let verticalHoldDuration: TimeInterval = 1.6
    static let verticalTransitionDuration: TimeInterval = 0.6
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
            height: MenuBarMetrics.contentHeight,
            alignment: .leading
        )
    }

    private func statusText(_ text: String, layout: MenuBarViewModel.ColumnLayout) -> some View {
        Text(text)
            .font(.system(size: MenuBarMetrics.fontSize, weight: .medium, design: .rounded))
            .lineLimit(1)
            .frame(
                width: layout.contentWidth,
                height: MenuBarMetrics.contentHeight,
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
                    height: MenuBarMetrics.contentHeight * 2,
                    alignment: .topLeading
                )
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarMetrics.contentHeight,
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
            titleColumn(columns: columns)
                .frame(width: titleColumnWidth, alignment: .leading)

            if let priceText = columns.priceText {
                Text(priceText)
                    .font(.system(size: MenuBarMetrics.fontSize - 1, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: layout.priceColumnWidth, alignment: .trailing)
                    .layoutPriority(1)
                    .padding(.leading, layout.columnSpacing)
            }

            if let changeText = columns.changeText {
                Text(changeText)
                    .font(.system(size: MenuBarMetrics.fontSize - 1, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: layout.changeColumnWidth, alignment: .trailing)
                    .layoutPriority(2)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .frame(
            width: layout.contentWidth,
            height: MenuBarMetrics.contentHeight,
            alignment: .topLeading
        )
        .offset(y: MenuBarMetrics.verticalTextOffset)
    }

    private var titleColumnWidth: CGFloat {
        let occupiedWidth = layout.priceWidthWithSpacing + layout.changeWidthWithSpacing
        return max(0, layout.contentWidth - occupiedWidth)
    }

    @ViewBuilder
    private func titleColumn(columns: DisplayQuote.MenuBarColumns) -> some View {
        HStack(spacing: 0) {
            Text(columns.primaryText)
                .font(.system(size: MenuBarMetrics.fontSize, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)

            if let secondaryText = columns.secondaryText {
                Text(secondaryText)
                    .font(.system(size: MenuBarMetrics.fontSize - 1, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
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
                try? await Task.sleep(for: .seconds(MenuBarMetrics.verticalHoldDuration))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: MenuBarMetrics.verticalTransitionDuration)) {
                    offsetY = -MenuBarMetrics.contentHeight
                }

                try? await Task.sleep(for: .seconds(MenuBarMetrics.verticalTransitionDuration))
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
