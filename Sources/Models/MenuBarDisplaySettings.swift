/// 定义菜单栏可配置的展示字段。
import Foundation

struct WatchlistEntry: Equatable, Codable, Sendable {
    var symbol: String
    var companyName: String
}

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    var watchlist: [WatchlistEntry]
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true

    static let `default` = MenuBarDisplaySettings(watchlist: [])
}
