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
        var watchlistRows: [WatchlistDraftRow]

        init(settings: MenuBarDisplaySettings) {
            self.settings = settings
            self.watchlistRows = settings.watchlist.map { WatchlistDraftRow(entry: $0) }
        }

        mutating func syncSettingsWatchlist() {
            settings.watchlist = watchlistRows.map(\.entry)
        }
    }

    @Published private(set) var settings: MenuBarDisplaySettings
    @Published var draft: DraftState
    @Published var newEntry = WatchlistEntry(symbol: "", companyName: "")

    private let store: any MenuBarSettingsStoring
    private var cancellables = Set<AnyCancellable>()

    init(store: any MenuBarSettingsStoring) {
        self.store = store
        settings = store.settings
        draft = DraftState(settings: store.settings)

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
        let sanitizedSettings = currentDraftSettings().sanitized()
        guard sanitizedSettings.validationMessage() == nil else { return }
        store.update(sanitizedSettings)
    }

    func binding(for field: MenuBarDisplaySettings.Field) -> BindingValue<Bool> {
        BindingValue(
            get: { [weak self] in
                self?.draft.settings.showsField(field) ?? false
            },
            set: { [weak self] isVisible in
                self?.draft.settings.setField(field, isVisible: isVisible)
            }
        )
    }

    func bindingForNewEntrySymbol() -> BindingValue<String> {
        BindingValue(
            get: { [weak self] in
                self?.newEntry.symbol ?? ""
            },
            set: { [weak self] input in
                self?.newEntry.symbol = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
            }
        )
    }

    func bindingForWatchlistEntryCompanyName(id: WatchlistDraftRow.ID) -> BindingValue<String> {
        BindingValue(
            get: { [weak self] in
                self?.draft.watchlistRows.first(where: { $0.id == id })?.entry.companyName ?? ""
            },
            set: { [weak self] input in
                self?.updateWatchlistEntryCompanyName(id: id, input: input)
            }
        )
    }

    func bindingForWatchlistEntrySymbol(id: WatchlistDraftRow.ID) -> BindingValue<String> {
        BindingValue(
            get: { [weak self] in
                self?.draft.watchlistRows.first(where: { $0.id == id })?.entry.symbol ?? ""
            },
            set: { [weak self] input in
                self?.updateWatchlistEntrySymbol(id: id, input: input)
            }
        )
    }

    func appendNewEntry() {
        let candidate = sanitizedNewEntry
        guard candidate.symbol.count == 6 else { return }
        guard !currentDraftSettings().containsWatchlistSymbol(candidate.symbol) else { return }
        draft.watchlistRows.append(WatchlistDraftRow(entry: candidate))
        draft.syncSettingsWatchlist()
        newEntry = WatchlistEntry(symbol: "", companyName: "")
    }

    func removeWatchlistEntry(id: WatchlistDraftRow.ID) {
        draft.watchlistRows.removeAll { $0.id == id }
        draft.syncSettingsWatchlist()
    }

    func updateWatchlistEntryCompanyName(id: WatchlistDraftRow.ID, input: String) {
        guard let index = draft.watchlistRows.firstIndex(where: { $0.id == id }) else { return }
        draft.watchlistRows[index].entry.companyName = input
        draft.syncSettingsWatchlist()
    }

    func updateWatchlistEntrySymbol(id: WatchlistDraftRow.ID, input: String) {
        guard let index = draft.watchlistRows.firstIndex(where: { $0.id == id }) else { return }
        let normalizedSymbol = String(WatchlistEntry.normalizedSymbol(from: input).prefix(6))
        draft.watchlistRows[index].entry.symbol = normalizedSymbol

        if draft.watchlistRows[index].entry.companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.watchlistRows[index].entry.companyName = normalizedSymbol
        }

        draft.syncSettingsWatchlist()
    }

    var hasUnsavedChanges: Bool {
        currentDraftSettings().sanitized() != settings
    }

    var canSave: Bool {
        validationMessage == nil && hasUnsavedChanges
    }

    var canAddWatchlistEntry: Bool {
        let candidate = sanitizedNewEntry
        guard candidate.symbol.count == 6 else { return false }
        return !currentDraftSettings().containsWatchlistSymbol(candidate.symbol)
    }

    var validationMessage: String? {
        currentDraftSettings().validationMessage()
    }

    private var sanitizedNewEntry: WatchlistEntry {
        newEntry.sanitized
    }

    private func currentDraftSettings() -> MenuBarDisplaySettings {
        var settings = draft.settings
        settings.watchlist = draft.watchlistRows.map(\.entry)
        return settings
    }

    private func resetDraft(from settings: MenuBarDisplaySettings) {
        draft = DraftState(settings: settings)
        newEntry = WatchlistEntry(symbol: "", companyName: "")
    }
}

struct BindingValue<Value> {
    let get: () -> Value
    let set: (Value) -> Void
}
