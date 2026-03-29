/// 描述行情是上涨、下跌还是持平，并提供这三种状态共用的 UI 样式。
import AppKit
import SwiftUI

enum QuoteChange: Equatable {
    case up
    case down
    case flat

    init(value: Double) {
        if value > 0 {
            self = .up
        } else if value < 0 {
            self = .down
        } else {
            self = .flat
        }
    }

    var tintColor: Color {
        switch self {
        case .up:
            .red
        case .down:
            .green
        case .flat:
            .secondary
        }
    }

    var appKitTintColor: NSColor {
        switch self {
        case .up:
            .systemRed
        case .down:
            .systemGreen
        case .flat:
            .secondaryLabelColor
        }
    }

    var symbolName: String {
        switch self {
        case .up:
            "arrow.up"
        case .down:
            "arrow.down"
        case .flat:
            "minus"
        }
    }
}
