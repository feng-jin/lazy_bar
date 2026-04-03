struct MenuBarPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let id: String
        let columns: DisplayQuote.QuoteColumns
    }

    let rows: [Row]
    let layout: QuoteColumnLayout
    let statusText: String

    init(
        displayQuotes: [DisplayQuote],
        settings: MenuBarDisplaySettings,
        statusText: String
    ) {
        rows = displayQuotes.map { quote in
            Row(
                id: quote.symbol,
                columns: quote.columns(settings: settings)
            )
        }
        layout = QuoteColumnLayoutCalculator.layout(
            columns: rows.map(\.columns),
            statusText: statusText
        )
        self.statusText = statusText
    }
}
