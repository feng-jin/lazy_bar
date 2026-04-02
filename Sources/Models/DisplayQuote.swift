/// 面向展示层的模型，负责把原始行情格式化成视图可直接使用的内容。
import Foundation

struct DisplayQuote: Equatable {
    struct QuoteColumns: Equatable {
        let nameText: String?
        let symbolText: String?
        let priceText: String?
        let changeText: String?
    }

    let symbol: String
    let companyName: String
    let priceText: String
    let changeAmountText: String
    let changePercentText: String
    let updatedAtText: String

    func columns(settings: MenuBarDisplaySettings) -> QuoteColumns {
        let showsAnyField =
            settings.showsCompanyName ||
            settings.showsSymbol ||
            settings.showsPrice ||
            settings.showsChangePercent

        return QuoteColumns(
            nameText: showsAnyField ? (settings.showsCompanyName ? companyName : nil) : companyName,
            symbolText: settings.showsSymbol ? symbol : nil,
            priceText: settings.showsPrice ? priceText : nil,
            changeText: settings.showsChangePercent ? changePercentText : nil
        )
    }

    var detailChangeText: String {
        "\(changeAmountText) (\(changePercentText))"
    }

    init(quote: StockQuote, preferredCompanyName: String? = nil) {
        symbol = quote.symbol
        companyName = preferredCompanyName ?? quote.companyName
        priceText = Self.priceFormatter(quote.lastPrice)
        changeAmountText = Self.signedNumberFormatter(quote.changeAmount)
        changePercentText = Self.signedPercentFormatter(quote.changePercent)
        updatedAtText = quote.updatedAt.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
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
