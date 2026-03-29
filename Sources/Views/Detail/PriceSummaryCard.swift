/// 详情面板里的主价格卡片，展示最新价、涨跌额和涨跌幅。
import SwiftUI

struct PriceSummaryCard: View {
    let displayQuote: DisplayQuote

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(displayQuote.priceText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                HStack(spacing: 10) {
                    Text(displayQuote.changePercentText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())

                    Text(displayQuote.changeAmountText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                Text("当日涨跌 \(displayQuote.detailChangeText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    PriceSummaryCard(displayQuote: PreviewMocks.displayQuote)
        .padding()
        .frame(width: 320)
}
