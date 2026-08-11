import Combine
import Foundation
import MacyadCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedLanguage = AppPreferences.defaults.selectedLanguage
    @Published var launchAtLogin = AppPreferences.defaults.launchAtLoginEnabled
    @Published var defaultScheduleMinutes = AppPreferences.defaults.defaultScheduleMinutes
    @Published var isGlobalSchedulerPaused = AppPreferences.defaults.isGlobalSchedulerPaused
    @Published var accounts: [YandexAccount] = []
    @Published var newAccountDisplayName = ""
    @Published var newAccountRemoteName = ""
    @Published var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    @Published var lastNotificationAttempt: String?
    @Published var lastCopiedCommand: String?
    @Published var errorMessage: String?
    @Published var isRestartPromptPresented = false
    @Published var pendingImportPlan: ConfigurationImportPlan?
    @Published var importSummary: String?
    @Published var importIssues: [String] = []

    private let preferencesStore: AppPreferencesStore
    private let loginItemService: LoginItemControlling
    private let accountRepository: AccountRepository
    private let pairRepository: PairRepository
    private let notificationClient: UserNotificationControlling
    private let paths: AppPaths
    private let pasteboard: PasteboardWriting
    private let filePicker: ConfigurationFilePicking
    private let accountService = AccountService()
    private let transferService = ConfigurationTransferService()
    private var didLoad = false
    private var loadedLanguage = AppPreferences.defaults.selectedLanguage
    var languageDidChange: @MainActor (AppLanguage) -> Void = { _ in }
    var preferencesDidChange: @MainActor (AppPreferences) -> Void = { _ in }
    var configurationDidImport: @MainActor ([SyncPair], [YandexAccount]) -> Void = { _, _ in }

    init(
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling,
        accountRepository: AccountRepository,
        pairRepository: PairRepository,
        notificationClient: UserNotificationControlling,
        paths: AppPaths,
        pasteboard: PasteboardWriting,
        filePicker: ConfigurationFilePicking
    ) {
        self.preferencesStore = preferencesStore
        self.loginItemService = loginItemService
        self.accountRepository = accountRepository
        self.pairRepository = pairRepository
        self.notificationClient = notificationClient
        self.paths = paths
        self.pasteboard = pasteboard
        self.filePicker = filePicker
    }

    func exportConfiguration(pairs: [SyncPair]) async {
        guard let destination = filePicker.pickExportDestination() else {
            return
        }

        let export = transferService.makeExport(
            preferences: makePreferences(),
            accounts: accounts,
            pairs: pairs
        )

        do {
            try transferService.encode(export).write(to: destination, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = AppCopy.current.configurationExportFailed(error.localizedDescription)
        }
    }

    /// Reads and validates the file, then stops: replacing the configuration
    /// is the user's call, so the plan waits for a confirmation.
    func prepareConfigurationImport() async {
        guard let source = filePicker.pickImportSource() else {
            return
        }

        do {
            let export = try transferService.decodeExport(from: Data(contentsOf: source))
            let remoteNames = RcloneConfigInspector(configURL: paths.rcloneConfigFile).remoteNames()

            pendingImportPlan = try transferService.prepareImport(
                export,
                configPath: paths.rcloneConfigFile.path,
                availableRemoteNames: remoteNames,
                folderExists: { path in
                    // Readability, not just existence: a folder this app has
                    // no TCC grant for is present but unusable, and a bookmark
                    // made for it would hide the problem until rclone failed.
                    var isDirectory: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                    return exists && isDirectory.boolValue && FileManager.default.isReadableFile(atPath: path)
                },
                bookmarkForPath: { filePicker.bookmark(forFolderAt: $0) }
            )
            errorMessage = nil
        } catch {
            errorMessage = AppCopy.current.configurationImportFailed(error.localizedDescription)
        }
    }

    func cancelConfigurationImport() {
        pendingImportPlan = nil
    }

    func applyPendingConfigurationImport() async {
        guard let plan = pendingImportPlan else {
            return
        }

        pendingImportPlan = nil
        let copy = AppCopy.current

        do {
            // Order matters, because these are three separate atomic writes and
            // the background cycle reads pairs and preferences from disk every
            // minute. Pausing first, then landing the switched-off pairs, means
            // every intermediate state on disk is one where nothing syncs. The
            // reverse order can leave the old, active pairs running against
            // freshly replaced accounts.
            try await preferencesStore.save(plan.preferences)
            try await pairRepository.save(plan.pairs)
            try await accountRepository.save(plan.accounts)

            accounts = try await accountRepository.load()
            apply(plan.preferences)
            try? loginItemService.setEnabled(plan.preferences.launchAtLoginEnabled)
            preferencesDidChange(plan.preferences)
            configurationDidImport(plan.pairs, plan.accounts)

            importIssues = plan.issues.map { issue in
                switch issue.kind {
                case let .unusableLocalFolder(path):
                    copy.configurationImportUnusableFolderIssue(pair: issue.pairName, path: path)
                case let .missingRemote(name):
                    copy.configurationImportMissingRemoteIssue(pair: issue.pairName, remote: name)
                case .missingAccount:
                    copy.configurationImportMissingAccountIssue(pair: issue.pairName)
                }
            }
            importSummary = copy.configurationImportSummary(
                pairs: plan.pairs.count,
                accounts: plan.accounts.count
            )
            errorMessage = nil
        } catch {
            // Part of the import may have landed. Show what is actually on
            // disk rather than the state the UI happened to be holding.
            accounts = (try? await accountRepository.load()) ?? accounts
            if let storedPreferences = try? await preferencesStore.load() {
                apply(storedPreferences)
                preferencesDidChange(storedPreferences)
            }
            if let storedPairs = try? await pairRepository.load() {
                configurationDidImport(storedPairs, accounts)
            }
            errorMessage = copy.configurationImportFailed(error.localizedDescription)
        }
    }

    func dismissImportSummary() {
        importSummary = nil
        importIssues = []
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
        preferencesDidChange(makePreferences())
        Task { await persist() }
    }

    func updateDefaultScheduleMinutes(_ minutes: Int) {
        defaultScheduleMinutes = minutes
        preferencesDidChange(makePreferences())
        Task { await persist() }
    }

    func updateLaunchAtLogin(_ enabled: Bool) async {
        let previousValue = launchAtLogin
        launchAtLogin = enabled

        do {
            try loginItemService.setEnabled(enabled)
            try await preferencesStore.save(makePreferences())
            preferencesDidChange(makePreferences())
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

    func accountRemovalState(for account: YandexAccount, pairs: [SyncPair]) -> AccountRemovalState {
        accountService.removalState(for: account, pairs: pairs, copy: AppCopy.current)
    }

    func removeAccount(_ account: YandexAccount, pairs: [SyncPair]) async {
        guard accountRemovalState(for: account, pairs: pairs).canRemove else {
            return
        }

        do {
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

    var currentPreferences: AppPreferences {
        makePreferences()
    }

    private func persist() async {
        do {
            try await preferencesStore.save(makePreferences())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateIsGlobalSchedulerPaused(_ paused: Bool) {
        isGlobalSchedulerPaused = paused
        preferencesDidChange(makePreferences())
        Task { await persist() }
    }

    private func apply(_ preferences: AppPreferences) {
        loadedLanguage = preferences.selectedLanguage
        selectedLanguage = preferences.selectedLanguage
        launchAtLogin = preferences.launchAtLoginEnabled
        defaultScheduleMinutes = preferences.defaultScheduleMinutes
        isGlobalSchedulerPaused = preferences.isGlobalSchedulerPaused
        languageDidChange(preferences.appLanguage)
        preferencesDidChange(preferences)
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
            defaultScheduleMinutes: defaultScheduleMinutes,
            isGlobalSchedulerPaused: isGlobalSchedulerPaused
        )
    }
}
