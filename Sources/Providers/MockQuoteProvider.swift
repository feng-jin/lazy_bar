/// UI-only 阶段使用的 mock 行情数据源，替代未来真实接口。
import Foundation

struct MockQuoteProvider: QuoteProviding {
    static let sampleQuote = StockQuote(
        symbol: "600519",
        companyName: "贵州茅台",
        lastPrice: 1688.88,
        changeAmount: 23.56,
        changePercent: 0.0141,
        updatedAt: Date()
    )

    func fetchQuote() async throws -> StockQuote {
        Self.sampleQuote
    }
}
