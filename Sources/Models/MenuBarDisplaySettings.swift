/// 定义菜单栏可配置的展示字段与颜色策略。
import Foundation

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true
    var usesChangeColor = true

    static let `default` = MenuBarDisplaySettings()
}
