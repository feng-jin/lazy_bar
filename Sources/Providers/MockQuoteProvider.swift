/// UI-only 阶段使用的 mock 行情数据源，替代未来真实接口。
import Foundation

struct MockQuoteProvider: QuoteProviding {
    static let sampleQuotes: [StockQuote] = [
        StockQuote(
            symbol: "600519",
            companyName: "贵州茅台",
            lastPrice: 1688.88,
            changeAmount: 23.56,
            changePercent: 0.0141,
            updatedAt: Date()
        ),
        StockQuote(
            symbol: "000858",
            companyName: "五粮液",
            lastPrice: 138.42,
            changeAmount: -1.87,
            changePercent: -0.0133,
            updatedAt: Date()
        ),
        StockQuote(
            symbol: "300750",
            companyName: "宁德时代",
            lastPrice: 201.65,
            changeAmount: 5.22,
            changePercent: 0.0266,
            updatedAt: Date()
        ),
        StockQuote(
            symbol: "601318",
            companyName: "中国平安",
            lastPrice: 52.31,
            changeAmount: 0.18,
            changePercent: 0.0035,
            updatedAt: Date()
        )
    ]

    func fetchQuotes() async throws -> [StockQuote] {
        Self.sampleQuotes
    }
}
