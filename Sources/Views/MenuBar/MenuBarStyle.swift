import SwiftUI

enum MenuBarStyle {
    enum Metrics {
        static let statusItemHorizontalInset: CGFloat = 10
        static let columnSpacing: CGFloat = 4
        static let contentHeight: CGFloat = 16
        static let primaryFontSize: CGFloat = 12
        static let secondaryFontSize: CGFloat = 12
        static let popoverPrimaryFontSize: CGFloat = 12
        static let popoverValueFontSize: CGFloat = 12
        static let verticalTextOffset: CGFloat = 1
        static let verticalHoldDuration: TimeInterval = 1.6
        static let verticalTransitionDuration: TimeInterval = 0.6
        static let panelOuterVerticalPadding: CGFloat = 4
        static let panelRowHorizontalPadding: CGFloat = 10
        static let panelRowVerticalPadding: CGFloat = 7
        static let panelCornerRadius: CGFloat = 14
        static let panelRowCornerRadius: CGFloat = 8
        static let panelBorderOpacity: CGFloat = 0.45
        static let panelDividerLeadingInset: CGFloat = 10
    }

    static let identityTextColor = Color.primary

    static func primaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func identitySecondaryTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func valueTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func statusTextFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}
