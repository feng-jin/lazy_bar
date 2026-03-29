/// UI 依赖的数据边界协议，用来隔离具体的数据来源实现。
import Foundation

protocol QuoteProviding: Sendable {
    func fetchQuotes() async throws -> [StockQuote]
}
