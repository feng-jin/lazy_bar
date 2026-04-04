struct MenuBarPresentationBuilder {
    func build(
        contentState: MenuBarContentState,
        settings: MenuBarDisplaySettings
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            displayQuotes: contentState.displayQuotes,
            settings: settings,
            statusText: contentState.statusText
        )
    }
}
