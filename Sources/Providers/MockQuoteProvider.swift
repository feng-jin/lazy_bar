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
