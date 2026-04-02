/// 管理菜单栏标签所需的紧凑行情状态。
import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    enum ViewState: Equatable {
        case loading
        case emptyWatchlist
        case failed
        case loaded([DisplayQuote])
    }

    @Published private(set) var viewState: ViewState

    private let provider: any QuoteProviding
    private let settingsStore: MenuBarSettingsStore
    private var hasLoaded = false
    private var isLoading = false
    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalNanoseconds: UInt64 = 3_000_000_000
    private var cancellables = Set<AnyCancellable>()

    init(provider: any QuoteProviding, settingsStore: MenuBarSettingsStore) {
        self.provider = provider
        self.settingsStore = settingsStore
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
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        let symbols = currentSymbols

        guard !symbols.isEmpty else {
            stopRefresh()
            hasLoaded = true
            viewState = .emptyWatchlist
            return
        }

        isLoading = true
        defer { isLoading = false }
        viewState = .loading

        do {
            let quotes = try await provider.fetchQuotes(symbols: symbols)
            let displayQuotes = displayQuotes(from: quotes)
            viewState = displayQuotes.isEmpty ? .failed : .loaded(displayQuotes)
            startRefreshIfNeeded()
            hasLoaded = true
        } catch {
            viewState = .failed
        }
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
        let intervalNanoseconds = refreshIntervalNanoseconds

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.refreshQuotes()
            }
        }
    }

    private func stopRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func handleWatchlistChange() async {
        guard !currentSymbols.isEmpty else {
            stopRefresh()
            hasLoaded = true
            viewState = .emptyWatchlist
            return
        }

        await load()
    }

    private func refreshQuotes() async {
        let symbols = currentSymbols
        guard !symbols.isEmpty else {
            stopRefresh()
            hasLoaded = true
            viewState = .emptyWatchlist
            return
        }

        do {
            let quotes = try await provider.fetchQuotes(symbols: symbols)
            let displayQuotes = displayQuotes(from: quotes)

            if !displayQuotes.isEmpty {
                viewState = .loaded(displayQuotes)
            } else if self.displayQuotes.isEmpty {
                viewState = .failed
            }
        } catch {
            // Keep the last successful snapshot when periodic refresh fails.
            if displayQuotes.isEmpty {
                viewState = .failed
            }
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
}
