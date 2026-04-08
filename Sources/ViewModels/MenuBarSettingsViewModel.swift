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
    @Published var newEntry = WatchlistEntry(symbol: "", companyName: "")

    private let store: any MenuBarSettingsStoring
    private var cancellables = Set<AnyCancellable>()

    init(store: any MenuBarSettingsStoring) {
        self.store = store
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
    }

    func beginEditing() {
        guard !hasUnsavedChanges else {
            Self.logger.debug("beginEditing skipped because there are unsaved draft changes")
            return
        }
        Self.logger.debug(
            "beginEditing watchlist=\(self.draft.settings.watchlist.count, privacy: .public) fields=\(Self.visibleFieldsDescription(self.draft.settings), privacy: .public)"
        )
        resetDraft(from: settings)
    }

    func cancel() {
        Self.logger.debug("cancel editing and reset draft")
        resetDraft(from: settings)
    }

    func save() {
        let sanitizedSettings = draft.settings.sanitized()
        guard let validationMessage = sanitizedSettings.validationMessage() else {
            Self.logger.debug(
                """
                save watchlist=\(sanitizedSettings.watchlist.count, privacy: .public) \
                fields=\(Self.visibleFieldsDescription(sanitizedSettings), privacy: .public)
                """
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
        Self.logger.debug("setDisplayMode mode=\(mode.rawValue, privacy: .public)")
    }

    func setField(_ field: MenuBarDisplaySettings.Field, isVisible: Bool) {
        let previousValue = draft.settings.showsField(field)
        draft.settings.setField(field, isVisible: isVisible)
        guard previousValue != isVisible else { return }
        Self.logger.debug(
            """
            setField field=\(field.rawValue, privacy: .public) \
            isVisible=\(isVisible, privacy: .public) \
            visibleFields=\(Self.visibleFieldsDescription(self.draft.settings), privacy: .public)
            """
        )
    }

    func newEntrySymbol() -> String {
        newEntry.symbol
    }

    func setNewEntrySymbol(_ input: String) {
        let normalized = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
        if newEntry.symbol != normalized {
            Self.logger.debug(
                "setNewEntrySymbol raw=\(input, privacy: .public) normalized=\(normalized, privacy: .public)"
            )
        }
        newEntry.symbol = normalized
    }

    var watchlistRows: [WatchlistDraftRow] {
        zip(draft.watchlistRowIDs, draft.settings.watchlist).map { id, entry in
            WatchlistDraftRow(id: id, entry: entry)
        }
    }

    func appendNewEntry() {
        let candidate = sanitizedNewEntry
        guard candidate.symbol.count == 6 else {
            Self.logger.error(
                "appendNewEntry blocked invalidSymbol=\(candidate.symbol, privacy: .public)"
            )
            return
        }
        guard !draft.settings.containsWatchlistSymbol(candidate.symbol) else {
            Self.logger.error(
                "appendNewEntry blocked duplicateSymbol=\(candidate.symbol, privacy: .public)"
            )
            return
        }
        draft.settings.watchlist.append(candidate)
        draft.watchlistRowIDs.append(UUID())
        newEntry = WatchlistEntry(symbol: "", companyName: "")
        Self.logger.debug(
            """
            appendNewEntry symbol=\(candidate.symbol, privacy: .public) \
            companyName=\(candidate.companyName, privacy: .public) \
            watchlistCount=\(self.draft.settings.watchlist.count, privacy: .public)
            """
        )
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

    var canAddWatchlistEntry: Bool {
        let candidate = sanitizedNewEntry
        guard candidate.symbol.count == 6 else { return false }
        return !draft.settings.containsWatchlistSymbol(candidate.symbol)
    }

    var validationMessage: String? {
        draft.settings.validationMessage()
    }

    private var sanitizedNewEntry: WatchlistEntry {
        newEntry.sanitized
    }

    private func resetDraft(from settings: MenuBarDisplaySettings) {
        draft = DraftState(
            settings: settings,
            watchlistRowIDs: settings.watchlist.map { _ in UUID() }
        )
        newEntry = WatchlistEntry(symbol: "", companyName: "")
        Self.logger.debug(
            """
            resetDraft watchlist=\(settings.watchlist.count, privacy: .public) \
            fields=\(Self.visibleFieldsDescription(settings), privacy: .public)
            """
        )
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

    private static func visibleFieldsDescription(_ settings: MenuBarDisplaySettings) -> String {
        let fields = MenuBarDisplaySettings.Field.allCases
            .filter { settings.showsField($0) }
            .map(\.rawValue)

        if fields.isEmpty {
            return "[]"
        }

        return "[\(fields.joined(separator: ","))]"
    }
}
