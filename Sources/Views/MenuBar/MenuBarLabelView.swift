/// 菜单栏上的紧凑 ticker 标签，在固定宽度内上下循环播放股票摘要。
import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation

    var body: some View {
        Group {
            if !presentation.rows.isEmpty {
                VerticalTickerView(items: presentation.rows, layout: presentation.layout)
            } else {
                statusText(
                    presentation.statusText,
                    layout: presentation.layout
                )
            }
        }
        .id(contentIdentity(for: presentation))
        .frame(
            width: presentation.layout.contentWidth,
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

    private func contentIdentity(for presentation: MenuBarPresentation) -> String {
        if presentation.rows.isEmpty {
            return "status:\(presentation.statusText):\(presentation.layout.itemWidth)"
        }

        let rowsSignature = presentation.rows
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
        return "rows:\(rowsSignature):\(presentation.layout.itemWidth)"
    }
}

private struct VerticalTickerView: View {
    let items: [MenuBarPresentation.Row]
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

    private var nextItem: MenuBarPresentation.Row? {
        guard items.count > 1 else { return currentItem }
        return items[nextIndex]
    }

    private var currentItem: MenuBarPresentation.Row? {
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
        presentation: PreviewMocks.menuBarViewModel.presentation
    )
    .padding()
}
