/// 为 SwiftUI Preview 提供稳定的示例数据和预加载的 ViewModel。
import Foundation

@MainActor
enum PreviewMocks {
    static let stockQuote = MockQuoteProvider.sampleQuotes[0]

    static let displayQuote = DisplayQuote(quote: stockQuote)
    static let displayQuotes = MockQuoteProvider.sampleQuotes.map { DisplayQuote(quote: $0) }

    @MainActor
    static var menuBarViewModel: MenuBarViewModel {
        let viewModel = MenuBarViewModel(
            provider: MockQuoteProvider(),
            settingsStore: MenuBarSettingsStore()
        )
        viewModel.displayQuotesForPreview(displayQuotes)
        return viewModel
    }
}
