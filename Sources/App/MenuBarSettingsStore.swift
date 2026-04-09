/// 持久化菜单栏展示设置，方便设置页和状态项控制器共享。
import Combine
import Foundation
import os

@MainActor
final class MenuBarSettingsStore: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "MenuBarSettingsStore"
    )

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
        let previousSettings = self.settings
        self.settings = settings
        guard previousSettings != settings else { return }

        guard let data = try? JSONEncoder().encode(settings) else {
            Self.logger.error("update failed to encode settings")
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }
}

extension MenuBarSettingsStore: MenuBarSettingsStoring {
    var settingsPublisher: AnyPublisher<MenuBarDisplaySettings, Never> {
        $settings.eraseToAnyPublisher()
    }
}
