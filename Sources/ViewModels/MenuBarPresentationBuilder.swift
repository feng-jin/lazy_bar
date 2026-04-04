struct MenuBarPresentationBuilder {
    enum ContentState: Equatable {
        case loading
        case emptyWatchlist
        case failed
        case loaded([DisplayQuote])
    }

    func build(
        contentState: ContentState,
        settings: MenuBarDisplaySettings
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            displayQuotes: displayQuotes(from: contentState),
            settings: settings,
            statusText: statusText(from: contentState)
        )
    }

    private func displayQuotes(from contentState: ContentState) -> [DisplayQuote] {
        guard case let .loaded(quotes) = contentState else { return [] }
        return quotes
    }

    private func statusText(from contentState: ContentState) -> String {
        switch contentState {
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
