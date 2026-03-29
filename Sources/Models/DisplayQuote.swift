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

    var menuBarPriceText: String {
        priceText
    }

    var menuBarSymbolText: String {
        symbol
    }

    func menuBarSummaryText(settings: MenuBarDisplaySettings) -> String {
        let segments = menuBarSegments(settings: settings)
        if segments.isEmpty {
            return menuBarNameText
        }
        return segments.joined(separator: " ")
    }

    func menuBarSegments(settings: MenuBarDisplaySettings) -> [String] {
        var segments: [String] = []

        if settings.showsSymbol {
            segments.append(menuBarSymbolText)
        }

        if settings.showsCompanyName {
            segments.append(menuBarNameText)
        }

        if settings.showsPrice {
            segments.append(menuBarPriceText)
        }

        if settings.showsChangePercent {
            segments.append(changePercentText)
        }

        return segments
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
