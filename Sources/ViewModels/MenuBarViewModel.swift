/// 管理菜单栏标签所需的紧凑行情状态。
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayQuotes: [DisplayQuote] = []
    @Published private(set) var currentDisplayQuote: DisplayQuote?
    @Published private(set) var isLoading = false

    private let provider: any QuoteProviding
    private var hasLoaded = false
    private var currentQuoteIndex = 0
    private var rotationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    private let rotationIntervalNanoseconds: UInt64 = 2_500_000_000
    private let refreshIntervalNanoseconds: UInt64 = 3_000_000_000

    init(provider: any QuoteProviding) {
        self.provider = provider
    }

    var displayQuote: DisplayQuote? {
        currentDisplayQuote
    }

    deinit {
        rotationTask?.cancel()
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
            resetRotationState()
            startRefreshIfNeeded()
            hasLoaded = true
        } catch {
            displayQuotes = []
            currentDisplayQuote = nil
            rotationTask?.cancel()
            rotationTask = nil
        }
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        displayQuotes = quotes
        resetRotationState()
        hasLoaded = true
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
            syncCurrentDisplayQuoteAfterRefresh()
        } catch {
            // Keep the last successful snapshot when periodic refresh fails.
        }
    }

    private func resetRotationState() {
        rotationTask?.cancel()
        rotationTask = nil
        currentQuoteIndex = 0
        currentDisplayQuote = displayQuotes.first

        guard displayQuotes.count > 1 else { return }
        let intervalNanoseconds = rotationIntervalNanoseconds

        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }
                self?.advanceDisplayedQuote()
            }
        }
    }

    private func advanceDisplayedQuote() {
        guard !displayQuotes.isEmpty else {
            currentDisplayQuote = nil
            return
        }

        currentQuoteIndex = (currentQuoteIndex + 1) % displayQuotes.count
        currentDisplayQuote = displayQuotes[currentQuoteIndex]
    }

    private func syncCurrentDisplayQuoteAfterRefresh() {
        guard !displayQuotes.isEmpty else {
            currentQuoteIndex = 0
            currentDisplayQuote = nil
            return
        }

        if currentQuoteIndex >= displayQuotes.count {
            currentQuoteIndex = 0
        }

        currentDisplayQuote = displayQuotes[currentQuoteIndex]
    }
}
