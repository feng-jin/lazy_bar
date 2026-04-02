/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
    @Published private(set) var settings: MenuBarDisplaySettings
    @Published private(set) var draftSettings: MenuBarDisplaySettings
    @Published var watchlistSymbolInput = ""
    @Published var watchlistNameInput = ""

    private let store: MenuBarSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: MenuBarSettingsStore) {
        self.store = store
        settings = store.settings
        draftSettings = store.settings

        store.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.settings = settings

                if !self.hasUnsavedChanges {
                    self.draftSettings = settings
                    self.resetInputs()
                }
            }
            .store(in: &cancellables)
    }

    func setShowsSymbol(_ isEnabled: Bool) {
        updateDraftSettings { $0.showsSymbol = isEnabled }
    }

    func setShowsCompanyName(_ isEnabled: Bool) {
        updateDraftSettings { $0.showsCompanyName = isEnabled }
    }

    func setShowsPrice(_ isEnabled: Bool) {
        updateDraftSettings { $0.showsPrice = isEnabled }
    }

    func setShowsChangePercent(_ isEnabled: Bool) {
        updateDraftSettings { $0.showsChangePercent = isEnabled }
    }

    func updateWatchlistSymbolInput(_ input: String) {
        watchlistSymbolInput = input
    }

    func updateWatchlistNameInput(_ input: String) {
        watchlistNameInput = input
    }

    func addWatchlistEntry() {
        let symbol = Self.normalizedSymbol(from: watchlistSymbolInput)
        let companyName = Self.normalizedCompanyName(from: watchlistNameInput)
        guard symbol.count == 6, !companyName.isEmpty else { return }

        updateDraftSettings { settings in
            guard !settings.watchlist.contains(where: { $0.symbol == symbol }) else { return }
            settings.watchlist.append(
                WatchlistEntry(
                    symbol: symbol,
                    companyName: companyName
                )
            )
        }
        resetInputs()
    }

    func removeWatchlistEntry(symbol: String) {
        updateDraftSettings { settings in
            settings.watchlist.removeAll { $0.symbol == symbol }
        }
    }

    var hasUnsavedChanges: Bool {
        draftSettings != settings
    }

    func save() {
        guard hasUnsavedChanges else { return }
        store.update(draftSettings)
    }

    func cancel() {
        draftSettings = settings
        resetInputs()
    }

    func beginEditing() {
        guard !hasUnsavedChanges else { return }
        draftSettings = settings
        resetInputs()
    }

    private func updateDraftSettings(_ mutation: (inout MenuBarDisplaySettings) -> Void) {
        var updatedSettings = draftSettings
        mutation(&updatedSettings)
        draftSettings = updatedSettings
    }

    private static func normalizedSymbol(from input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }

    private static func normalizedCompanyName(from input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetInputs() {
        watchlistSymbolInput = ""
        watchlistNameInput = ""
    }
}
