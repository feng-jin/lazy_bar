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
        symbols.compactMap { quoteSnapshotsBySymbol[$0] }
    }

    func updateTrackedSymbols(_ symbols: [String]) -> [StockQuote] {
        pruneSnapshots(excluding: Set(symbols))
        return cachedQuotes(for: symbols)
    }

    func fetchLatest(symbols: [String]) async -> FetchOutcome {
        guard !symbols.isEmpty else {
            return .success([])
        }

        activeFetchTask?.cancel()
        let task = Task { try await provider.fetchQuotes(symbols: symbols) }
        activeFetchTask = task

        do {
            let quotes = try await task.value
            guard activeFetchTask == task else { return .cancelled }
            activeFetchTask = nil
            replaceSnapshots(with: quotes, for: symbols)
            return .success(cachedQuotes(for: symbols))
        } catch is CancellationError {
            if activeFetchTask == task {
                activeFetchTask = nil
            }
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

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let intervalNanoseconds = self.refreshScheduler.delayNanoseconds()
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }

                let symbols = currentSymbols()
                guard !symbols.isEmpty else {
                    continue
                }

                let outcome = await self.fetchLatest(symbols: symbols)
                guard !Task.isCancelled else { return }
                handleResult(outcome)
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func reset() {
        stopRefreshing()
        cancelActiveFetch()
        quoteSnapshotsBySymbol = [:]
    }

    private func cancelActiveFetch() {
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
}
