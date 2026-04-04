enum MenuBarContentState: Equatable {
    case loading
    case emptyWatchlist
    case failed
    case loaded([DisplayQuote])

    var displayQuotes: [DisplayQuote] {
        guard case let .loaded(quotes) = self else { return [] }
        return quotes
    }

    var statusText: String {
        switch self {
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
