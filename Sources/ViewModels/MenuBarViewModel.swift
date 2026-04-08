/// 管理菜单栏标签所需的紧凑行情状态。
import Combine
import Foundation
import os

@MainActor
final class MenuBarViewModel: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "MenuBarViewModel"
    )

    @Published private(set) var viewState: MenuBarContentState
    @Published private(set) var renderState: MenuBarRenderState

    private let settingsStore: any MenuBarSettingsStoring
    private let quoteSession: QuoteSession
    private var lastObservedSymbols: [String]
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: any MenuBarSettingsStoring,
        quoteSession: QuoteSession
    ) {
        let initialViewState: MenuBarContentState = settingsStore.settings.watchlist.isEmpty ? .emptyWatchlist : .loading

        self.settingsStore = settingsStore
        self.quoteSession = quoteSession
        lastObservedSymbols = settingsStore.settings.watchlist.map(\.symbol)
        viewState = initialViewState
        renderState = Self.makeRenderState(
            contentState: initialViewState,
            settings: settingsStore.settings
        )

        $viewState
            .combineLatest(settingsStore.settingsPublisher)
            .map { viewState, settings in
                Self.makeRenderState(
                    contentState: viewState,
                    settings: settings
                )
            }
            .assign(to: &$renderState)

        $viewState
            .sink { viewState in
                Self.logger.debug("viewState -> \(Self.debugDescription(for: viewState), privacy: .public)")
            }
            .store(in: &cancellables)

        $renderState
            .sink { renderState in
                Self.logger.debug(
                    """
                    renderState -> quotes=\(renderState.displayQuotes.count, privacy: .public) \
                    status=\(renderState.statusText, privacy: .public) \
                    signature=\(Self.renderStateSignature(for: renderState), privacy: .public)
                    """
                )
            }
            .store(in: &cancellables)

        settingsStore.settingsPublisher
            .dropFirst()
            .sink { [weak self] settings in
                guard let self else { return }
                Task { await self.handleSettingsChange(settings) }
            }
            .store(in: &cancellables)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            Self.logger.debug("loadIfNeeded skipped because data is already loaded")
            return
        }
        Self.logger.debug("loadIfNeeded triggered initial load")
        await performLoad(showLoadingState: true)
    }

    func load() async {
        Self.logger.debug("load triggered manual reload")
        await performLoad(showLoadingState: true)
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        viewState = .loaded(quotes)
        hasLoaded = true
    }

    func pinDisplayedSymbol(_ symbol: String) {
        let normalizedSymbol = WatchlistEntry.normalizedSymbol(from: symbol)
        guard settingsStore.settings.watchlist.contains(where: { $0.symbol == normalizedSymbol }) else {
            Self.logger.error("pinDisplayedSymbol ignored missing symbol=\(normalizedSymbol, privacy: .public)")
            return
        }

        guard settingsStore.settings.fixedSymbol != normalizedSymbol else {
            Self.logger.debug("pinDisplayedSymbol ignored unchanged symbol=\(normalizedSymbol, privacy: .public)")
            return
        }

        var updatedSettings = settingsStore.settings
        updatedSettings.fixedSymbol = normalizedSymbol
        Self.logger.debug("pinDisplayedSymbol symbol=\(normalizedSymbol, privacy: .public)")
        settingsStore.update(updatedSettings)
    }

    private func performLoad(showLoadingState: Bool) async {
        let symbols = currentSymbols
        Self.logger.debug(
            """
            performLoad start showLoadingState=\(showLoadingState, privacy: .public) \
            symbols=\(Self.symbolsDescription(symbols), privacy: .public)
            """
        )

        guard !symbols.isEmpty else {
            Self.logger.debug("performLoad found empty watchlist")
            applyEmptyWatchlistState()
            return
        }

        if showLoadingState {
            viewState = .loading
        }

        let outcome = await quoteSession.fetchLatest(symbols: symbols)
        handleFetchOutcome(
            outcome,
            fallbackToFailureWhenEmpty: true
        )
        Self.logger.debug(
            "performLoad finished outcome=\(Self.debugDescription(for: outcome), privacy: .public)"
        )

        if case .success = outcome {
            hasLoaded = true
        }
    }

    private func startRefreshIfNeeded() {
        quoteSession.startRefreshingIfNeeded(
            currentSymbols: { [weak self] in
                self?.currentSymbols ?? []
            },
            handleResult: { [weak self] outcome in
                guard let self else { return }
                self.handleFetchOutcome(
                    outcome,
                    fallbackToFailureWhenEmpty: self.currentDisplayQuotes.isEmpty
                )
            }
        )
    }

    private func handleSettingsChange(_ settings: MenuBarDisplaySettings) async {
        let symbols = settings.watchlist.map(\.symbol)
        let previousSymbols = lastObservedSymbols
        lastObservedSymbols = symbols
        Self.logger.debug(
            """
            handleSettingsChange previousSymbols=\(Self.symbolsDescription(previousSymbols), privacy: .public) \
            newSymbols=\(Self.symbolsDescription(symbols), privacy: .public) \
            fields=\(Self.visibleFieldsDescription(settings), privacy: .public)
            """
        )

        guard symbols != previousSymbols else {
            Self.logger.debug("handleSettingsChange only affected display configuration")
            reapplyCurrentSnapshotsIfPossible()
            return
        }

        Self.logger.debug("handleSettingsChange detected symbol list change")
        await handleSymbolListChange(symbols: symbols)
    }

    private func handleSymbolListChange(symbols: [String]) async {
        guard !symbols.isEmpty else {
            Self.logger.debug("handleSymbolListChange -> empty watchlist")
            applyEmptyWatchlistState()
            return
        }

        let retainedQuotes = quoteSession.updateTrackedSymbols(symbols)
        let retainedDisplayQuotes = displayQuotes(from: retainedQuotes)
        Self.logger.debug(
            """
            handleSymbolListChange retainedQuotes=\(retainedQuotes.count, privacy: .public) \
            retainedDisplayQuotes=\(retainedDisplayQuotes.count, privacy: .public)
            """
        )

        if !retainedDisplayQuotes.isEmpty {
            viewState = .loaded(retainedDisplayQuotes)
        }

        await performLoad(showLoadingState: retainedDisplayQuotes.isEmpty)
    }

    private func displayQuotes(from quotes: [StockQuote]) -> [DisplayQuote] {
        let watchlistNamesBySymbol = Dictionary(
            uniqueKeysWithValues: settingsStore.settings.watchlist.map { ($0.symbol, $0.companyName) }
        )
        let quotesBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        return settingsStore.settings.watchlist.compactMap { entry in
            guard let quote = quotesBySymbol[entry.symbol] else { return nil }
            let displayName = watchlistNamesBySymbol[quote.symbol] ?? quote.companyName
            return DisplayQuote(quote: quote, preferredCompanyName: displayName)
        }
    }

    private var currentSymbols: [String] {
        settingsStore.settings.watchlist.map(\.symbol)
    }

    private var currentDisplayQuotes: [DisplayQuote] {
        guard case let .loaded(quotes) = viewState else { return [] }
        return quotes
    }

    private func applyEmptyWatchlistState() {
        hasLoaded = true
        quoteSession.reset()
        viewState = .emptyWatchlist
        Self.logger.debug("applyEmptyWatchlistState")
    }

    private func reapplyCurrentSnapshotsIfPossible(fallbackToFailureWhenEmpty: Bool = false) {
        Self.logger.debug(
            """
            reapplyCurrentSnapshotsIfPossible symbols=\(Self.symbolsDescription(self.currentSymbols), privacy: .public) \
            fallbackToFailureWhenEmpty=\(fallbackToFailureWhenEmpty, privacy: .public)
            """
        )
        applyCachedQuotes(
            quoteSession.cachedQuotes(for: currentSymbols),
            fallbackToFailureWhenEmpty: fallbackToFailureWhenEmpty
        )
    }

    private func applyCachedQuotes(
        _ quotes: [StockQuote],
        fallbackToFailureWhenEmpty: Bool = false
    ) {
        let displayQuotes = displayQuotes(from: quotes)
        Self.logger.debug(
            """
            applyCachedQuotes raw=\(quotes.count, privacy: .public) \
            display=\(displayQuotes.count, privacy: .public) \
            fallbackToFailureWhenEmpty=\(fallbackToFailureWhenEmpty, privacy: .public)
            """
        )

        if !displayQuotes.isEmpty {
            viewState = .loaded(displayQuotes)
        } else if fallbackToFailureWhenEmpty {
            viewState = .failed
        }
    }

    private func handleFetchOutcome(
        _ outcome: QuoteSession.FetchOutcome,
        fallbackToFailureWhenEmpty: Bool
    ) {
        Self.logger.debug(
            """
            handleFetchOutcome outcome=\(Self.debugDescription(for: outcome), privacy: .public) \
            fallbackToFailureWhenEmpty=\(fallbackToFailureWhenEmpty, privacy: .public)
            """
        )
        switch outcome {
        case let .success(quotes):
            applyCachedQuotes(quotes, fallbackToFailureWhenEmpty: fallbackToFailureWhenEmpty)
            startRefreshIfNeeded()
        case let .failure(cachedQuotes):
            applyCachedQuotes(cachedQuotes, fallbackToFailureWhenEmpty: fallbackToFailureWhenEmpty)
        case .cancelled:
            Self.logger.debug("handleFetchOutcome ignored cancelled result")
            return
        }
    }

    private static func debugDescription(for viewState: MenuBarContentState) -> String {
        switch viewState {
        case .loading:
            return "loading"
        case .emptyWatchlist:
            return "emptyWatchlist"
        case .failed:
            return "failed"
        case let .loaded(quotes):
            let symbols = quotes.map(\.symbol).joined(separator: ",")
            return "loaded(count: \(quotes.count), symbols: [\(symbols)])"
        }
    }

    private static func makeRenderState(
        contentState: MenuBarContentState,
        settings: MenuBarDisplaySettings
    ) -> MenuBarRenderState {
        MenuBarRenderState(
            contentState: contentState,
            settings: settings
        )
    }

    private static func renderStateSignature(for renderState: MenuBarRenderState) -> String {
        if renderState.displayQuotes.isEmpty {
            return "status:\(renderState.statusText)"
        }

        return renderState.displayQuotes
            .map { quote in
                let columns = quote.columns(settings: renderState.settings)
                return [
                    quote.symbol,
                    columns.nameText ?? "",
                    columns.symbolText ?? "",
                    columns.priceText ?? "",
                    columns.changeText ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ",")
    }

    private static func symbolsDescription(_ symbols: [String]) -> String {
        if symbols.isEmpty {
            return "[]"
        }

        return "[\(symbols.joined(separator: ","))]"
    }

    private static func visibleFieldsDescription(_ settings: MenuBarDisplaySettings) -> String {
        MenuBarDisplaySettings.Field.allCases
            .filter { settings.showsField($0) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private static func debugDescription(for outcome: QuoteSession.FetchOutcome) -> String {
        switch outcome {
        case let .success(quotes):
            return "success(count: \(quotes.count), symbols: \(symbolsDescription(quotes.map(\.symbol))))"
        case let .failure(cachedQuotes):
            return "failure(cached: \(cachedQuotes.count), symbols: \(symbolsDescription(cachedQuotes.map(\.symbol))))"
        case .cancelled:
            return "cancelled"
        }
    }
}
