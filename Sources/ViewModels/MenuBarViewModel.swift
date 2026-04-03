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

    private let provider: any QuoteProviding
    private let settingsStore: MenuBarSettingsStore
    private let refreshScheduler: QuoteRefreshScheduler
    private var hasLoaded = false
    private var activeFetchTask: Task<[StockQuote], Error>?
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        provider: any QuoteProviding,
        settingsStore: MenuBarSettingsStore,
        refreshScheduler: QuoteRefreshScheduler = QuoteRefreshScheduler()
    ) {
        self.provider = provider
        self.settingsStore = settingsStore
        self.refreshScheduler = refreshScheduler
        viewState = settingsStore.settings.watchlist.isEmpty ? .emptyWatchlist : .loading

        settingsStore.$settings
            .map(\.watchlist)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleWatchlistChange() }
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

    var displayQuotes: [DisplayQuote] {
        guard case let .loaded(quotes) = viewState else { return [] }
        return quotes
    }

    var statusText: String {
        switch viewState {
        case .loading:
            return "加载中..."
        case .emptyWatchlist:
            return "请先添加股票"
        case .failed:
            return "行情不可用"
        case .loaded:
            return ""
        }
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

    private func handleWatchlistChange() async {
        guard !currentSymbols.isEmpty else {
            cancelActiveFetch()
            applyEmptyWatchlistState()
            return
        }

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

        let displayQuotes = displayQuotes(from: quotes)
        if !displayQuotes.isEmpty {
            viewState = .loaded(displayQuotes)
        } else if self.displayQuotes.isEmpty {
            viewState = .failed
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

            if failureBehavior == .showFailure || displayQuotes.isEmpty {
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

    private func applyEmptyWatchlistState() {
        stopRefresh()
        hasLoaded = true
        viewState = .emptyWatchlist
    }

    private func applyLoadedQuotes(_ quotes: [StockQuote]?) {
        guard let quotes else { return }

        let displayQuotes = displayQuotes(from: quotes)
        viewState = displayQuotes.isEmpty ? .failed : .loaded(displayQuotes)
        startRefreshIfNeeded()
        hasLoaded = true
    }
}
