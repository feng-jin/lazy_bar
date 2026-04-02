/// 通过新浪财经未公开快照接口拉取 A 股准实时行情。
import Foundation

struct SinaQuoteProvider: QuoteProviding {
    private let session: URLSession
    private let maxRetryCount = 2

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuotes(symbols: [String]) async throws -> [StockQuote] {
        let normalizedSymbols = symbols
            .map(Self.normalizedSymbol)
            .filter { !$0.isEmpty }

        guard !normalizedSymbols.isEmpty else {
            return []
        }

        let request = try makeRequest(symbols: normalizedSymbols)
        let (responseData, response) = try await data(for: request)
        try validate(response: response)

        let payload = try decodePayload(from: responseData)
        let quotesBySymbol = try parseQuotes(payload)

        return normalizedSymbols.compactMap { quotesBySymbol[$0] }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0

        while true {
            do {
                return try await session.data(for: request)
            } catch {
                guard shouldRetry(error: error), attempt < maxRetryCount else {
                    throw error
                }

                attempt += 1
                let delayNanoseconds = UInt64(attempt) * 500_000_000
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
    }

    private func makeRequest(symbols: [String]) throws -> URLRequest {
        let prefixedSymbols = symbols.map(Self.marketPrefixedSymbol).joined(separator: ",")
        let components = URLComponents(string: "https://hq.sinajs.cn/list=\(prefixedSymbols)")

        guard let url = components?.url else {
            throw SinaQuoteProviderError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("https://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SinaQuoteProviderError.invalidResponse
        }
    }

    private func decodePayload(from data: Data) throws -> String {
        if let payload = String(data: data, encoding: Self.gb18030Encoding) {
            return payload
        }

        if let payload = String(data: data, encoding: .utf8) {
            return payload
        }

        throw SinaQuoteProviderError.invalidEncoding
    }

    private func parseQuotes(_ payload: String) throws -> [String: StockQuote] {
        var quotesBySymbol: [String: StockQuote] = [:]

        for rawLine in payload.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty else { continue }
            guard let quote = try parseQuote(line) else { continue }

            quotesBySymbol[quote.symbol] = quote
        }

        return quotesBySymbol
    }

    private func parseQuote(_ line: String) throws -> StockQuote? {
        let prefix = "var hq_str_"
        guard line.hasPrefix(prefix) else {
            return nil
        }

        guard
            let equalsIndex = line.firstIndex(of: "="),
            let firstQuoteIndex = line[equalsIndex...].firstIndex(of: "\""),
            let lastQuoteIndex = line.lastIndex(of: "\""),
            firstQuoteIndex < lastQuoteIndex
        else {
            throw SinaQuoteProviderError.invalidPayload
        }

        let marketSymbol = String(line[line.index(line.startIndex, offsetBy: prefix.count)..<equalsIndex])
        let symbol = Self.plainSymbol(from: marketSymbol)
        let bodyStart = line.index(after: firstQuoteIndex)
        let body = String(line[bodyStart..<lastQuoteIndex])
        let fields = body.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        guard fields.count >= 32 else {
            throw SinaQuoteProviderError.invalidPayload
        }

        let companyName = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !companyName.isEmpty else {
            return nil
        }

        guard
            let previousClose = Double(fields[2]),
            let lastPrice = Double(fields[3])
        else {
            throw SinaQuoteProviderError.invalidPayload
        }

        let updatedAt = Self.makeUpdatedAt(date: fields[30], time: fields[31]) ?? Date()
        let changeAmount = lastPrice - previousClose
        let changePercent = previousClose == 0 ? 0 : changeAmount / previousClose

        return StockQuote(
            symbol: symbol,
            companyName: companyName,
            lastPrice: lastPrice,
            changeAmount: changeAmount,
            changePercent: changePercent,
            updatedAt: updatedAt
        )
    }

    private func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private static func normalizedSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func marketPrefixedSymbol(_ symbol: String) -> String {
        "\(marketPrefix(for: symbol))\(symbol)"
    }

    private static func plainSymbol(from marketSymbol: String) -> String {
        if marketSymbol.hasPrefix("sh") || marketSymbol.hasPrefix("sz") {
            return String(marketSymbol.dropFirst(2))
        }

        return marketSymbol
    }

    private static func marketPrefix(for symbol: String) -> String {
        guard let firstCharacter = symbol.first else {
            return "sz"
        }

        switch firstCharacter {
        case "5", "6", "9":
            return "sh"
        default:
            return "sz"
        }
    }

    private static func makeUpdatedAt(date: String, time: String) -> Date? {
        let normalizedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTime = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDate.isEmpty, !normalizedTime.isEmpty else { return nil }

        return quoteDateFormatter.date(from: "\(normalizedDate) \(normalizedTime)")
    }

    private static let quoteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let gb18030Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}

private enum SinaQuoteProviderError: Error {
    case invalidRequest
    case invalidResponse
    case invalidEncoding
    case invalidPayload
}
