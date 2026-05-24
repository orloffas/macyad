import Combine
import MacyadCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedLanguage = AppPreferences.defaults.selectedLanguage
    @Published var launchAtLogin = AppPreferences.defaults.launchAtLoginEnabled
    @Published var defaultScheduleMinutes = AppPreferences.defaults.defaultScheduleMinutes
    @Published var errorMessage: String?

    private let preferencesStore: AppPreferencesStore
    private let loginItemService: LoginItemControlling
    private var didLoad = false

    init(
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling
    ) {
        self.preferencesStore = preferencesStore
        self.loginItemService = loginItemService
    }

    func loadIfNeeded() async {
        guard !didLoad else {
            return
        }

        didLoad = true

        do {
            apply(try await preferencesStore.load())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSelectedLanguage(_ language: String) {
        selectedLanguage = language
        Task { await persist() }
    }

    func updateDefaultScheduleMinutes(_ minutes: Int) {
        defaultScheduleMinutes = minutes
        Task { await persist() }
    }

    func updateLaunchAtLogin(_ enabled: Bool) async {
        let previousValue = launchAtLogin
        launchAtLogin = enabled

        do {
            try loginItemService.setEnabled(enabled)
            try await preferencesStore.save(makePreferences())
        } catch {
            launchAtLogin = previousValue
            errorMessage = error.localizedDescription
        }
    }

    private func persist() async {
        do {
            try await preferencesStore.save(makePreferences())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ preferences: AppPreferences) {
        selectedLanguage = preferences.selectedLanguage
        launchAtLogin = preferences.launchAtLoginEnabled
        defaultScheduleMinutes = preferences.defaultScheduleMinutes
    }

    private func makePreferences() -> AppPreferences {
        AppPreferences(
            selectedLanguage: selectedLanguage,
            launchAtLoginEnabled: launchAtLogin,
            defaultScheduleMinutes: defaultScheduleMinutes
        )
    }
}
