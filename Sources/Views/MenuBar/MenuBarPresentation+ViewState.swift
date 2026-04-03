import Foundation

extension MenuBarPresentation {
    init(
        viewState: MenuBarViewModel.ViewState,
        settings: MenuBarDisplaySettings
    ) {
        self.init(
            displayQuotes: Self.displayQuotes(from: viewState),
            settings: settings,
            statusText: Self.statusText(from: viewState)
        )
    }

    private static func displayQuotes(
        from viewState: MenuBarViewModel.ViewState
    ) -> [DisplayQuote] {
        guard case let .loaded(quotes) = viewState else { return [] }
        return quotes
    }

    private static func statusText(
        from viewState: MenuBarViewModel.ViewState
    ) -> String {
        switch viewState {
        case .loading:
            return "加载中..."
        case .emptyWatchlist:
            return "请先添加股票"
        case .failed:
            return "行情不可用"
        case .loaded:
            return ""
        }
    }
}
