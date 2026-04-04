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
            Self.logger.debug(
                """
                init loaded persisted settings \
                watchlist=\(settings.watchlist.count, privacy: .public) \
                fields=\(Self.visibleFieldsDescription(settings), privacy: .public)
                """
            )
        } else {
            self.settings = .default
            Self.logger.debug("init using default settings")
        }
    }

    func update(_ settings: MenuBarDisplaySettings) {
        let previousSettings = self.settings
        self.settings = settings
        Self.logger.debug(
            """
            update watchlist=\(settings.watchlist.count, privacy: .public) \
            fields=\(Self.visibleFieldsDescription(settings), privacy: .public) \
            changed=\(previousSettings != settings, privacy: .public)
            """
        )

        guard let data = try? JSONEncoder().encode(settings) else {
            Self.logger.error("update failed to encode settings")
            return
        }
        userDefaults.set(data, forKey: storageKey)
        Self.logger.debug("update persisted settings bytes=\(data.count, privacy: .public)")
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

extension MenuBarSettingsStore: MenuBarSettingsStoring {
    var settingsPublisher: AnyPublisher<MenuBarDisplaySettings, Never> {
        $settings.eraseToAnyPublisher()
    }
}
