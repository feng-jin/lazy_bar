/// 定义菜单栏可配置的展示字段。
import Foundation

struct WatchlistEntry: Equatable, Codable, Sendable {
    var symbol: String
    var companyName: String

    var sanitized: WatchlistEntry {
        let normalizedSymbol = Self.normalizedSymbol(from: symbol)
        let trimmedName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)

        return WatchlistEntry(
            symbol: normalizedSymbol,
            companyName: trimmedName.isEmpty ? normalizedSymbol : trimmedName
        )
    }

    static func normalizedSymbol(from input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }
}

struct MenuBarDisplaySettings: Equatable, Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case watchlist
        case displayMode
        case fixedSymbol
        case showsSymbol
        case showsCompanyName
        case showsPrice
        case showsChangePercent
    }

    enum DisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
        case scrolling
        case fixed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scrolling:
                return "滚动模式"
            case .fixed:
                return "固定模式"
            }
        }

        var description: String {
            switch self {
            case .scrolling:
                return "菜单栏按当前监控列表逐条循环播放股票摘要。"
            case .fixed:
                return "菜单栏固定显示一只股票，不再自动轮播；固定对象可在左键列表里点选。"
            }
        }
    }

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
    var displayMode: DisplayMode = .scrolling
    var fixedSymbol: String?
    var showsSymbol = false
    var showsCompanyName = true
    var showsPrice = true
    var showsChangePercent = true

    static let `default` = MenuBarDisplaySettings(watchlist: [])

    init(
        watchlist: [WatchlistEntry],
        displayMode: DisplayMode = .scrolling,
        fixedSymbol: String? = nil,
        showsSymbol: Bool = false,
        showsCompanyName: Bool = true,
        showsPrice: Bool = true,
        showsChangePercent: Bool = true
    ) {
        self.watchlist = watchlist
        self.displayMode = displayMode
        self.fixedSymbol = fixedSymbol
        self.showsSymbol = showsSymbol
        self.showsCompanyName = showsCompanyName
        self.showsPrice = showsPrice
        self.showsChangePercent = showsChangePercent
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchlist = try container.decodeIfPresent([WatchlistEntry].self, forKey: .watchlist) ?? []
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .scrolling
        fixedSymbol = try container.decodeIfPresent(String.self, forKey: .fixedSymbol)
        showsSymbol = try container.decodeIfPresent(Bool.self, forKey: .showsSymbol) ?? false
        showsCompanyName = try container.decodeIfPresent(Bool.self, forKey: .showsCompanyName) ?? true
        showsPrice = try container.decodeIfPresent(Bool.self, forKey: .showsPrice) ?? true
        showsChangePercent = try container.decodeIfPresent(Bool.self, forKey: .showsChangePercent) ?? true
    }

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

    mutating func setField(_ field: Field, isVisible: Bool) {
        switch field {
        case .companyName:
            showsCompanyName = isVisible
        case .symbol:
            showsSymbol = isVisible
        case .price:
            showsPrice = isVisible
        case .changePercent:
            showsChangePercent = isVisible
        }
    }

    var hasAtLeastOneVisibleField: Bool {
        showsSymbol || showsCompanyName || showsPrice || showsChangePercent
    }

    func containsWatchlistSymbol(_ symbol: String, excludingIndex: Int? = nil) -> Bool {
        let normalizedSymbol = WatchlistEntry.normalizedSymbol(from: symbol)

        return watchlist.enumerated().contains { index, entry in
            guard entry.sanitized.symbol == normalizedSymbol else { return false }
            return index != excludingIndex
        }
    }

    func validationMessage() -> String? {
        guard hasAtLeastOneVisibleField else {
            return "请至少保留一个展示字段，否则菜单栏和主面板都没有可显示内容。"
        }

        var seenSymbols = Set<String>()

        for entry in watchlist.map(\.sanitized) {
            guard !entry.symbol.isEmpty else {
                return "监控列表里有空代码，请补全为 6 位股票代码。"
            }

            guard entry.symbol.count == 6 else {
                return "监控列表里的股票代码必须是 6 位数字。"
            }

            guard seenSymbols.insert(entry.symbol).inserted else {
                return "监控列表里存在重复代码，请删除或修改后再保存。"
            }
        }

        return nil
    }

    func resolvedFixedSymbol(in symbols: [String]) -> String? {
        let symbolSet = Set(symbols)

        if let fixedSymbol, symbolSet.contains(fixedSymbol) {
            return fixedSymbol
        }

        return symbols.first
    }

    func sanitized() -> MenuBarDisplaySettings {
        let sanitizedWatchlist = watchlist.map(\.sanitized)
        let sanitizedSymbols = Set(sanitizedWatchlist.map(\.symbol))
        let sanitizedFixedSymbol = fixedSymbol.flatMap { symbol in
            let normalized = WatchlistEntry.normalizedSymbol(from: symbol)
            return sanitizedSymbols.contains(normalized) ? normalized : nil
        }

        return MenuBarDisplaySettings(
            watchlist: sanitizedWatchlist,
            displayMode: displayMode,
            fixedSymbol: sanitizedFixedSymbol,
            showsSymbol: showsSymbol,
            showsCompanyName: showsCompanyName,
            showsPrice: showsPrice,
            showsChangePercent: showsChangePercent
        )
    }
}
