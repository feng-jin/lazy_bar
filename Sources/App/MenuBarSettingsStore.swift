/// 持久化菜单栏展示设置，方便设置页和状态项控制器共享。
import Combine
import Foundation

@MainActor
final class MenuBarSettingsStore: ObservableObject {
    @Published private(set) var settings: MenuBarDisplaySettings

    private let userDefaults: UserDefaults
    private let storageKey = "menuBarDisplaySettings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if
            let data = userDefaults.data(forKey: storageKey),
            let settings = try? JSONDecoder().decode(MenuBarDisplaySettings.self, from: data)
        {
            self.settings = settings
        } else {
            self.settings = .default
        }
    }

    func update(_ settings: MenuBarDisplaySettings) {
        self.settings = settings

        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
