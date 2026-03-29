/// 管理菜单栏标签所需的紧凑行情状态。
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayQuotes: [DisplayQuote] = []
    @Published private(set) var isLoading = false

    private let provider: any QuoteProviding
    private var hasLoaded = false

    init(provider: any QuoteProviding) {
        self.provider = provider
    }

    var displayQuote: DisplayQuote? {
        displayQuotes.first
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
            hasLoaded = true
        } catch {
            displayQuotes = []
        }
    }

    func displayQuotesForPreview(_ quotes: [DisplayQuote]) {
        displayQuotes = quotes
        hasLoaded = true
    }
}
