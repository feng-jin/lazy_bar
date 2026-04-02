/// 左键点击状态栏后展示的股票列表面板内容。
import AppKit
import SwiftUI

struct QuotesPopoverView: View {
    private enum LayoutMetrics {
        static let maxQuotesListHeight: CGFloat = 220
    }

    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settingsStore: MenuBarSettingsStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        let settings = settingsStore.settings
        let displayQuotes = viewModel.displayQuotes
        let layout = QuoteColumnLayoutCalculator.layout(
            displayQuotes: displayQuotes,
            settings: settings,
            statusText: viewModel.statusMessage(settings: settings)
        )

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
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: LayoutMetrics.maxQuotesListHeight)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.leading, MenuBarStyle.Metrics.panelDividerLeadingInset)

            ActionsSection(onOpenSettings: onOpenSettings, onQuit: onQuit)
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
    let layout: QuoteColumnLayout
    @State private var isHovering = false

    var body: some View {
        QuoteColumnsRowView(
            columns: quote.columns(settings: settings),
            layout: layout,
            typography: .popover
        )
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
        viewModel: MenuBarViewModel(
            provider: MockQuoteProvider(),
            settingsStore: MenuBarSettingsStore()
        ),
        settingsStore: MenuBarSettingsStore(),
        onOpenSettings: {},
        onQuit: {}
    )
}
