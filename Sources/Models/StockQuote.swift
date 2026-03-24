import Foundation

struct StockQuote: Equatable, Sendable {
    let symbol: String
    let companyName: String
    let lastPrice: Double
    let changeAmount: Double
    let changePercent: Double
    let updatedAt: Date

    var change: QuoteChange {
        QuoteChange(value: changeAmount)
    }
}
