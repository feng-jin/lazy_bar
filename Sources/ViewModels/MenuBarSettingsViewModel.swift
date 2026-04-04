/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
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
        guard !hasUnsavedChanges else { return }
        resetDraft(from: settings)
    }

    func cancel() {
        resetDraft(from: settings)
    }

    func save() {
        let sanitizedSettings = draft.settings.sanitized()
        guard sanitizedSettings.validationMessage() == nil else { return }
        store.update(sanitizedSettings)
    }

    func showsField(_ field: MenuBarDisplaySettings.Field) -> Bool {
        draft.settings.showsField(field)
    }

    func setField(_ field: MenuBarDisplaySettings.Field, isVisible: Bool) {
        draft.settings.setField(field, isVisible: isVisible)
    }

    func newEntrySymbol() -> String {
        newEntry.symbol
    }

    func setNewEntrySymbol(_ input: String) {
        newEntry.symbol = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
    }

    var watchlistRows: [WatchlistDraftRow] {
        zip(draft.watchlistRowIDs, draft.settings.watchlist).map { id, entry in
            WatchlistDraftRow(id: id, entry: entry)
        }
    }

    func appendNewEntry() {
        let candidate = sanitizedNewEntry
        guard candidate.symbol.count == 6 else { return }
        guard !draft.settings.containsWatchlistSymbol(candidate.symbol) else { return }
        draft.settings.watchlist.append(candidate)
        draft.watchlistRowIDs.append(UUID())
        newEntry = WatchlistEntry(symbol: "", companyName: "")
    }

    func removeWatchlistEntry(id: WatchlistDraftRow.ID) {
        guard let index = draft.watchlistRowIDs.firstIndex(of: id) else { return }
        draft.watchlistRowIDs.remove(at: index)
        draft.settings.watchlist.remove(at: index)
    }

    func updateWatchlistEntryCompanyName(id: WatchlistDraftRow.ID, input: String) {
        guard let index = watchlistIndex(for: id) else { return }
        draft.settings.watchlist[index].companyName = input
    }

    func updateWatchlistEntrySymbol(id: WatchlistDraftRow.ID, input: String) {
        guard let index = watchlistIndex(for: id) else { return }
        let normalizedSymbol = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
        draft.settings.watchlist[index].symbol = normalizedSymbol

        if draft.settings.watchlist[index].companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.settings.watchlist[index].companyName = normalizedSymbol
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
}
