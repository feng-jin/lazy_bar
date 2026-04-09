import Foundation

struct StockSearchResult: Equatable, Identifiable, Sendable {
    let symbol: String
    let companyName: String
    let marketName: String?

    var id: String { symbol }

    var marketSummary: String {
        guard let marketName, !marketName.isEmpty else {
            return "A 股"
        }

        return marketName
    }
}
