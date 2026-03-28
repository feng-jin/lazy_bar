/// 点击菜单栏项后展开的主内容视图。
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: StockDetailViewModel

    var body: some View {
        Group {
            if let quote = viewModel.displayQuote {
                VStack(alignment: .leading, spacing: 16) {
                    StockHeaderView(displayQuote: quote)
                    PriceSummaryCard(displayQuote: quote)

                    SectionCardView(title: "概览") {
                        VStack(spacing: 10) {
                            QuoteRowView(title: "代码", value: quote.symbol)
                            QuoteRowView(title: "公司", value: quote.companyName)
                            QuoteRowView(title: "更新时间", value: quote.updatedAtText)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.isLoading {
                ProgressView("正在载入行情...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("行情不可用")
                        .font(.headline)
                    Text("当前版本只接入 mock data。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor.windowBackgroundColor),
                    Color(nsColor: NSColor.controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview {
    MenuBarContentView(viewModel: PreviewMocks.detailViewModel)
        .frame(width: 320)
}
