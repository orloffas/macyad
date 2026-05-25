import Combine
import MacyadCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedLanguage = AppPreferences.defaults.selectedLanguage
    @Published var launchAtLogin = AppPreferences.defaults.launchAtLoginEnabled
    @Published var defaultScheduleMinutes = AppPreferences.defaults.defaultScheduleMinutes
    @Published var errorMessage: String?
    @Published var isRestartPromptPresented = false

    private let preferencesStore: AppPreferencesStore
    private let loginItemService: LoginItemControlling
    private var didLoad = false
    private var loadedLanguage = AppPreferences.defaults.selectedLanguage
    var languageDidChange: @MainActor (AppLanguage) -> Void = { _ in }

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
            let preferences = try await preferencesStore.load()
            apply(preferences)
            try loginItemService.setEnabled(preferences.launchAtLoginEnabled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSelectedLanguage(_ language: String) {
        guard selectedLanguage != language else {
            return
        }

        selectedLanguage = language
        isRestartPromptPresented = language != loadedLanguage
        languageDidChange(selectedAppLanguage)
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

    func dismissRestartPrompt() {
        isRestartPromptPresented = false
    }

    var selectedAppLanguage: AppLanguage {
        AppLanguage(code: selectedLanguage)
    }

    private func persist() async {
        do {
            try await preferencesStore.save(makePreferences())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ preferences: AppPreferences) {
        loadedLanguage = preferences.selectedLanguage
        selectedLanguage = preferences.selectedLanguage
        launchAtLogin = preferences.launchAtLoginEnabled
        defaultScheduleMinutes = preferences.defaultScheduleMinutes
        languageDidChange(preferences.appLanguage)
    }

    private func makePreferences() -> AppPreferences {
        AppPreferences(
            selectedLanguage: selectedLanguage,
            launchAtLoginEnabled: launchAtLogin,
            defaultScheduleMinutes: defaultScheduleMinutes
        )
    }
}
