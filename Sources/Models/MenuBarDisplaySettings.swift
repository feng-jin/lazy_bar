/// 定义菜单栏可配置的展示字段。
import Foundation

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true

    static let `default` = MenuBarDisplaySettings()
}
