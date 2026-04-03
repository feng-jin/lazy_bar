import AppKit
import SwiftUI

struct QuoteColumnLayout: Equatable {
    let itemWidth: CGFloat
    let contentWidth: CGFloat
    let symbolColumnWidth: CGFloat
    let priceColumnWidth: CGFloat
    let changeColumnWidth: CGFloat
    let columnSpacing: CGFloat
    let valueColumnLeadingSpacing: CGFloat

    var symbolWidthWithSpacing: CGFloat {
        guard symbolColumnWidth > 0 else { return 0 }
        return columnSpacing + symbolColumnWidth
    }

    var priceWidthWithSpacing: CGFloat {
        guard priceColumnWidth > 0 else { return 0 }
        return valueColumnLeadingSpacing + priceColumnWidth
    }

    var changeWidthWithSpacing: CGFloat {
        guard changeColumnWidth > 0 else { return 0 }
        return columnSpacing + changeColumnWidth
    }

    var nameColumnWidth: CGFloat {
        let occupiedWidth =
            symbolWidthWithSpacing +
            priceWidthWithSpacing +
            changeWidthWithSpacing
        return max(0, contentWidth - occupiedWidth)
    }
}

struct QuoteColumnLayoutCalculator {
    private enum Metrics {
        static let horizontalInset = MenuBarStyle.Metrics.statusItemHorizontalInset
        static let contentHorizontalInset: CGFloat = horizontalInset * 2
        static let columnSpacing = MenuBarStyle.Metrics.columnSpacing
        static let valueColumnLeadingSpacing = MenuBarStyle.Metrics.valueColumnLeadingSpacing
        static let statusFont = MenuBarStyle.statusTextNSFont(size: MenuBarStyle.Metrics.primaryFontSize)
        static let barTitleFont = MenuBarStyle.primaryTextNSFont(size: MenuBarStyle.Metrics.primaryFontSize)
        static let barSecondaryFont = MenuBarStyle.identitySecondaryTextNSFont(size: MenuBarStyle.Metrics.secondaryFontSize)
        static let barValueFont = MenuBarStyle.valueTextNSFont(size: MenuBarStyle.Metrics.secondaryFontSize)
        static let listPrimaryFont = MenuBarStyle.primaryTextNSFont(size: MenuBarStyle.Metrics.popoverPrimaryFontSize)
        static let listSecondaryFont = MenuBarStyle.identitySecondaryTextNSFont(size: MenuBarStyle.Metrics.secondaryFontSize)
        static let listValueFont = MenuBarStyle.valueTextNSFont(size: MenuBarStyle.Metrics.popoverValueFontSize)
    }

    static func layout(
        columns: [DisplayQuote.QuoteColumns],
        statusText: String
    ) -> QuoteColumnLayout {
        let nameColumnWidth = columns
            .map {
                max(
                    optionalTextWidth($0.nameText, font: Metrics.barTitleFont),
                    optionalTextWidth($0.nameText, font: Metrics.listPrimaryFont)
                )
            }
            .max() ?? 0

        let symbolColumnWidth = max(
            columns
                .compactMap(\.symbolText)
                .map { textWidth($0, font: Metrics.barSecondaryFont) }
                .max() ?? 0,
            columns
                .compactMap(\.symbolText)
                .map { textWidth($0, font: Metrics.listSecondaryFont) }
                .max() ?? 0
        )

        let priceColumnWidth = max(
            columns
                .compactMap(\.priceText)
                .map { textWidth($0, font: Metrics.barValueFont) }
                .max() ?? 0,
            columns
                .compactMap(\.priceText)
                .map { textWidth($0, font: Metrics.listValueFont) }
                .max() ?? 0
        )

        let changeColumnWidth = max(
            columns
                .compactMap(\.changeText)
                .map { textWidth($0, font: Metrics.barValueFont) }
                .max() ?? 0,
            columns
                .compactMap(\.changeText)
                .map { textWidth($0, font: Metrics.listValueFont) }
                .max() ?? 0
        )

        var contentWidth = ceil(nameColumnWidth)

        if symbolColumnWidth > 0 {
            contentWidth += Metrics.columnSpacing + ceil(symbolColumnWidth)
        }

        if priceColumnWidth > 0 {
            contentWidth += Metrics.valueColumnLeadingSpacing + ceil(priceColumnWidth)
        }

        if changeColumnWidth > 0 {
            contentWidth += Metrics.columnSpacing + ceil(changeColumnWidth)
        }

        if contentWidth == 0 {
            contentWidth = ceil(textWidth(statusText, font: Metrics.statusFont))
        }

        let itemWidth = contentWidth + Metrics.contentHorizontalInset

        return QuoteColumnLayout(
            itemWidth: itemWidth,
            contentWidth: itemWidth - Metrics.contentHorizontalInset,
            symbolColumnWidth: ceil(symbolColumnWidth),
            priceColumnWidth: ceil(priceColumnWidth),
            changeColumnWidth: ceil(changeColumnWidth),
            columnSpacing: Metrics.columnSpacing,
            valueColumnLeadingSpacing: Metrics.valueColumnLeadingSpacing
        )
    }

    private static func optionalTextWidth(_ text: String?, font: NSFont) -> CGFloat {
        guard let text else { return 0 }
        return textWidth(text, font: font)
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }
}
