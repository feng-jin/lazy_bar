/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation
import os

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "MenuBarSettingsViewModel"
    )

    struct WatchlistDraftRow: Identifiable, Equatable {
        let id: UUID
        var entry: WatchlistEntry

        init(id: UUID = UUID(), entry: WatchlistEntry) {
            self.id = id
            self.entry = entry
        }
    }

    struct DraftState: Equatable {
        var settings: MenuBarDisplaySettings
        var watchlistRowIDs: [WatchlistDraftRow.ID]
    }

    @Published private(set) var settings: MenuBarDisplaySettings
    @Published var draft: DraftState
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [StockSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchStatusMessage: String?
    @Published private(set) var isSearchOverlayVisible = false

    private let store: any MenuBarSettingsStoring
    private let stockSearchProvider: any StockSearchProviding
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(
        store: any MenuBarSettingsStoring,
        stockSearchProvider: any StockSearchProviding
    ) {
        self.store = store
        self.stockSearchProvider = stockSearchProvider
        settings = store.settings
        draft = DraftState(
            settings: store.settings,
            watchlistRowIDs: store.settings.watchlist.map { _ in UUID() }
        )

        store.settingsPublisher
            .dropFirst()
            .sink { [weak self] settings in
                guard let self else { return }
                self.settings = settings

                if !self.hasUnsavedChanges {
                    self.resetDraft(from: settings)
                }
            }
            .store(in: &cancellables)

        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(for: query)
            }
            .store(in: &cancellables)
    }

    func beginEditing() {
        guard !hasUnsavedChanges else {
            return
        }
        resetDraft(from: settings)
    }

    func cancel() {
        resetDraft(from: settings)
        clearSearch(reason: "cancel")
    }

    func save() {
        let sanitizedSettings = draft.settings.sanitized()
        guard let validationMessage = sanitizedSettings.validationMessage() else {
            Self.logger.debug(
                "save watchlist=\(sanitizedSettings.watchlist.count, privacy: .public)"
            )
            store.update(sanitizedSettings)
            return
        }
        Self.logger.error("save blocked validation=\(validationMessage, privacy: .public)")
    }

    func showsField(_ field: MenuBarDisplaySettings.Field) -> Bool {
        draft.settings.showsField(field)
    }

    func displayMode() -> MenuBarDisplaySettings.DisplayMode {
        draft.settings.displayMode
    }

    func setDisplayMode(_ mode: MenuBarDisplaySettings.DisplayMode) {
        let previousMode = draft.settings.displayMode
        draft.settings.displayMode = mode
        guard previousMode != mode else { return }
    }

    func setField(_ field: MenuBarDisplaySettings.Field, isVisible: Bool) {
        let previousValue = draft.settings.showsField(field)
        draft.settings.setField(field, isVisible: isVisible)
        guard previousValue != isVisible else { return }
    }

    var watchlistRows: [WatchlistDraftRow] {
        zip(draft.watchlistRowIDs, draft.settings.watchlist).map { id, entry in
            WatchlistDraftRow(id: id, entry: entry)
        }
    }

    func selectSearchResult(_ result: StockSearchResult) {
        guard !draft.settings.containsWatchlistSymbol(result.symbol) else {
            Self.logger.debug(
                "selectSearchResult ignored duplicate symbol=\(result.symbol, privacy: .public)"
            )
            searchStatusMessage = "这只股票已经在监控列表里。"
            return
        }

        let entry = WatchlistEntry(symbol: result.symbol, companyName: result.companyName).sanitized
        draft.settings.watchlist.append(entry)
        draft.watchlistRowIDs.append(UUID())
        Self.logger.debug(
            """
            selectSearchResult symbol=\(entry.symbol, privacy: .public) \
            companyName=\(entry.companyName, privacy: .public) \
            watchlistCount=\(self.draft.settings.watchlist.count, privacy: .public)
            """
        )
        clearSearch(reason: "selectResult")
    }

    func removeWatchlistEntry(id: WatchlistDraftRow.ID) {
        guard let index = draft.watchlistRowIDs.firstIndex(of: id) else {
            Self.logger.error("removeWatchlistEntry missing row id")
            return
        }
        let removedEntry = draft.settings.watchlist[index]
        draft.watchlistRowIDs.remove(at: index)
        draft.settings.watchlist.remove(at: index)
        Self.logger.debug(
            """
            removeWatchlistEntry symbol=\(removedEntry.symbol, privacy: .public) \
            companyName=\(removedEntry.companyName, privacy: .public) \
            watchlistCount=\(self.draft.settings.watchlist.count, privacy: .public)
            """
        )
    }

    func updateWatchlistEntryCompanyName(id: WatchlistDraftRow.ID, input: String) {
        guard let index = watchlistIndex(for: id) else {
            Self.logger.error("updateWatchlistEntryCompanyName missing row id")
            return
        }
        draft.settings.watchlist[index].companyName = input
    }

    func updateWatchlistEntrySymbol(id: WatchlistDraftRow.ID, input: String) {
        guard let index = watchlistIndex(for: id) else {
            Self.logger.error("updateWatchlistEntrySymbol missing row id")
            return
        }
        let normalizedSymbol = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
        let previousSymbol = draft.settings.watchlist[index].symbol
        draft.settings.watchlist[index].symbol = normalizedSymbol

        if draft.settings.watchlist[index].companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.settings.watchlist[index].companyName = normalizedSymbol
        }

        if previousSymbol != normalizedSymbol {
            Self.logger.debug(
                """
                updateWatchlistEntrySymbol from=\(previousSymbol, privacy: .public) \
                to=\(normalizedSymbol, privacy: .public)
                """
            )
        }
    }

    var hasUnsavedChanges: Bool {
        draft.settings.sanitized() != settings
    }

    var canSave: Bool {
        validationMessage == nil && hasUnsavedChanges
    }

    var showsSearchResults: Bool {
        isSearchOverlayVisible
    }

    var validationMessage: String? {
        draft.settings.validationMessage()
    }

    private func resetDraft(from settings: MenuBarDisplaySettings) {
        draft = DraftState(
            settings: settings,
            watchlistRowIDs: settings.watchlist.map { _ in UUID() }
        )
    }

    func isSearchResultAlreadyAdded(_ result: StockSearchResult) -> Bool {
        draft.settings.containsWatchlistSymbol(result.symbol)
    }

    func selectFirstSearchResultIfAvailable() {
        guard let result = searchResults.first, !isSearchResultAlreadyAdded(result) else {
            return
        }

        selectSearchResult(result)
    }

    @discardableResult
    func dismissSearchIfNeeded(reason: String = "dismissIfNeeded") -> Bool {
        let hasVisibleSearchState = showsSearchResults

        guard hasVisibleSearchState else {
            return false
        }

        dismissSearchOverlay(reason: reason)
        return true
    }

    func revealSearchOverlayIfNeeded() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        Self.logger.debug(
            "revealSearchOverlayIfNeeded query=\(trimmedQuery, privacy: .public)"
        )
        isSearchOverlayVisible = true
    }

    private func watchlistIndex(for id: WatchlistDraftRow.ID) -> Int? {
        draft.watchlistRowIDs.firstIndex(of: id)
    }

    private func watchlistEntry(id: WatchlistDraftRow.ID) -> WatchlistEntry? {
        guard let index = watchlistIndex(for: id) else { return nil }
        return draft.settings.watchlist[index]
    }

    func watchlistEntryCompanyName(id: WatchlistDraftRow.ID) -> String {
        watchlistEntry(id: id)?.companyName ?? ""
    }

    func watchlistEntrySymbol(id: WatchlistDraftRow.ID) -> String {
        watchlistEntry(id: id)?.symbol ?? ""
    }
    private func performSearch(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if searchTask != nil {
            Self.logger.debug("performSearch cancelling previous in-flight search task")
        }
        searchTask?.cancel()

        guard !trimmedQuery.isEmpty else {
            clearSearch(reason: "emptyQuery")
            return
        }

        isSearching = true
        isSearchOverlayVisible = true
        searchStatusMessage = nil
        searchTask = Task { [weak self] in
            guard let self else { return }

            do {
                Self.logger.debug("performSearch task started query=\(trimmedQuery, privacy: .public)")
                let results = try await stockSearchProvider.searchStocks(query: trimmedQuery)
                guard !Task.isCancelled else {
                    Self.logger.debug(
                        "performSearch task cancelled after provider returned query=\(trimmedQuery, privacy: .public)"
                    )
                    return
                }

                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = results
                    self.searchStatusMessage = results.isEmpty ? "没有找到匹配的 A 股，请换个简称或代码。" : nil
                    self.isSearchOverlayVisible = true
                    self.searchTask = nil
                }
                Self.logger.debug(
                    """
                    performSearch completed query=\(trimmedQuery, privacy: .public) \
                    resultCount=\(results.count, privacy: .public) \
                    status=\(self.searchStatusMessage ?? "nil", privacy: .public)
                    """
                )
            } catch {
                guard !Task.isCancelled else {
                    Self.logger.debug(
                        "performSearch task cancelled during failure handling query=\(trimmedQuery, privacy: .public)"
                    )
                    return
                }

                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = []
                    self.searchStatusMessage = "搜索失败，请稍后再试。"
                    self.isSearchOverlayVisible = true
                    self.searchTask = nil
                }
                Self.logger.error(
                    "performSearch failed query=\(trimmedQuery, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func dismissSearchOverlay(reason: String) {
        guard isSearchOverlayVisible else {
            return
        }

        Self.logger.debug("dismissSearchOverlay reason=\(reason, privacy: .public)")
        isSearchOverlayVisible = false
    }

    private func clearSearch(reason: String) {
        guard isSearchOverlayVisible || !searchQuery.isEmpty || !searchResults.isEmpty || isSearching else {
            return
        }

        Self.logger.debug("clearSearch reason=\(reason, privacy: .public)")
        searchTask?.cancel()
        searchTask = nil
        isSearchOverlayVisible = false
        searchQuery = ""
        searchResults = []
        isSearching = false
        searchStatusMessage = nil
    }
}
