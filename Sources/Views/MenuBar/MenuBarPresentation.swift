struct MenuBarPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let id: String
        let columns: DisplayQuote.QuoteColumns
    }

    let rows: [Row]
    let layout: QuoteColumnLayout
    let statusText: String

    init(renderState: MenuBarRenderState) {
        self.init(
            displayQuotes: renderState.displayQuotes,
            settings: renderState.settings,
            statusText: renderState.statusText
        )
    }

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

    var debugSignature: String {
        if rows.isEmpty {
            return "status:\(statusText)"
        }

        return rowsSignature
    }

    var contentIdentity: String {
        if rows.isEmpty {
            return "status:\(statusText):\(layout.itemWidth)"
        }

        return "rows:\(rowsSignature):\(layout.itemWidth)"
    }

    private var rowsSignature: String {
        rows
            .map { row in
                [
                    row.id,
                    row.columns.nameText ?? "",
                    row.columns.symbolText ?? "",
                    row.columns.priceText ?? "",
                    row.columns.changeText ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ",")
    }
}
