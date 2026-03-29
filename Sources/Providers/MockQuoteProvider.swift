/// UI-only 阶段使用的 mock 行情数据源，替代未来真实接口。
import Foundation

struct MockQuoteProvider: QuoteProviding {
    private struct SeedQuote: Sendable {
        let symbol: String
        let companyName: String
        let previousClose: Double
        let basePrice: Double
        let maxSwingRatio: Double
    }

    private static let seedQuotes: [SeedQuote] = [
        SeedQuote(
            symbol: "600519",
            companyName: "贵州茅台",
            previousClose: 1665.32,
            basePrice: 1688.88,
            maxSwingRatio: 0.006
        ),
        SeedQuote(
            symbol: "000858",
            companyName: "五粮液",
            previousClose: 140.29,
            basePrice: 138.42,
            maxSwingRatio: 0.007
        ),
        SeedQuote(
            symbol: "300750",
            companyName: "宁德时代",
            previousClose: 196.43,
            basePrice: 201.65,
            maxSwingRatio: 0.009
        ),
        SeedQuote(
            symbol: "601318",
            companyName: "中国平安",
            previousClose: 52.13,
            basePrice: 52.31,
            maxSwingRatio: 0.005
        )
    ]

    static var sampleQuotes: [StockQuote] {
        let timestamp = Date()

        return seedQuotes.map { quote in
            let changeAmount = (quote.basePrice - quote.previousClose).roundedToScale(2)
            let changePercent = quote.previousClose == 0 ? 0 : changeAmount / quote.previousClose

            return StockQuote(
                symbol: quote.symbol,
                companyName: quote.companyName,
                lastPrice: quote.basePrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                updatedAt: timestamp
            )
        }
    }

    func fetchQuotes() async throws -> [StockQuote] {
        let timestamp = Date()

        return Self.seedQuotes.map { quote in
            let swingRatio = Double.random(in: -quote.maxSwingRatio...quote.maxSwingRatio)
            let price = (quote.basePrice * (1 + swingRatio)).roundedToScale(2)
            let changeAmount = (price - quote.previousClose).roundedToScale(2)
            let changePercent = quote.previousClose == 0 ? 0 : changeAmount / quote.previousClose

            return StockQuote(
                symbol: quote.symbol,
                companyName: quote.companyName,
                lastPrice: price,
                changeAmount: changeAmount,
                changePercent: changePercent,
                updatedAt: timestamp
            )
        }
    }
}

private extension Double {
    func roundedToScale(_ scale: Int) -> Double {
        let multiplier = pow(10, Double(scale))
        return (self * multiplier).rounded() / multiplier
    }
}
