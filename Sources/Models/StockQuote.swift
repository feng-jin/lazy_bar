/// Provider 层返回的原始股票行情领域模型。
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
