import Foundation
import os

struct SinaStockSearchProvider: StockSearchProviding {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "SinaStockSearchProvider"
    )

    private let session: URLSession
    private static let gb18030Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchStocks(query: String) async throws -> [StockSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedQuery.isEmpty else {
            Self.logger.debug("searchStocks skipped empty query")
            return []
        }

        let request = try makeRequest(query: normalizedQuery)
        Self.logger.debug(
            """
            searchStocks start query=\(normalizedQuery, privacy: .public) \
            url=\(request.url?.absoluteString ?? "", privacy: .public)
            """
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let payload = try decodePayload(from: data)
        let results = parseSearchResults(payload)

        Self.logger.debug(
            """
            searchStocks success query=\(normalizedQuery, privacy: .public) \
            bytes=\(data.count, privacy: .public) \
            results=\(results.count, privacy: .public)
            """
        )

        return Array(results.prefix(8))
    }

    private func makeRequest(query: String) throws -> URLRequest {
        guard var components = URLComponents(string: "https://suggest3.sinajs.cn/suggest/") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "type", value: "11,12,13,14,15"),
            URLQueryItem(name: "key", value: query),
            URLQueryItem(name: "name", value: "suggestdata")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.debug("validate skipped non-http response")
            return
        }

        Self.logger.debug("validate statusCode=\(httpResponse.statusCode, privacy: .public)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error(
                "validate failed statusCode=\(httpResponse.statusCode, privacy: .public)"
            )
            throw URLError(.badServerResponse)
        }
    }

    private func decodePayload(from data: Data) throws -> String {
        if let payload = String(data: data, encoding: Self.gb18030Encoding) {
            Self.logger.debug("decodePayload encoding=gb18030 characters=\(payload.count, privacy: .public)")
            return payload
        }

        if let payload = String(data: data, encoding: .utf8) {
            Self.logger.debug("decodePayload encoding=utf8 characters=\(payload.count, privacy: .public)")
            return payload
        }

        Self.logger.error("decodePayload failed bytes=\(data.count, privacy: .public)")
        throw URLError(.cannotDecodeContentData)
    }

    private func parseSearchResults(_ payload: String) -> [StockSearchResult] {
        guard
            let start = payload.range(of: "\"")?.upperBound,
            let end = payload.range(of: "\";", options: .backwards)?.lowerBound,
            start <= end
        else {
            Self.logger.error(
                "parseSearchResults failed to locate quoted payload prefix=\(String(payload.prefix(120)), privacy: .public)"
            )
            return []
        }

        let body = String(payload[start..<end])
        let rawItems = body
            .split(separator: ";", omittingEmptySubsequences: true)
            .map(String.init)

        var seenSymbols = Set<String>()
        var results: [StockSearchResult] = []
        var invalidFieldCount = 0
        var unsupportedCount = 0
        var duplicateCount = 0

        for rawItem in rawItems {
            let fields = rawItem.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 5 else {
                invalidFieldCount += 1
                continue
            }

            let symbol = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let marketSymbol = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let companyName = fields[4].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !companyName.isEmpty else {
                invalidFieldCount += 1
                continue
            }

            guard Self.isSupportedAShareSymbol(symbol, marketSymbol: marketSymbol) else {
                unsupportedCount += 1
                continue
            }

            guard seenSymbols.insert(symbol).inserted else {
                duplicateCount += 1
                continue
            }

            results.append(
                StockSearchResult(
                    symbol: symbol,
                    companyName: companyName,
                    marketName: Self.marketName(for: marketSymbol)
                )
            )
        }

        Self.logger.debug(
            """
            parseSearchResults rawItems=\(rawItems.count, privacy: .public) \
            accepted=\(results.count, privacy: .public) \
            invalid=\(invalidFieldCount, privacy: .public) \
            unsupported=\(unsupportedCount, privacy: .public) \
            duplicates=\(duplicateCount, privacy: .public)
            """
        )

        if let firstResult = results.first {
            Self.logger.debug(
                """
                parseSearchResults firstResult symbol=\(firstResult.symbol, privacy: .public) \
                companyName=\(firstResult.companyName, privacy: .public) \
                market=\(firstResult.marketSummary, privacy: .public)
                """
            )
        }

        return Array(results.prefix(8))
    }

    private static func isSupportedAShareSymbol(_ symbol: String, marketSymbol: String) -> Bool {
        guard symbol.count == 6 else { return false }

        if marketSymbol.hasPrefix("sh") {
            return symbol.hasPrefix("600")
                || symbol.hasPrefix("601")
                || symbol.hasPrefix("603")
                || symbol.hasPrefix("605")
                || symbol.hasPrefix("688")
                || symbol.hasPrefix("689")
        }

        if marketSymbol.hasPrefix("sz") {
            return symbol.hasPrefix("000")
                || symbol.hasPrefix("001")
                || symbol.hasPrefix("002")
                || symbol.hasPrefix("003")
                || symbol.hasPrefix("300")
                || symbol.hasPrefix("301")
        }

        return false
    }

    private static func marketName(for marketSymbol: String) -> String {
        if marketSymbol.hasPrefix("sh") {
            return "沪A"
        }

        if marketSymbol.hasPrefix("sz") {
            return "深A"
        }

        return "A 股"
    }
}
