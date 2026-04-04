import Combine

@MainActor
protocol MenuBarSettingsStoring: AnyObject {
    var settings: MenuBarDisplaySettings { get }
    var settingsPublisher: AnyPublisher<MenuBarDisplaySettings, Never> { get }

    func update(_ settings: MenuBarDisplaySettings)
}
