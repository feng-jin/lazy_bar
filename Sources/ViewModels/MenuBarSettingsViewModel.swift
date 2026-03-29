/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
    @Published private(set) var settings: MenuBarDisplaySettings
    @Published private(set) var draftSettings: MenuBarDisplaySettings

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

    var hasUnsavedChanges: Bool {
        draftSettings != settings
    }

    func save() {
        guard hasUnsavedChanges else { return }
        store.update(draftSettings)
    }

    func cancel() {
        draftSettings = settings
    }

    func beginEditing() {
        guard !hasUnsavedChanges else { return }
        draftSettings = settings
    }

    private func updateDraftSettings(_ mutation: (inout MenuBarDisplaySettings) -> Void) {
        var updatedSettings = draftSettings
        mutation(&updatedSettings)
        draftSettings = updatedSettings
    }
}
