/// 管理菜单栏标签所需的紧凑行情状态。
import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
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

    func statusMessage(settings: MenuBarDisplaySettings) -> String {
        if isLoading {
            return "加载中..."
        }

        if settings.watchlist.isEmpty {
            return "请先添加股票"
        }

        return "行情不可用"
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
}
