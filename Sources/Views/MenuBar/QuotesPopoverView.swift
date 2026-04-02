/// 左键点击状态栏后展示的股票列表面板内容。
import AppKit
import SwiftUI

struct QuotesPopoverView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settingsStore: MenuBarSettingsStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        let settings = settingsStore.settings
        let displayQuotes = viewModel.displayQuotes
        let layout = viewModel.columnLayout(settings: settings)

        VStack(spacing: 0) {
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
                                        .padding(.leading, MenuBarStyle.Metrics.panelDividerLeadingInset)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            ActionsSection(onOpenSettings: onOpenSettings, onQuit: onQuit)
                .padding(.vertical, 4)
        }
        .padding(.vertical, MenuBarStyle.Metrics.panelOuterVerticalPadding)
        .frame(width: layout.itemWidth)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MenuBarStyle.Metrics.panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MenuBarStyle.Metrics.panelCornerRadius, style: .continuous)
                .stroke(
                    Color(nsColor: .separatorColor).opacity(MenuBarStyle.Metrics.panelBorderOpacity),
                    lineWidth: 0.5
                )
        }
    }

    @ViewBuilder
    private func stateView(text: String) -> some View {
        Text(text)
            .font(MenuBarStyle.statusTextFont(size: MenuBarStyle.Metrics.popoverPrimaryFontSize))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
    }
}

private struct ActionsSection: View {
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ActionRowView(
                title: "设置",
                systemImage: "gearshape",
                action: onOpenSettings
            )

            Divider()
                .padding(.leading, MenuBarStyle.Metrics.panelDividerLeadingInset)

            ActionRowView(
                title: "退出",
                systemImage: "power",
                action: onQuit
            )
        }
    }
}

private struct ActionRowView: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)

                Text(title)
                    .font(MenuBarStyle.primaryTextFont(size: MenuBarStyle.Metrics.popoverPrimaryFontSize))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MenuBarStyle.Metrics.panelRowHorizontalPadding)
            .padding(.vertical, MenuBarStyle.Metrics.panelRowVerticalPadding)
            .background {
                RoundedRectangle(
                    cornerRadius: MenuBarStyle.Metrics.panelRowCornerRadius,
                    style: .continuous
                )
                .fill(
                    isHovering
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
                        : .clear
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: MenuBarStyle.Metrics.panelRowCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
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
                    .font(MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.popoverValueFontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: layout.priceColumnWidth, alignment: .trailing)
                    .layoutPriority(1)
                    .padding(.leading, layout.columnSpacing)
            }

            if let changeText = columns.changeText {
                Text(changeText)
                    .font(MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.popoverValueFontSize))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: layout.changeColumnWidth, alignment: .trailing)
                    .layoutPriority(2)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuBarStyle.Metrics.panelRowHorizontalPadding)
        .padding(.vertical, MenuBarStyle.Metrics.panelRowVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: MenuBarStyle.Metrics.panelRowCornerRadius, style: .continuous)
                .fill(
                    isHovering
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
                        : .clear
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: MenuBarStyle.Metrics.panelRowCornerRadius, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var nameColumnWidth: CGFloat {
        let occupiedWidth =
            layout.symbolWidthWithSpacing +
            layout.priceWidthWithSpacing +
            layout.changeWidthWithSpacing
        return max(0, layout.contentWidth - occupiedWidth)
    }

    @ViewBuilder
    private func nameColumn(columns: DisplayQuote.MenuListColumns) -> some View {
        Text(columns.nameText ?? "")
            .font(MenuBarStyle.primaryTextFont(size: MenuBarStyle.Metrics.popoverPrimaryFontSize))
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Quotes") {
    QuotesPopoverView(
        viewModel: PreviewMocks.menuBarViewModel,
        settingsStore: MenuBarSettingsStore(),
        onOpenSettings: {},
        onQuit: {}
    )
}

#Preview("Loading") {
    QuotesPopoverView(
        viewModel: MenuBarViewModel(provider: MockQuoteProvider()),
        settingsStore: MenuBarSettingsStore(),
        onOpenSettings: {},
        onQuit: {}
    )
}
