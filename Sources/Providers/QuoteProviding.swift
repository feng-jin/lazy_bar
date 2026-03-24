import Foundation

protocol QuoteProviding: Sendable {
    func fetchQuote() async throws -> StockQuote
}
