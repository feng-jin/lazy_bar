/// 左键点击状态栏后展示的股票列表面板内容。
import AppKit
import SwiftUI

struct QuotesPopoverView: View {
    private enum LayoutMetrics {
        static let maxQuotesListHeight: CGFloat = 220
    }

    @ObservedObject var presentationStore: MenuBarPresentationStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        let presentation = presentationStore.presentation

        VStack(spacing: 0) {
            Group {
                if !presentation.rows.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(presentation.rows.enumerated()), id: \.element.id) { index, row in
                                QuotePopoverRowView(
                                    row: row,
                                    layout: presentation.layout
                                )

                                if index < presentation.rows.count - 1 {
                                    Divider()
                                        .padding(.leading, MenuBarStyle.Metrics.panelDividerLeadingInset)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: LayoutMetrics.maxQuotesListHeight)
                } else {
                    stateView(text: presentation.statusText)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.leading, MenuBarStyle.Metrics.panelDividerLeadingInset)

            ActionsSection(onOpenSettings: onOpenSettings, onQuit: onQuit)
        }
        .padding(.vertical, MenuBarStyle.Metrics.panelOuterVerticalPadding)
        .frame(width: presentation.layout.itemWidth)
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
    let row: MenuBarPresentation.Row
    let layout: QuoteColumnLayout
    @State private var isHovering = false

    var body: some View {
        QuoteColumnsRowView(
            columns: row.columns,
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
        presentationStore: MenuBarPresentationStore(
            viewModel: PreviewMocks.menuBarViewModel,
            settingsStore: MenuBarSettingsStore()
        ),
        onOpenSettings: {},
        onQuit: {}
    )
}

#Preview("Loading") {
    let settingsStore = MenuBarSettingsStore()
    QuotesPopoverView(
        presentationStore: MenuBarPresentationStore(
            viewModel: MenuBarViewModel(
                provider: MockQuoteProvider(),
                settingsStore: settingsStore
            ),
            settingsStore: settingsStore
        ),
        onOpenSettings: {},
        onQuit: {}
    )
}
