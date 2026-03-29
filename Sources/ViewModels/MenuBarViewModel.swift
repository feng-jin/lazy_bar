/// 管理菜单栏标签所需的紧凑行情状态。
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    struct MenuBarTickerItem: Equatable, Identifiable {
        let id: String
        let text: String
    }

    @Published private(set) var displayQuotes: [DisplayQuote] = []
    @Published private(set) var isLoading = false

    private let provider: any QuoteProviding
    private var hasLoaded = false
    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalNanoseconds: UInt64 = 3_000_000_000

    init(provider: any QuoteProviding) {
        self.provider = provider
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
            let quotes = try await provider.fetchQuotes()
            displayQuotes = quotes.map(DisplayQuote.init)
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
                    text: $0.menuBarSummaryText(settings: settings)
                )
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

    private func refreshQuotes() async {
        do {
            let quotes = try await provider.fetchQuotes()
            displayQuotes = quotes.map(DisplayQuote.init)
        } catch {
            // Keep the last successful snapshot when periodic refresh fails.
        }
    }
}
