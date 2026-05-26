import Combine
import MacyadCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedLanguage = AppPreferences.defaults.selectedLanguage
    @Published var launchAtLogin = AppPreferences.defaults.launchAtLoginEnabled
    @Published var defaultScheduleMinutes = AppPreferences.defaults.defaultScheduleMinutes
    @Published var accounts: [YandexAccount] = []
    @Published var newAccountDisplayName = ""
    @Published var newAccountRemoteName = ""
    @Published var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    @Published var lastNotificationAttempt: String?
    @Published var lastCopiedCommand: String?
    @Published var errorMessage: String?
    @Published var isRestartPromptPresented = false

    private let preferencesStore: AppPreferencesStore
    private let loginItemService: LoginItemControlling
    private let accountRepository: AccountRepository
    private let pairRepository: PairRepository
    private let notificationClient: UserNotificationControlling
    private let paths: AppPaths
    private let pasteboard: PasteboardWriting
    private let accountService = AccountService()
    private var didLoad = false
    private var loadedLanguage = AppPreferences.defaults.selectedLanguage
    var languageDidChange: @MainActor (AppLanguage) -> Void = { _ in }

    init(
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling,
        accountRepository: AccountRepository,
        pairRepository: PairRepository,
        notificationClient: UserNotificationControlling,
        paths: AppPaths,
        pasteboard: PasteboardWriting
    ) {
        self.preferencesStore = preferencesStore
        self.loginItemService = loginItemService
        self.accountRepository = accountRepository
        self.pairRepository = pairRepository
        self.notificationClient = notificationClient
        self.paths = paths
        self.pasteboard = pasteboard
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
            try await refreshAccounts()
            notificationStatus = await notificationClient.authorizationStatus()
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

    func addAccount() async {
        do {
            let account = try accountService.makeAccount(
                displayName: newAccountDisplayName,
                remoteName: newAccountRemoteName,
                configPath: paths.rcloneConfigFile.path,
                existingAccounts: accounts
            )
            var updatedAccounts = accounts
            updatedAccounts.append(account)
            try await accountRepository.save(updatedAccounts)
            accounts = try await accountRepository.load()
            newAccountDisplayName = ""
            newAccountRemoteName = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAccount(_ account: YandexAccount) async {
        do {
            let pairs = try await pairRepository.load()
            let updatedAccounts = try accountService.removeAccount(account, from: accounts, pairs: pairs)
            try await accountRepository.save(updatedAccounts)
            accounts = updatedAccounts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNewAccountDisplayName(_ value: String) {
        newAccountDisplayName = value
        if newAccountRemoteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newAccountRemoteName = AccountService.suggestedRemoteName(for: value, existingAccounts: accounts)
        }
    }

    func requestNotificationPermission() async {
        do {
            notificationStatus = try await notificationClient.requestAuthorization()
            lastNotificationAttempt = notificationStatusMessage(notificationStatus)
        } catch {
            errorMessage = error.localizedDescription
            lastNotificationAttempt = error.localizedDescription
        }
    }

    func sendTestNotification() async {
        do {
            try await notificationClient.sendTestNotification()
            notificationStatus = await notificationClient.authorizationStatus()
            lastNotificationAttempt = AppCopy.current.notificationsTestBody
        } catch {
            errorMessage = error.localizedDescription
            lastNotificationAttempt = error.localizedDescription
        }
    }

    func copy(_ command: String) {
        pasteboard.copy(command)
        lastCopiedCommand = command
    }

    func reconnectCommand(for account: YandexAccount) -> String {
        RcloneCommandBuilder.remoteReconnectCommand(configPath: account.configPath, remoteName: account.remoteName)
    }

    func recreateCommand(for account: YandexAccount) -> String {
        RcloneCommandBuilder.remoteCreateCommand(configPath: account.configPath, remoteName: account.remoteName)
    }

    func removeCommand(for account: YandexAccount) -> String {
        RcloneCommandBuilder.remoteDeleteCommand(configPath: account.configPath, remoteName: account.remoteName)
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

    private func refreshAccounts() async throws {
        let storedAccounts = try await accountRepository.load()
        let pairs = try await pairRepository.load()
        let configRemoteNames = RcloneConfigInspector(configURL: paths.rcloneConfigFile).remoteNames()
        let reconciled = accountService.reconcileAccounts(
            storedAccounts: storedAccounts,
            pairs: pairs,
            configPath: paths.rcloneConfigFile.path,
            configRemoteNames: configRemoteNames
        )

        if reconciled.didMutate {
            try await accountRepository.save(reconciled.accounts)
            try await pairRepository.save(reconciled.pairs)
        }

        accounts = reconciled.accounts
    }

    private func notificationStatusMessage(_ status: NotificationAuthorizationStatus) -> String {
        let copy = AppCopy.current
        return switch status {
        case .authorized:
            copy.notificationsStatusAuthorized
        case .denied:
            copy.notificationsStatusDenied
        case .notDetermined:
            copy.notificationsStatusNotDetermined
        case .provisional:
            copy.notificationsStatusProvisional
        case .ephemeral:
            copy.notificationsStatusEphemeral
        case .unknown:
            copy.notificationsStatusUnknown
        }
    }

    private func makePreferences() -> AppPreferences {
        AppPreferences(
            selectedLanguage: selectedLanguage,
            launchAtLoginEnabled: launchAtLogin,
            defaultScheduleMinutes: defaultScheduleMinutes
        )
    }
}
