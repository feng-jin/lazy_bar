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

    struct DraftSettings: Equatable {
        var watchlist: [EditableWatchlistEntry]
        var showsSymbol: Bool
        var showsCompanyName: Bool
        var showsPrice: Bool
        var showsChangePercent: Bool

        init(settings: MenuBarDisplaySettings) {
            watchlist = settings.watchlist.map {
                EditableWatchlistEntry(symbol: $0.symbol, companyName: $0.companyName)
            }
            showsSymbol = settings.showsSymbol
            showsCompanyName = settings.showsCompanyName
            showsPrice = settings.showsPrice
            showsChangePercent = settings.showsChangePercent
        }
    }

    @Published private(set) var settings: MenuBarDisplaySettings
    @Published private(set) var draftSettings: DraftSettings
    @Published var watchlistCompanyNameInput = ""
    @Published var watchlistSymbolInput = ""

    private let store: MenuBarSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: MenuBarSettingsStore) {
        self.store = store
        settings = store.settings
        draftSettings = DraftSettings(settings: store.settings)

        store.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.settings = settings

                if !self.hasUnsavedChanges {
                    self.draftSettings = DraftSettings(settings: settings)
                    self.watchlistCompanyNameInput = ""
                    self.watchlistSymbolInput = ""
                }
            }
            .store(in: &cancellables)
    }

    func showsField(_ field: MenuBarDisplaySettings.Field) -> Bool {
        switch field {
        case .companyName:
            return draftSettings.showsCompanyName
        case .symbol:
            return draftSettings.showsSymbol
        case .price:
            return draftSettings.showsPrice
        case .changePercent:
            return draftSettings.showsChangePercent
        }
    }

    func setField(_ field: MenuBarDisplaySettings.Field, isEnabled: Bool) {
        switch field {
        case .companyName:
            draftSettings.showsCompanyName = isEnabled
        case .symbol:
            draftSettings.showsSymbol = isEnabled
        case .price:
            draftSettings.showsPrice = isEnabled
        case .changePercent:
            draftSettings.showsChangePercent = isEnabled
        }
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

        guard !draftSettings.watchlist.contains(where: { $0.symbol == symbol }) else { return }
        draftSettings.watchlist.append(
            EditableWatchlistEntry(
                symbol: symbol,
                companyName: companyName.isEmpty ? symbol : companyName
            )
        )
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    func removeWatchlistEntry(id: EditableWatchlistEntry.ID) {
        draftSettings.watchlist.removeAll { $0.id == id }
    }

    func updateWatchlistEntrySymbol(id: EditableWatchlistEntry.ID, input: String) {
        guard let index = draftSettings.watchlist.firstIndex(where: { $0.id == id }) else { return }

        let normalizedSymbol = String(Self.normalizedSymbol(from: input).prefix(6))
        draftSettings.watchlist[index].symbol = normalizedSymbol

        if draftSettings.watchlist[index].companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftSettings.watchlist[index].companyName = normalizedSymbol
        }
    }

    func updateWatchlistEntryCompanyName(id: EditableWatchlistEntry.ID, input: String) {
        guard let index = draftSettings.watchlist.firstIndex(where: { $0.id == id }) else { return }
        draftSettings.watchlist[index].companyName = input
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
        draftSettings = DraftSettings(settings: settings)
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    func beginEditing() {
        guard !hasUnsavedChanges else { return }
        draftSettings = DraftSettings(settings: settings)
        watchlistCompanyNameInput = ""
        watchlistSymbolInput = ""
    }

    var canAddWatchlistEntry: Bool {
        let symbol = Self.normalizedSymbol(from: watchlistSymbolInput)
        guard symbol.count == 6 else { return false }
        return !draftSettings.watchlist.contains(where: { $0.symbol == symbol })
    }

    var validationMessage: String? {
        guard hasAtLeastOneVisibleField else {
            return "请至少保留一个展示字段，否则菜单栏和主面板都没有可显示内容。"
        }

        let entries = draftSettings.watchlist
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

    private func currentDraftSettings() -> MenuBarDisplaySettings {
        MenuBarDisplaySettings(
            watchlist: draftSettings.watchlist.map(Self.watchlistEntry(from:)),
            showsSymbol: draftSettings.showsSymbol,
            showsCompanyName: draftSettings.showsCompanyName,
            showsPrice: draftSettings.showsPrice,
            showsChangePercent: draftSettings.showsChangePercent
        )
    }

    private func sanitizedDraftSettings() -> MenuBarDisplaySettings? {
        guard validationMessage == nil else { return nil }
        let watchlist = draftSettings.watchlist.map { entry in
            let symbol = Self.normalizedSymbol(from: entry.symbol)
            let companyName = entry.companyName.trimmingCharacters(in: .whitespacesAndNewlines)

            return WatchlistEntry(
                symbol: symbol,
                companyName: companyName.isEmpty ? symbol : companyName
            )
        }
        return MenuBarDisplaySettings(
            watchlist: watchlist,
            showsSymbol: draftSettings.showsSymbol,
            showsCompanyName: draftSettings.showsCompanyName,
            showsPrice: draftSettings.showsPrice,
            showsChangePercent: draftSettings.showsChangePercent
        )
    }

    private static func watchlistEntry(from editableEntry: EditableWatchlistEntry) -> WatchlistEntry {
        WatchlistEntry(symbol: editableEntry.symbol, companyName: editableEntry.companyName)
    }

    private var hasAtLeastOneVisibleField: Bool {
        draftSettings.showsSymbol ||
        draftSettings.showsCompanyName ||
        draftSettings.showsPrice ||
        draftSettings.showsChangePercent
    }

    private static func normalizedSymbol(from input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }
}
