/// 管理展开后的详情面板所需的完整行情状态。
import Foundation

@MainActor
final class StockDetailViewModel: ObservableObject {
    @Published private(set) var displayQuote: DisplayQuote?
    @Published private(set) var isLoading = false

    private let provider: any QuoteProviding
    private var hasLoaded = false

    init(provider: any QuoteProviding) {
        self.provider = provider
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
            let quote = try await provider.fetchQuotes(symbols: []).first
            displayQuote = quote.map { DisplayQuote(quote: $0) }
            hasLoaded = true
        } catch {
            displayQuote = nil
        }
    }

    func displayQuoteForPreview(_ quote: DisplayQuote) {
        displayQuote = quote
        hasLoaded = true
    }
}
