/// UI-only 阶段使用的 mock 行情数据源，替代未来真实接口。
import Foundation

struct MockQuoteProvider: QuoteProviding {
    func fetchQuote() async throws -> StockQuote {
        StockQuote(
            symbol: "AAPL",
            companyName: "Apple Inc.",
            lastPrice: 182.31,
            changeAmount: 2.24,
            changePercent: 0.0124,
            updatedAt: Date()
        )
    }
}
