import Foundation

protocol StockSearchProviding: Sendable {
    func searchStocks(query: String) async throws -> [StockSearchResult]
}
