/// 定义菜单栏可配置的展示字段。
import Foundation

struct WatchlistEntry: Equatable, Codable, Sendable {
    var symbol: String
    var companyName: String
}

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    enum Field: String, CaseIterable, Identifiable, Sendable {
        case companyName
        case symbol
        case price
        case changePercent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .companyName:
                return "股票简称"
            case .symbol:
                return "股票代码"
            case .price:
                return "当前股价"
            case .changePercent:
                return "涨跌幅"
            }
        }

        var description: String {
            switch self {
            case .companyName:
                return "优先显示你自定义维护的股票名称，适合快速扫一眼识别标的。"
            case .symbol:
                return "展示 6 位代码，适合区分同名或相近简称的股票。"
            case .price:
                return "显示最新价格，是菜单栏和主面板里的核心数值字段。"
            case .changePercent:
                return "显示相对昨收的百分比变化，便于快速判断强弱。"
            }
        }
    }

    var watchlist: [WatchlistEntry]
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true

    static let `default` = MenuBarDisplaySettings(watchlist: [])

    func showsField(_ field: Field) -> Bool {
        switch field {
        case .companyName:
            return showsCompanyName
        case .symbol:
            return showsSymbol
        case .price:
            return showsPrice
        case .changePercent:
            return showsChangePercent
        }
    }
}
