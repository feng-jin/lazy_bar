/// 面向展示层的模型，负责把原始行情格式化成视图可直接使用的内容。
import Foundation

struct DisplayQuote: Equatable {
    let symbol: String
    let companyName: String
    let priceText: String
    let changeAmountText: String
    let changePercentText: String
    let updatedAtText: String
    let change: QuoteChange

    var menuBarNameText: String {
        companyName
    }

    var menuBarText: String {
        "\(menuBarNameText) \(changePercentText)"
    }

    var detailChangeText: String {
        "\(changeAmountText) (\(changePercentText))"
    }

    init(quote: StockQuote) {
        symbol = quote.symbol
        companyName = quote.companyName
        priceText = Self.priceFormatter(quote.lastPrice)
        changeAmountText = Self.signedNumberFormatter(quote.changeAmount)
        changePercentText = Self.signedPercentFormatter(quote.changePercent)
        updatedAtText = quote.updatedAt.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
        change = quote.change
    }

    private static func priceFormatter(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(2))
                .grouping(.never)
        )
    }

    private static func signedNumberFormatter(_ value: Double) -> String {
        let formatted = abs(value).formatted(
            .number
                .precision(.fractionLength(2))
                .grouping(.never)
        )
        return signedPrefix(for: value) + formatted
    }

    private static func signedPercentFormatter(_ value: Double) -> String {
        let formatted = abs(value).formatted(
            .percent
                .precision(.fractionLength(2))
        )
        return signedPrefix(for: value) + formatted
    }

    private static func signedPrefix(for value: Double) -> String {
        if value > 0 {
            return "+"
        }
        if value < 0 {
            return "-"
        }
        return ""
    }
}
