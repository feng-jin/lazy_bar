/// 左键点击状态栏项后展示的股票列表弹层内容。
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                stateView(text: "加载中...")
            } else if viewModel.displayQuotes.isEmpty {
                stateView(text: "暂无股票")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.displayQuotes.enumerated()), id: \.element.symbol) { index, quote in
                        quoteRow(for: quote)

                        if index < viewModel.displayQuotes.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func stateView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(.horizontal, 16)
    }

    private func quoteRow(for quote: DisplayQuote) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.menuListTitleText)
                    .font(.system(size: 13, weight: .semibold))

                Text(quote.menuListDetailText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(quote.menuListTrailingText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(changeColor(for: quote))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func changeColor(for quote: DisplayQuote) -> Color {
        if quote.changePercentText.hasPrefix("+") {
            return .red
        }
        if quote.changePercentText.hasPrefix("-") {
            return .green
        } else {
            return .primary
        }
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView(viewModel: PreviewMocks.menuBarViewModel)
    }
}
