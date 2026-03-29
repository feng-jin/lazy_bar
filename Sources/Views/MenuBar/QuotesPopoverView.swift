/// 左键点击状态栏后展示的股票列表面板内容。
import AppKit
import SwiftUI

private enum QuotesPopoverMetrics {
    static let horizontalPadding: CGFloat = 6
}

struct QuotesPopoverView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settingsStore: MenuBarSettingsStore

    var body: some View {
        let settings = settingsStore.settings
        let displayQuotes = viewModel.displayQuotes
        let layout = viewModel.columnLayout(settings: settings)

        Group {
            if viewModel.isLoading {
                stateView(text: "加载中...")
            } else if displayQuotes.isEmpty {
                stateView(text: "暂无股票")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayQuotes.enumerated()), id: \.element.symbol) { index, quote in
                            QuotePopoverRowView(
                                quote: quote,
                                settings: settings,
                                layout: layout
                            )

                            if index < displayQuotes.count - 1 {
                                Divider()
                                    .padding(.leading, 10)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(4)
        .frame(width: layout.itemWidth)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private func stateView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
    }
}

private struct QuotePopoverRowView: View {
    let quote: DisplayQuote
    let settings: MenuBarDisplaySettings
    let layout: MenuBarViewModel.ColumnLayout
    @State private var isHovering = false

    var body: some View {
        let columns = quote.menuListColumns(settings: settings)

        HStack(spacing: 0) {
            nameColumn(columns: columns)

            if let priceText = columns.priceText {
                Text(priceText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: layout.priceColumnWidth, alignment: .trailing)
                    .layoutPriority(1)
                    .padding(.leading, layout.columnSpacing)
            }

            if let changeText = columns.changeText {
                Text(changeText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: layout.changeColumnWidth, alignment: .trailing)
                    .layoutPriority(2)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, QuotesPopoverMetrics.horizontalPadding)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isHovering
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
                        : .clear
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private func nameColumn(columns: DisplayQuote.MenuListColumns) -> some View {
        HStack(spacing: 0) {
            if let primaryText = columns.primaryText {
                Text(primaryText)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let secondaryText = columns.secondaryText {
                Text(secondaryText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
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
}

#Preview("Quotes") {
    QuotesPopoverView(
        viewModel: PreviewMocks.menuBarViewModel,
        settingsStore: MenuBarSettingsStore()
    )
}

#Preview("Loading") {
    QuotesPopoverView(
        viewModel: MenuBarViewModel(provider: MockQuoteProvider()),
        settingsStore: MenuBarSettingsStore()
    )
}
