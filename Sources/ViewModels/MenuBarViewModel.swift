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
    @Published private(set) var presentation: MenuBarPresentation

    private let settingsStore: any MenuBarSettingsStoring
    private let quoteSession: QuoteSession
    private var lastObservedSymbols: [String]
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: any MenuBarSettingsStoring,
        quoteSession: QuoteSession,
        presentationBuilder: MenuBarPresentationBuilder = MenuBarPresentationBuilder()
    ) {
        let initialViewState: MenuBarContentState = settingsStore.settings.watchlist.isEmpty ? .emptyWatchlist : .loading

        self.settingsStore = settingsStore
        self.quoteSession = quoteSession
        lastObservedSymbols = settingsStore.settings.watchlist.map(\.symbol)
        viewState = initialViewState
        presentation = presentationBuilder.build(
            contentState: initialViewState,
            settings: settingsStore.settings
        )

        $viewState
            .combineLatest(settingsStore.settingsPublisher)
            .map { [presentationBuilder] viewState, settings in
                presentationBuilder.build(
                    contentState: viewState,
                    settings: settings
                )
            }
            .assign(to: &$presentation)

        $viewState
            .sink { viewState in
                Self.logger.debug("viewState -> \(Self.debugDescription(for: viewState), privacy: .public)")
            }
            .store(in: &cancellables)

        $presentation
            .sink { presentation in
                Self.logger.debug(
                    """
                    presentation -> rows=\(presentation.rows.count, privacy: .public) \
                    status=\(presentation.statusText, privacy: .public) \
                    width=\(presentation.layout.itemWidth, privacy: .public) \
                    signature=\(Self.presentationSignature(for: presentation), privacy: .public)
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
        guard !hasLoaded else { return }
        await performLoad(showLoadingState: true)
    }

    func load() async {
        await performLoad(showLoadingState: true)
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        viewState = .loaded(quotes)
        hasLoaded = true
    }

    private func performLoad(showLoadingState: Bool) async {
        let symbols = currentSymbols

        guard !symbols.isEmpty else {
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

        guard symbols != previousSymbols else {
            reapplyCurrentSnapshotsIfPossible()
            return
        }

        await handleSymbolListChange(symbols: symbols)
    }

    private func handleSymbolListChange(symbols: [String]) async {
        guard !symbols.isEmpty else {
            applyEmptyWatchlistState()
            return
        }

        let retainedQuotes = quoteSession.updateTrackedSymbols(symbols)
        let retainedDisplayQuotes = displayQuotes(from: retainedQuotes)

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
    }

    private func reapplyCurrentSnapshotsIfPossible(fallbackToFailureWhenEmpty: Bool = false) {
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
        switch outcome {
        case let .success(quotes):
            applyCachedQuotes(quotes, fallbackToFailureWhenEmpty: fallbackToFailureWhenEmpty)
            startRefreshIfNeeded()
        case let .failure(cachedQuotes):
            applyCachedQuotes(cachedQuotes, fallbackToFailureWhenEmpty: fallbackToFailureWhenEmpty)
        case .cancelled:
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

    private static func presentationSignature(for presentation: MenuBarPresentation) -> String {
        presentation.debugSignature
    }
}
