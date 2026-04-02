/// 面向展示层的模型，负责把原始行情格式化成视图可直接使用的内容。
import Foundation

struct DisplayQuote: Equatable {
    struct MenuBarSegment: Equatable {
        let text: String
    }

    struct MenuListColumns: Equatable {
        let nameText: String?
        let symbolText: String?
        let priceText: String?
        let changeText: String?
    }

    struct MenuBarColumns: Equatable {
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

    var menuBarNameText: String {
        companyName
    }

    var menuBarPriceText: String {
        priceText
    }

    var menuBarSymbolText: String {
        symbol
    }

    var menuListTitleText: String {
        companyName
    }

    var menuListDetailText: String {
        priceText
    }

    var menuListTrailingText: String {
        changePercentText
    }

    var menuListSummaryText: String {
        "\(companyName)  \(priceText)  \(changePercentText)"
    }

    func menuListColumns(settings: MenuBarDisplaySettings) -> MenuListColumns {
        return MenuListColumns(
            nameText: settings.showsCompanyName ? companyName : nil,
            symbolText: settings.showsSymbol ? symbol : nil,
            priceText: settings.showsPrice ? priceText : nil,
            changeText: settings.showsChangePercent ? changePercentText : nil
        )
    }

    func menuBarColumns(settings: MenuBarDisplaySettings) -> MenuBarColumns {
        let showsAnyField =
            settings.showsCompanyName ||
            settings.showsSymbol ||
            settings.showsPrice ||
            settings.showsChangePercent

        return MenuBarColumns(
            nameText: showsAnyField ? (settings.showsCompanyName ? companyName : nil) : companyName,
            symbolText: settings.showsSymbol ? symbol : nil,
            priceText: settings.showsPrice ? priceText : nil,
            changeText: settings.showsChangePercent ? changePercentText : nil
        )
    }

    func menuBarSummaryText(settings: MenuBarDisplaySettings) -> String {
        let segments = menuBarSegments(settings: settings).map(\.text)
        if segments.isEmpty {
            return menuBarNameText
        }
        return segments.joined(separator: " ")
    }

    func menuBarSegments(settings: MenuBarDisplaySettings) -> [MenuBarSegment] {
        var segments: [MenuBarSegment] = []

        if settings.showsSymbol {
            segments.append(MenuBarSegment(text: menuBarSymbolText))
        }

        if settings.showsCompanyName {
            segments.append(MenuBarSegment(text: menuBarNameText))
        }

        if settings.showsPrice {
            segments.append(MenuBarSegment(text: menuBarPriceText))
        }

        if settings.showsChangePercent {
            segments.append(MenuBarSegment(text: changePercentText))
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
