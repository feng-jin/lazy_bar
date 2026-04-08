struct MenuBarPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let id: String
        let columns: DisplayQuote.QuoteColumns
    }

    let rows: [Row]
    let barRows: [Row]
    let layout: QuoteColumnLayout
    let statusText: String
    let displayMode: MenuBarDisplaySettings.DisplayMode

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
        displayMode = settings.displayMode
        if
            settings.displayMode == .fixed,
            let fixedSymbol = settings.resolvedFixedSymbol(in: rows.map(\.id)),
            let fixedRow = rows.first(where: { $0.id == fixedSymbol })
        {
            barRows = [fixedRow]
        } else {
            barRows = rows
        }
        layout = QuoteColumnLayoutCalculator.layout(
            columns: rows.map(\.columns),
            statusText: statusText
        )
        self.statusText = statusText
    }

    var debugSignature: String {
        if barRows.isEmpty {
            return "status:\(statusText)"
        }

        return rowsSignature(barRows)
    }

    var contentIdentity: String {
        if barRows.isEmpty {
            return "status:\(statusText):\(layout.itemWidth)"
        }

        return "rows:\(rowsSignature(barRows)):\(layout.itemWidth)"
    }

    private func rowsSignature(_ rows: [Row]) -> String {
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
