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
