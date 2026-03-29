/// 管理菜单栏展示设置，供设置窗口编辑并驱动菜单栏渲染。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsViewModel: ObservableObject {
    @Published private(set) var settings: MenuBarDisplaySettings

    private let store: MenuBarSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: MenuBarSettingsStore) {
        self.store = store
        settings = store.settings

        store.$settings
            .sink { [weak self] settings in
                self?.settings = settings
            }
            .store(in: &cancellables)
    }

    func setShowsSymbol(_ isEnabled: Bool) {
        updateSettings { $0.showsSymbol = isEnabled }
    }

    func setShowsCompanyName(_ isEnabled: Bool) {
        updateSettings { $0.showsCompanyName = isEnabled }
    }

    func setShowsPrice(_ isEnabled: Bool) {
        updateSettings { $0.showsPrice = isEnabled }
    }

    func setShowsChangePercent(_ isEnabled: Bool) {
        updateSettings { $0.showsChangePercent = isEnabled }
    }

    func setUsesChangeColor(_ isEnabled: Bool) {
        updateSettings { $0.usesChangeColor = isEnabled }
    }

    private func updateSettings(_ mutation: (inout MenuBarDisplaySettings) -> Void) {
        var updatedSettings = settings
        mutation(&updatedSettings)
        store.update(updatedSettings)
    }
}
