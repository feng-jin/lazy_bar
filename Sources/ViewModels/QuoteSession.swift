import Foundation
import os

@MainActor
final class QuoteSession {
    enum FetchOutcome {
        case success([StockQuote])
        case failure(cachedQuotes: [StockQuote])
        case cancelled
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "QuoteSession"
    )

    private let provider: any QuoteProviding
    private let refreshScheduler: QuoteRefreshScheduler
    private var quoteSnapshotsBySymbol: [String: StockQuote] = [:]
    private var activeFetchTask: Task<[StockQuote], Error>?
    private var refreshTask: Task<Void, Never>?

    init(
        provider: any QuoteProviding,
        refreshScheduler: QuoteRefreshScheduler = QuoteRefreshScheduler()
    ) {
        self.provider = provider
        self.refreshScheduler = refreshScheduler
    }

    deinit {
        activeFetchTask?.cancel()
        refreshTask?.cancel()
    }

    func cachedQuotes(for symbols: [String]) -> [StockQuote] {
        let quotes = symbols.compactMap { quoteSnapshotsBySymbol[$0] }
        Self.logger.debug(
            "cachedQuotes symbols=\(Self.symbolsDescription(symbols), privacy: .public) hits=\(quotes.count, privacy: .public)"
        )
        return quotes
    }

    func updateTrackedSymbols(_ symbols: [String]) -> [StockQuote] {
        Self.logger.debug(
            """
            updateTrackedSymbols newSymbols=\(Self.symbolsDescription(symbols), privacy: .public) \
            cachedBefore=\(Self.symbolsDescription(Array(self.quoteSnapshotsBySymbol.keys).sorted()), privacy: .public)
            """
        )
        pruneSnapshots(excluding: Set(symbols))
        return cachedQuotes(for: symbols)
    }

    func fetchLatest(symbols: [String]) async -> FetchOutcome {
        guard !symbols.isEmpty else {
            Self.logger.debug("fetchLatest skipped empty symbol list")
            return .success([])
        }

        Self.logger.debug(
            """
            fetchLatest start symbols=\(Self.symbolsDescription(symbols), privacy: .public) \
            cachedBefore=\(self.quoteSnapshotsBySymbol.count, privacy: .public)
            """
        )
        activeFetchTask?.cancel()
        let task = Task { try await provider.fetchQuotes(symbols: symbols) }
        activeFetchTask = task

        do {
            let quotes = try await task.value
            guard activeFetchTask == task else { return .cancelled }
            activeFetchTask = nil
            replaceSnapshots(with: quotes, for: symbols)
            Self.logger.debug(
                """
                fetchLatest success requested=\(symbols.count, privacy: .public) \
                received=\(quotes.count, privacy: .public) \
                cachedAfter=\(self.quoteSnapshotsBySymbol.count, privacy: .public)
                """
            )
            return .success(cachedQuotes(for: symbols))
        } catch is CancellationError {
            if activeFetchTask == task {
                activeFetchTask = nil
            }
            Self.logger.debug(
                "fetchLatest cancelled symbols=\(Self.symbolsDescription(symbols), privacy: .public)"
            )
            return .cancelled
        } catch {
            guard activeFetchTask == task else { return .cancelled }
            activeFetchTask = nil
            Self.logger.error(
                """
                fetchLatest failed symbols=\(Self.symbolsDescription(symbols), privacy: .public) \
                cachedFallback=\(self.cachedQuotes(for: symbols).count, privacy: .public) \
                error=\(error.localizedDescription, privacy: .public)
                """
            )
            return .failure(cachedQuotes: cachedQuotes(for: symbols))
        }
    }

    func startRefreshingIfNeeded(
        currentSymbols: @escaping @MainActor () -> [String],
        handleResult: @escaping @MainActor (FetchOutcome) -> Void
    ) {
        guard refreshTask == nil else { return }
        Self.logger.debug("startRefreshingIfNeeded starting refresh loop")

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let intervalNanoseconds = self.refreshScheduler.delayNanoseconds()
                let delaySeconds = Double(intervalNanoseconds) / 1_000_000_000
                Self.logger.debug(
                    "refreshLoop waiting \(delaySeconds, format: .fixed(precision: 3))s before next fetch"
                )
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }

                let symbols = currentSymbols()
                guard !symbols.isEmpty else {
                    Self.logger.debug("refreshLoop skipped because current symbols are empty")
                    continue
                }

                Self.logger.debug(
                    "refreshLoop fetching symbols=\(Self.symbolsDescription(symbols), privacy: .public)"
                )
                let outcome = await self.fetchLatest(symbols: symbols)
                guard !Task.isCancelled else { return }
                Self.logger.debug(
                    "refreshLoop result=\(Self.debugDescription(for: outcome), privacy: .public)"
                )
                handleResult(outcome)
            }
        }
    }

    func stopRefreshing() {
        Self.logger.debug("stopRefreshing")
        refreshTask?.cancel()
        refreshTask = nil
    }

    func reset() {
        Self.logger.debug(
            "reset clearingSnapshots=\(self.quoteSnapshotsBySymbol.count, privacy: .public)"
        )
        stopRefreshing()
        cancelActiveFetch()
        quoteSnapshotsBySymbol = [:]
    }

    private func cancelActiveFetch() {
        if activeFetchTask != nil {
            Self.logger.debug("cancelActiveFetch")
        }
        activeFetchTask?.cancel()
        activeFetchTask = nil
    }

    private func replaceSnapshots(with quotes: [StockQuote], for symbols: [String]) {
        for symbol in symbols {
            quoteSnapshotsBySymbol.removeValue(forKey: symbol)
        }

        for quote in quotes {
            quoteSnapshotsBySymbol[quote.symbol] = quote
        }

        Self.logger.debug(
            """
            replaceSnapshots trackedSymbols=\(Self.symbolsDescription(symbols), privacy: .public) \
            storedSymbols=\(Self.symbolsDescription(Array(self.quoteSnapshotsBySymbol.keys).sorted()), privacy: .public)
            """
        )
    }

    private func pruneSnapshots(excluding retainedSymbols: Set<String>) {
        let removedSymbols = quoteSnapshotsBySymbol.keys
            .filter { !retainedSymbols.contains($0) }
            .sorted()
        quoteSnapshotsBySymbol = quoteSnapshotsBySymbol.filter { retainedSymbols.contains($0.key) }
        if !removedSymbols.isEmpty {
            Self.logger.debug(
                "pruneSnapshots removed=\(Self.symbolsDescription(removedSymbols), privacy: .public)"
            )
        }
    }

    private static func symbolsDescription(_ symbols: [String]) -> String {
        if symbols.isEmpty {
            return "[]"
        }

        return "[\(symbols.joined(separator: ","))]"
    }

    private static func debugDescription(for outcome: FetchOutcome) -> String {
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
