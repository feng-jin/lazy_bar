import SwiftUI

struct PriceSummaryCard: View {
    let displayQuote: DisplayQuote

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(displayQuote.priceText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                HStack(spacing: 10) {
                    ChangeBadgeView(
                        text: displayQuote.changePercentText,
                        change: displayQuote.change
                    )

                    Text(displayQuote.changeAmountText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(displayQuote.change.tintColor)
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
