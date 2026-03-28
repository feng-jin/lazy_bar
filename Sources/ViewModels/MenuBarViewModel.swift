/// 管理菜单栏标签所需的紧凑行情状态。
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
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
            let quote = try await provider.fetchQuote()
            displayQuote = DisplayQuote(quote: quote)
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
