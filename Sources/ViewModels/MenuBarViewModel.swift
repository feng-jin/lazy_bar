/// 管理菜单栏标签所需的紧凑行情状态。
import AppKit
import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    struct ColumnLayout: Equatable {
        let itemWidth: CGFloat
        let contentWidth: CGFloat
        let symbolColumnWidth: CGFloat
        let priceColumnWidth: CGFloat
        let changeColumnWidth: CGFloat
        let columnSpacing: CGFloat

        var symbolWidthWithSpacing: CGFloat {
            guard symbolColumnWidth > 0 else { return 0 }
            return columnSpacing + symbolColumnWidth
        }

        var priceWidthWithSpacing: CGFloat {
            guard priceColumnWidth > 0 else { return 0 }
            return columnSpacing + priceColumnWidth
        }

        var changeWidthWithSpacing: CGFloat {
            guard changeColumnWidth > 0 else { return 0 }
            return columnSpacing + changeColumnWidth
        }
    }

    struct MenuBarTickerItem: Equatable, Identifiable {
        let id: String
        let columns: DisplayQuote.MenuBarColumns
    }

    private enum LayoutMetrics {
        static let horizontalInset = MenuBarStyle.Metrics.statusItemHorizontalInset
        static let contentHorizontalInset: CGFloat = horizontalInset * 2
        static let columnSpacing = MenuBarStyle.Metrics.columnSpacing
        static let barTitleFont = NSFont.systemFont(ofSize: MenuBarStyle.Metrics.primaryFontSize, weight: .semibold)
        static let barSecondaryFont = NSFont.systemFont(ofSize: MenuBarStyle.Metrics.secondaryFontSize, weight: .semibold)
        static let barValueFont = NSFont.monospacedDigitSystemFont(ofSize: MenuBarStyle.Metrics.secondaryFontSize, weight: .medium)
        static let listPrimaryFont = NSFont.systemFont(ofSize: MenuBarStyle.Metrics.popoverPrimaryFontSize, weight: .semibold)
        static let listSecondaryFont = NSFont.systemFont(ofSize: MenuBarStyle.Metrics.secondaryFontSize, weight: .semibold)
        static let listValueFont = NSFont.monospacedDigitSystemFont(ofSize: MenuBarStyle.Metrics.popoverValueFontSize, weight: .medium)
    }

    @Published private(set) var displayQuotes: [DisplayQuote] = []
    @Published private(set) var isLoading = false

    private let provider: any QuoteProviding
    private let settingsStore: MenuBarSettingsStore
    private var hasLoaded = false
    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalNanoseconds: UInt64 = 3_000_000_000
    private var cancellables = Set<AnyCancellable>()

    init(provider: any QuoteProviding, settingsStore: MenuBarSettingsStore) {
        self.provider = provider
        self.settingsStore = settingsStore

        settingsStore.$settings
            .map(\.watchlist)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.load() }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let quotes = try await provider.fetchQuotes(symbols: settingsStore.settings.watchlist.map(\.symbol))
            displayQuotes = displayQuotes(from: quotes)
            startRefreshIfNeeded()
            hasLoaded = true
        } catch {
            displayQuotes = []
        }
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        displayQuotes = quotes
        hasLoaded = true
    }

    func menuBarTickerItems(settings: MenuBarDisplaySettings) -> [MenuBarTickerItem] {
        guard !displayQuotes.isEmpty else { return [] }

        return displayQuotes
            .map {
                MenuBarTickerItem(
                    id: $0.symbol,
                    columns: $0.menuBarColumns(settings: settings)
                )
            }
    }

    func columnLayout(settings: MenuBarDisplaySettings) -> ColumnLayout {
        let nameColumnWidth = displayQuotes
            .map { quote in
                let listColumns = quote.menuListColumns(settings: settings)
                let barColumns = quote.menuBarColumns(settings: settings)

                return max(
                    Self.optionalTextWidth(barColumns.nameText, font: LayoutMetrics.barTitleFont),
                    Self.optionalTextWidth(listColumns.nameText, font: LayoutMetrics.listPrimaryFont)
                )
            }
            .max() ?? 0

        let symbolColumnWidth = settings.showsSymbol
            ? max(
                displayQuotes
                    .compactMap { $0.menuBarColumns(settings: settings).symbolText }
                    .map { Self.textWidth($0, font: LayoutMetrics.barSecondaryFont) }
                    .max() ?? 0,
                displayQuotes
                    .compactMap { $0.menuListColumns(settings: settings).symbolText }
                    .map { Self.textWidth($0, font: LayoutMetrics.listSecondaryFont) }
                    .max() ?? 0
            )
            : 0

        let priceColumnWidth = settings.showsPrice
            ? max(
                displayQuotes
                    .compactMap { $0.menuBarColumns(settings: settings).priceText }
                    .map { Self.textWidth($0, font: LayoutMetrics.barValueFont) }
                    .max() ?? 0,
                displayQuotes
                    .compactMap { $0.menuListColumns(settings: settings).priceText }
                    .map { Self.textWidth($0, font: LayoutMetrics.listValueFont) }
                    .max() ?? 0
            )
            : 0

        let changeColumnWidth = settings.showsChangePercent
            ? max(
                displayQuotes
                    .compactMap { $0.menuBarColumns(settings: settings).changeText }
                    .map { Self.textWidth($0, font: LayoutMetrics.barValueFont) }
                    .max() ?? 0,
                displayQuotes
                    .compactMap { $0.menuListColumns(settings: settings).changeText }
                    .map { Self.textWidth($0, font: LayoutMetrics.listValueFont) }
                    .max() ?? 0
            )
            : 0

        var contentWidth = ceil(nameColumnWidth)

        if symbolColumnWidth > 0 {
            contentWidth += LayoutMetrics.columnSpacing + ceil(symbolColumnWidth)
        }

        if priceColumnWidth > 0 {
            contentWidth += LayoutMetrics.columnSpacing + ceil(priceColumnWidth)
        }

        if changeColumnWidth > 0 {
            contentWidth += LayoutMetrics.columnSpacing + ceil(changeColumnWidth)
        }

        let itemWidth = contentWidth + LayoutMetrics.contentHorizontalInset

        return ColumnLayout(
            itemWidth: itemWidth,
            contentWidth: itemWidth - LayoutMetrics.contentHorizontalInset,
            symbolColumnWidth: ceil(symbolColumnWidth),
            priceColumnWidth: ceil(priceColumnWidth),
            changeColumnWidth: ceil(changeColumnWidth),
            columnSpacing: LayoutMetrics.columnSpacing
        )
    }

    private func startRefreshIfNeeded() {
        guard refreshTask == nil else { return }
        let intervalNanoseconds = refreshIntervalNanoseconds

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.refreshQuotes()
            }
        }
    }

    private func refreshQuotes() async {
        do {
            let quotes = try await provider.fetchQuotes(symbols: settingsStore.settings.watchlist.map(\.symbol))
            displayQuotes = displayQuotes(from: quotes)
        } catch {
            // Keep the last successful snapshot when periodic refresh fails.
        }
    }

    private func displayQuotes(from quotes: [StockQuote]) -> [DisplayQuote] {
        let watchlistNamesBySymbol = Dictionary(
            uniqueKeysWithValues: settingsStore.settings.watchlist.map { ($0.symbol, $0.companyName) }
        )

        return quotes.map { quote in
            let displayName = watchlistNamesBySymbol[quote.symbol] ?? quote.companyName
            return DisplayQuote(quote: quote, preferredCompanyName: displayName)
        }
    }

    private static func optionalTextWidth(_ text: String?, font: NSFont) -> CGFloat {
        guard let text else { return 0 }
        return textWidth(text, font: font)
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }
}
