/// 详情面板头部，展示公司名称、股票代码和更新时间。
import SwiftUI

struct StockHeaderView: View {
    let displayQuote: DisplayQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayQuote.companyName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            HStack(spacing: 8) {
                Text(displayQuote.symbol)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("更新于 \(displayQuote.updatedAtText)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    StockHeaderView(displayQuote: PreviewMocks.displayQuote)
        .padding()
}
