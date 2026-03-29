/// 为 SwiftUI Preview 提供稳定的示例数据和预加载的 ViewModel。
import Foundation

@MainActor
enum PreviewMocks {
    static let stockQuote = MockQuoteProvider.sampleQuote

    static let displayQuote = DisplayQuote(quote: stockQuote)

    @MainActor
    static var menuBarViewModel: MenuBarViewModel {
        let viewModel = MenuBarViewModel(provider: MockQuoteProvider())
        viewModel.displayQuoteForPreview(displayQuote)
        return viewModel
    }
}
