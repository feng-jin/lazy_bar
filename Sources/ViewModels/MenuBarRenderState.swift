struct MenuBarRenderState: Equatable {
    let displayQuotes: [DisplayQuote]
    let settings: MenuBarDisplaySettings
    let statusText: String

    init(
        contentState: MenuBarContentState,
        settings: MenuBarDisplaySettings
    ) {
        displayQuotes = contentState.displayQuotes
        self.settings = settings
        statusText = contentState.statusText
    }
}
