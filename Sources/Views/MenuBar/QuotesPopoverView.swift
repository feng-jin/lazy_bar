/// 左键点击状态栏后展示的股票列表面板内容。
import SwiftUI

struct QuotesPopoverView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settingsStore: MenuBarSettingsStore

    var body: some View {
        let tickerItems = viewModel.menuBarTickerItems(settings: settingsStore.settings)

        Group {
            if viewModel.isLoading {
                stateView(text: "加载中...")
            } else if tickerItems.isEmpty {
                stateView(text: "暂无股票")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(tickerItems.enumerated()), id: \.element.id) { index, item in
                            QuotePopoverRowView(text: item.text)

                            if index < tickerItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 280)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func stateView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
    }
}

private struct QuotePopoverRowView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
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
