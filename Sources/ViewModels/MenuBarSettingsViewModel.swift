/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
    struct EditableWatchlistEntry: Identifiable, Equatable {
        let id = UUID()
        var symbol: String
        var companyName: String
    }

    @Published private(set) var settings: MenuBarDisplaySettings
    @Published private(set) var draftWatchlist: [EditableWatchlistEntry]
    @Published private(set) var draftShowsSymbol: Bool
    @Published private(set) var draftShowsCompanyName: Bool
    @Published private(set) var draftShowsPrice: Bool
    @Published private(set) var draftShowsChangePercent: Bool
    @Published var watchlistCompanyNameInput = ""
    @Published var watchlistSymbolInput = ""

    private let store: MenuBarSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: MenuBarSettingsStore) {
        self.store = store
        settings = store.settings
        draftWatchlist = Self.editableWatchlist(from: store.settings.watchlist)
        draftShowsSymbol = store.settings.showsSymbol
        draftShowsCompanyName = store.settings.showsCompanyName
        draftShowsPrice = store.settings.showsPrice
        draftShowsChangePercent = store.settings.showsChangePercent

        store.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.settings = settings

                if !self.hasUnsavedChanges {
                    self.replaceDraft(with: settings)
                    self.watchlistCompanyNameInput = ""
                    self.watchlistSymbolInput = ""
                }
            }
            .store(in: &cancellables)
    }

    func setShowsSymbol(_ isEnabled: Bool) {
        draftShowsSymbol = isEnabled
    }

    func setShowsCompanyName(_ isEnabled: Bool) {
        draftShowsCompanyName = isEnabled
    }

    func setShowsPrice(_ isEnabled: Bool) {
        draftShowsPrice = isEnabled
    }

    func setShowsChangePercent(_ isEnabled: Bool) {
        draftShowsChangePercent = isEnabled
    }

    func updateWatchlistCompanyNameInput(_ input: String) {
        watchlistCompanyNameInput = input
    }

    func updateWatchlistSymbolInput(_ input: String) {
        watchlistSymbolInput = String(Self.normalizedSymbol(from: input).prefix(6))
    }

    func addWatchlistEntry() {
        let symbol = Self.normalizedSymbol(from: watchlistSymbolInput)
        guard symbol.count == 6 else { return }
        let companyName = watchlistCompanyNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !draftWatchlist.contains(where: { $0.symbol == symbol }) else { return }
        draftWatchlist.append(
            EditableWatchlistEntry(
                symbol: symbol,
                companyName: companyName.isEmpty ? symbol : companyName
            )
        )
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    func removeWatchlistEntry(id: EditableWatchlistEntry.ID) {
        draftWatchlist.removeAll { $0.id == id }
    }

    func updateWatchlistEntrySymbol(id: EditableWatchlistEntry.ID, input: String) {
        guard let index = draftWatchlist.firstIndex(where: { $0.id == id }) else { return }

        let normalizedSymbol = String(Self.normalizedSymbol(from: input).prefix(6))
        draftWatchlist[index].symbol = normalizedSymbol

        if draftWatchlist[index].companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftWatchlist[index].companyName = normalizedSymbol
        }
    }

    func updateWatchlistEntryCompanyName(id: EditableWatchlistEntry.ID, input: String) {
        guard let index = draftWatchlist.firstIndex(where: { $0.id == id }) else { return }
        draftWatchlist[index].companyName = input
    }

    func resetWatchlistToBase() {
        draftWatchlist = Self.editableWatchlist(from: store.baseWatchlist)
    }

    var hasUnsavedChanges: Bool {
        currentDraftSettings() != settings
    }

    var canSave: Bool {
        validationMessage == nil && hasUnsavedChanges
    }

    func save() {
        guard let sanitizedSettings = sanitizedDraftSettings() else { return }
        store.update(sanitizedSettings)
    }

    func cancel() {
        replaceDraft(with: settings)
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    func beginEditing() {
        guard !hasUnsavedChanges else { return }
        replaceDraft(with: settings)
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    var canAddWatchlistEntry: Bool {
        let symbol = Self.normalizedSymbol(from: watchlistSymbolInput)
        guard symbol.count == 6 else { return false }
        return !draftWatchlist.contains(where: { $0.symbol == symbol })
    }

    var validationMessage: String? {
        let entries = draftWatchlist
        var seenSymbols = Set<String>()

        for entry in entries {
            let symbol = Self.normalizedSymbol(from: entry.symbol)
            guard !symbol.isEmpty else {
                return "监控列表里有空代码，请补全为 6 位股票代码。"
            }

            guard symbol.count == 6 else {
                return "监控列表里的股票代码必须是 6 位数字。"
            }

            guard seenSymbols.insert(symbol).inserted else {
                return "监控列表里存在重复代码，请删除或修改后再保存。"
            }
        }

        return nil
    }

    var canResetWatchlistToBase: Bool {
        draftWatchlist.map(Self.watchlistEntry(from:)) != store.baseWatchlist
    }

    private func currentDraftSettings() -> MenuBarDisplaySettings {
        MenuBarDisplaySettings(
            watchlist: draftWatchlist.map(Self.watchlistEntry(from:)),
            showsSymbol: draftShowsSymbol,
            showsCompanyName: draftShowsCompanyName,
            showsPrice: draftShowsPrice,
            showsChangePercent: draftShowsChangePercent
        )
    }

    private func sanitizedDraftSettings() -> MenuBarDisplaySettings? {
        guard validationMessage == nil else { return nil }
        let watchlist = draftWatchlist.map { entry in
            let symbol = Self.normalizedSymbol(from: entry.symbol)
            let companyName = entry.companyName.trimmingCharacters(in: .whitespacesAndNewlines)

            return WatchlistEntry(
                symbol: symbol,
                companyName: companyName.isEmpty ? symbol : companyName
            )
        }
        return MenuBarDisplaySettings(
            watchlist: watchlist,
            showsSymbol: draftShowsSymbol,
            showsCompanyName: draftShowsCompanyName,
            showsPrice: draftShowsPrice,
            showsChangePercent: draftShowsChangePercent
        )
    }

    private func replaceDraft(with settings: MenuBarDisplaySettings) {
        draftWatchlist = Self.editableWatchlist(from: settings.watchlist)
        draftShowsSymbol = settings.showsSymbol
        draftShowsCompanyName = settings.showsCompanyName
        draftShowsPrice = settings.showsPrice
        draftShowsChangePercent = settings.showsChangePercent
    }

    private static func editableWatchlist(from watchlist: [WatchlistEntry]) -> [EditableWatchlistEntry] {
        watchlist.map {
            EditableWatchlistEntry(symbol: $0.symbol, companyName: $0.companyName)
        }
    }

    private static func watchlistEntry(from editableEntry: EditableWatchlistEntry) -> WatchlistEntry {
        WatchlistEntry(symbol: editableEntry.symbol, companyName: editableEntry.companyName)
    }

    private static func normalizedSymbol(from input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }
}
