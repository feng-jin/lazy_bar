/// 管理菜单栏标签所需的紧凑行情状态。
import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    private enum FailureBehavior {
        case showFailure
        case keepLastSuccessfulSnapshot
    }

    enum ViewState: Equatable {
        case loading
        case emptyWatchlist
        case failed
        case loaded([DisplayQuote])
    }

    @Published private(set) var viewState: ViewState
    @Published private(set) var presentation: MenuBarPresentation

    private let provider: any QuoteProviding
    private let settingsStore: MenuBarSettingsStore
    private let refreshScheduler: QuoteRefreshScheduler
    private var hasLoaded = false
    private var quoteSnapshotsBySymbol: [String: StockQuote] = [:]
    private var activeFetchTask: Task<[StockQuote], Error>?
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        provider: any QuoteProviding,
        settingsStore: MenuBarSettingsStore,
        refreshScheduler: QuoteRefreshScheduler = QuoteRefreshScheduler()
    ) {
        let initialViewState: ViewState = settingsStore.settings.watchlist.isEmpty ? .emptyWatchlist : .loading

        self.provider = provider
        self.settingsStore = settingsStore
        self.refreshScheduler = refreshScheduler
        viewState = initialViewState
        presentation = MenuBarPresentation(
            viewState: initialViewState,
            settings: settingsStore.settings
        )

        $viewState
            .combineLatest(settingsStore.$settings)
            .map(MenuBarPresentation.init(viewState:settings:))
            .assign(to: &$presentation)

        settingsStore.$settings
            .map { settings in
                settings.watchlist.map(\.symbol)
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleSymbolListChange() }
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.reapplyCurrentSnapshotsIfPossible()
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await performLoad()
    }

    func load() async {
        await performLoad()
    }

    private func performLoad() async {
        let symbols = currentSymbols

        guard !symbols.isEmpty else {
            cancelActiveFetch()
            applyEmptyWatchlistState()
            return
        }

        viewState = .loading
        let quotes = await fetchQuotes(symbols: symbols, failureBehavior: .showFailure)
        applyLoadedQuotes(quotes)
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        viewState = .loaded(quotes)
        hasLoaded = true
    }

    private func startRefreshIfNeeded() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let intervalNanoseconds = self.refreshScheduler.delayNanoseconds()
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self.refreshQuotes()
            }
        }
    }

    private func stopRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func handleSymbolListChange() async {
        guard !currentSymbols.isEmpty else {
            cancelActiveFetch()
            applyEmptyWatchlistState()
            return
        }

        pruneSnapshots(excluding: Set(currentSymbols))
        await performLoad()
    }

    private func refreshQuotes() async {
        let symbols = currentSymbols
        guard !symbols.isEmpty else {
            applyEmptyWatchlistState()
            return
        }

        let quotes = await fetchQuotes(symbols: symbols, failureBehavior: .keepLastSuccessfulSnapshot)
        guard let quotes else { return }

        replaceSnapshots(with: quotes, for: symbols)
        reapplyCurrentSnapshotsIfPossible(fallbackToFailureWhenEmpty: currentDisplayQuotes.isEmpty)
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

    private func fetchQuotes(
        symbols: [String],
        failureBehavior: FailureBehavior
    ) async -> [StockQuote]? {
        activeFetchTask?.cancel()
        let task = Task { try await provider.fetchQuotes(symbols: symbols) }
        activeFetchTask = task

        do {
            let quotes = try await task.value
            guard activeFetchTask == task else { return nil }
            activeFetchTask = nil
            return quotes
        } catch is CancellationError {
            if activeFetchTask == task {
                activeFetchTask = nil
            }
            return nil
        } catch {
            guard activeFetchTask == task else { return nil }

            if failureBehavior == .showFailure || currentDisplayQuotes.isEmpty {
                viewState = .failed
            }
            activeFetchTask = nil
            return nil
        }
    }

    private func cancelActiveFetch() {
        activeFetchTask?.cancel()
        activeFetchTask = nil
    }

    private var currentDisplayQuotes: [DisplayQuote] {
        guard case let .loaded(quotes) = viewState else { return [] }
        return quotes
    }

    private func applyEmptyWatchlistState() {
        stopRefresh()
        hasLoaded = true
        quoteSnapshotsBySymbol = [:]
        viewState = .emptyWatchlist
    }

    private func applyLoadedQuotes(_ quotes: [StockQuote]?) {
        guard let quotes else { return }

        replaceSnapshots(with: quotes, for: currentSymbols)
        reapplyCurrentSnapshotsIfPossible(fallbackToFailureWhenEmpty: true)
        startRefreshIfNeeded()
        hasLoaded = true
    }

    private func reapplyCurrentSnapshotsIfPossible(fallbackToFailureWhenEmpty: Bool = false) {
        let quotes = currentSymbols.compactMap { quoteSnapshotsBySymbol[$0] }
        let displayQuotes = displayQuotes(from: quotes)

        if !displayQuotes.isEmpty {
            viewState = .loaded(displayQuotes)
        } else if fallbackToFailureWhenEmpty {
            viewState = .failed
        }
    }

    private func replaceSnapshots(with quotes: [StockQuote], for symbols: [String]) {
        for symbol in symbols {
            quoteSnapshotsBySymbol.removeValue(forKey: symbol)
        }

        for quote in quotes {
            quoteSnapshotsBySymbol[quote.symbol] = quote
        }
    }

    private func pruneSnapshots(excluding retainedSymbols: Set<String>) {
        quoteSnapshotsBySymbol = quoteSnapshotsBySymbol.filter { retainedSymbols.contains($0.key) }
    }
}
