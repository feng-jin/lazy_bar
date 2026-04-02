/// 定义菜单栏可配置的展示字段。
import Foundation

struct WatchlistEntry: Equatable, Codable, Sendable {
    var symbol: String
    var companyName: String
}

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    var watchlist = [
        WatchlistEntry(symbol: "600519", companyName: "贵州茅台"),
        WatchlistEntry(symbol: "000858", companyName: "五粮液"),
        WatchlistEntry(symbol: "300750", companyName: "宁德时代"),
        WatchlistEntry(symbol: "601318", companyName: "中国平安")
    ]
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true

    static let `default` = MenuBarDisplaySettings()
}
