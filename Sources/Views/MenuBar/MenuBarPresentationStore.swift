import Combine
import Foundation

@MainActor
final class MenuBarPresentationStore: ObservableObject {
    @Published private(set) var presentation: MenuBarPresentation

    private var cancellables = Set<AnyCancellable>()

    init(
        viewModel: MenuBarViewModel,
        settingsStore: MenuBarSettingsStore
    ) {
        presentation = MenuBarPresentation(
            viewState: viewModel.viewState,
            settings: settingsStore.settings
        )

        Publishers.CombineLatest(
            viewModel.$viewState,
            settingsStore.$settings
        )
        .map(MenuBarPresentation.init(viewState:settings:))
        .sink { [weak self] presentation in
            self?.presentation = presentation
        }
        .store(in: &cancellables)
    }
}
