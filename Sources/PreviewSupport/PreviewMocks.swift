import Foundation

@MainActor
enum PreviewMocks {
    static let stockQuote = StockQuote(
        symbol: "AAPL",
        companyName: "Apple Inc.",
        lastPrice: 182.31,
        changeAmount: 2.24,
        changePercent: 0.0124,
        updatedAt: Date()
    )

    static let displayQuote = DisplayQuote(quote: stockQuote)

    @MainActor
    static var menuBarViewModel: MenuBarViewModel {
        let viewModel = MenuBarViewModel(provider: MockQuoteProvider())
        viewModel.displayQuoteForPreview(displayQuote)
        return viewModel
    }

    @MainActor
    static var detailViewModel: StockDetailViewModel {
        let viewModel = StockDetailViewModel(provider: MockQuoteProvider())
        viewModel.displayQuoteForPreview(displayQuote)
        return viewModel
    }
}
