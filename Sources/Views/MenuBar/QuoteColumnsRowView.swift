import SwiftUI

struct QuoteColumnsRowView: View {
    enum Typography {
        case menuBar
        case popover

        var primaryFont: Font {
            switch self {
            case .menuBar:
                return MenuBarStyle.primaryTextFont(size: MenuBarStyle.Metrics.primaryFontSize)
            case .popover:
                return MenuBarStyle.primaryTextFont(size: MenuBarStyle.Metrics.popoverPrimaryFontSize)
            }
        }

        var secondaryFont: Font {
            MenuBarStyle.identitySecondaryTextFont(size: MenuBarStyle.Metrics.secondaryFontSize)
        }

        var valueFont: Font {
            switch self {
            case .menuBar:
                return MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.secondaryFontSize)
            case .popover:
                return MenuBarStyle.valueTextFont(size: MenuBarStyle.Metrics.popoverValueFontSize)
            }
        }
    }

    let columns: DisplayQuote.QuoteColumns
    let layout: QuoteColumnLayout
    let typography: Typography
    var height: CGFloat? = nil
    var verticalOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            Text(columns.nameText ?? "")
                .font(typography.primaryFont)
                .foregroundStyle(MenuBarStyle.identityTextColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)
                .frame(width: layout.nameColumnWidth, alignment: .trailing)

            if let symbolText = columns.symbolText {
                Text(symbolText)
                    .font(typography.secondaryFont)
                    .foregroundStyle(MenuBarStyle.identityTextColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: layout.symbolColumnWidth, alignment: .trailing)
                    .padding(.leading, layout.columnSpacing)
            }

            if let priceText = columns.priceText {
                Text(priceText)
                    .font(typography.valueFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: layout.priceColumnWidth, alignment: .trailing)
                    .layoutPriority(1)
                    .padding(.leading, layout.valueColumnLeadingSpacing)
            }

            if let changeText = columns.changeText {
                Text(changeText)
                    .font(typography.valueFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: layout.changeColumnWidth, alignment: .trailing)
                    .layoutPriority(2)
                    .padding(.leading, layout.columnSpacing)
            }
        }
        .frame(
            width: layout.contentWidth,
            height: height,
            alignment: .trailing
        )
        .offset(y: verticalOffset)
    }
}
