import Combine
import Foundation
import MacyadCore

@MainActor
final class AppEnvironment: ObservableObject {
    private enum BackgroundSyncBootstrapError: LocalizedError {
        case rcloneUnavailable

        var errorDescription: String? {
            switch self {
            case .rcloneUnavailable:
                AppCopy.current.backgroundSyncRcloneUnavailable
            }
        }
    }

    private struct StubRcloneLocator: RcloneLocating {
        let location: String?

        func locate() async throws -> String? {
            location
        }
    }

    private struct StubOnboardingService: OnboardingServicing {
        let state: OnboardingState

        func refresh(pairCount: Int) async throws -> OnboardingState {
            var state = state
            state.pairsCount = pairCount
            return state
        }
    }

    private struct NoopLoginItemService: LoginItemControlling {
        func setEnabled(_ enabled: Bool) throws {}
    }

    private struct NoopUserNotificationClient: UserNotificationControlling {
        func authorizationStatus() async -> NotificationAuthorizationStatus { .authorized }
        func requestAuthorization() async throws -> NotificationAuthorizationStatus { .authorized }
        func send(title: String, body: String, routeToken: ActivityRouteToken?) async throws {}
        func sendTestNotification() async throws {}
    }

    let launchMode: AppLaunchMode
    /// When this process came up. Used to tell journal entries left behind by
    /// a previous launch from ones this launch is still working on.
    let launchedAt = Date()
    let paths: AppPaths
    let rcloneLocator: RcloneLocating
    let statusService: StatusService
    let onboardingService: OnboardingServicing
    let onboardingViewModel: OnboardingViewModel
    let folderOpener: FolderOpening
    let pairRepository: PairRepository
    let accountRepository: AccountRepository
    let conflictStateRepository: PairConflictStateRepository
    let preferencesStore: AppPreferencesStore
    let settingsViewModel: SettingsViewModel
    let activityRepository: ActivityRepository
    let pairDetailViewModel: PairDetailViewModel
    let overviewViewModel: OverviewViewModel
    let notificationClient: UserNotificationControlling
    let operationCoordinator: SerialOperationCoordinator

    init(
        launchMode: AppLaunchMode,
        paths: AppPaths,
        rcloneLocator: RcloneLocating,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing,
        pairRepository: PairRepository,
        accountRepository: AccountRepository,
        conflictStateRepository: PairConflictStateRepository,
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling,
        activityRepository: ActivityRepository,
        notificationClient: UserNotificationControlling,
        operationCoordinator: SerialOperationCoordinator = SerialOperationCoordinator()
    ) {
        self.launchMode = launchMode
        self.paths = paths
        self.rcloneLocator = rcloneLocator
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.pairRepository = pairRepository
        self.accountRepository = accountRepository
        self.conflictStateRepository = conflictStateRepository
        self.preferencesStore = preferencesStore
        self.activityRepository = activityRepository
        self.notificationClient = notificationClient
        self.operationCoordinator = operationCoordinator
        self.onboardingViewModel = OnboardingViewModel(
            service: onboardingService,
            pasteboard: PasteboardBridge()
        )
        self.folderOpener = FinderFolderOpenerBridge()
        self.settingsViewModel = SettingsViewModel(
            preferencesStore: preferencesStore,
            loginItemService: loginItemService,
            accountRepository: accountRepository,
            pairRepository: pairRepository,
            notificationClient: notificationClient,
            paths: paths,
            pasteboard: PasteboardBridge(),
            filePicker: ConfigurationFilePanelBridge()
        )
        self.pairDetailViewModel = PairDetailViewModel()
        self.overviewViewModel = OverviewViewModel()
    }

    static func bootstrap(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> AppEnvironment {
        let launchMode = AppLaunchMode(arguments: arguments)
        let paths = try makePaths(for: launchMode)
        let rcloneLocator: RcloneLocating

        if launchMode.usesEphemeralPaths {
            rcloneLocator = StubRcloneLocator(location: launchMode.stubbedRcloneLocation)
        } else {
            rcloneLocator = RcloneLocator()
        }

        let onboardingService: OnboardingServicing

        if launchMode == .uiTestReadyState {
            onboardingService = StubOnboardingService(
                state: OnboardingState(
                    step: .createFirstPair,
                    rcloneLocation: launchMode.stubbedRcloneLocation,
                    brewInstallCommand: "brew install rclone",
                    remoteCreateCommand: "",
                    configPath: paths.rcloneConfigFile.path
                )
            )
        } else {
            onboardingService = OnboardingService(locator: rcloneLocator, paths: paths)
        }

        if let seededLanguage = launchMode.seededSampleLanguage {
            try seedSamplePairs(at: paths, language: seededLanguage)
        }

        let pairRepository = PairRepository(paths: paths)
        let accountRepository = AccountRepository(paths: paths)


        let conflictStateRepository = PairConflictStateRepository(paths: paths)
        let preferencesStore = AppPreferencesStore(paths: paths)
        let activityRepository = ActivityRepository(paths: paths)
        return .init(
            launchMode: launchMode,
            paths: paths,
            rcloneLocator: rcloneLocator,
            onboardingService: onboardingService,
            pairRepository: pairRepository,
            accountRepository: accountRepository,
            conflictStateRepository: conflictStateRepository,
            preferencesStore: preferencesStore,
            loginItemService: launchMode.usesEphemeralPaths ? NoopLoginItemService() : LoginItemService(),
            activityRepository: activityRepository,
            notificationClient: launchMode.usesEphemeralPaths ? NoopUserNotificationClient() : UserNotificationClient()
        )
    }

    func makeBackgroundSyncController(
        stateDidChange: @escaping BackgroundSyncController.StateDidChange,
        scheduledSyncLifecycle: ScheduledSyncLifecycle = .noop
    ) -> BackgroundSyncController {
        let scheduler = SchedulerService(syncServiceProvider: { [rcloneLocator, paths = self.paths] in
            guard let executablePath = try await rcloneLocator.locate() else {
                throw BackgroundSyncBootstrapError.rcloneUnavailable
            }

            return SyncService(
                processClient: RcloneProcessClient(executablePath: executablePath),
                configPath: paths.rcloneConfigFile.path,
                excludeFileStore: PersistentRcloneExcludeFileStore(paths: paths),
                baselineRepository: self.conflictStateRepository,
                operationInspector: SystemRcloneOperationInspector()
            )
        }, operationCoordinator: operationCoordinator)

        return BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairRepository,
            preferencesStore: preferencesStore,
            activityStore: activityRepository,
            notificationClient: notificationClient,
            stateDidChange: stateDidChange,
            scheduledSyncLifecycle: scheduledSyncLifecycle
        )
    }

    func reconcileAccountsAndPairs(pairs: [SyncPair]) async throws -> (pairs: [SyncPair], accounts: [YandexAccount]) {
        let storedAccounts = try await accountRepository.load()
        let remoteNames = RcloneConfigInspector(configURL: paths.rcloneConfigFile).remoteNames()
        let reconciled = AccountService().reconcileAccounts(
            storedAccounts: storedAccounts,
            pairs: pairs,
            configPath: paths.rcloneConfigFile.path,
            configRemoteNames: remoteNames
        )

        if reconciled.didMutate {
            try await accountRepository.save(reconciled.accounts)
            if reconciled.pairs != pairs {
                try await pairRepository.save(reconciled.pairs)
            }
        }

        return (reconciled.pairs, reconciled.accounts)
    }

    /// Writes a fixed demonstration configuration so UI tests can exercise the
    /// panes that only do anything once pairs exist, and so the README
    /// screenshots show a populated app. Ephemeral paths only — this must never
    /// touch a real installation.
    ///
    /// Everything here is invented: the folder paths belong to no real account
    /// and the remote token is a literal placeholder. The state is deliberately
    /// varied — every auto-sync mode, every severity — because a screenshot of
    /// four identical healthy rows explains nothing.
    private static func seedSamplePairs(at paths: AppPaths, language: AppLanguage) throws {
        // Set before any copy is read: the seeded journal messages are built
        // from AppCopy, and the screenshots are taken in both languages.
        AppLanguageState.update(language)
        let copy = AppCopy.current

        let personalAccountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let workAccountID = UUID(uuidString: "11111111-1111-1111-1111-111111111112")!
        let accounts = [
            YandexAccount(
                id: personalAccountID,
                displayName: "macyad-yandex",
                remoteName: "macyad-yandex",
                configPath: paths.rcloneConfigFile.path,
                isManaged: false,
                createdAt: Date(timeIntervalSince1970: 1_716_000_000)
            ),
            YandexAccount(
                id: workAccountID,
                displayName: "macyad-yandex-work",
                remoteName: "macyad-yandex-work",
                configPath: paths.rcloneConfigFile.path,
                isManaged: true,
                createdAt: Date(timeIntervalSince1970: 1_717_000_000)
            )
        ]

        let now = Date()
        let minute = 60.0
        let hour = 3_600.0
        let samples: [(name: String, account: UUID, mode: AutoSyncMode, severity: Severity, lastSync: TimeInterval, minutes: Int)] = [
            ("Documents", personalAccountID, .push, .healthy, 8 * minute, 15),
            ("Photos", personalAccountID, .pull, .healthy, 41 * minute, 60),
            ("Projects", workAccountID, .push, .warning, 3 * hour, 30),
            ("Music", personalAccountID, .off, .healthy, 26 * hour, 15)
        ]
        let pairs = samples.enumerated().map { index, sample in
            SyncPair(
                id: UUID(uuidString: "2222222\(index)-2222-2222-2222-222222222222")!,
                name: sample.name,
                localFolderBookmark: Data("bookmark".utf8),
                localFolderDisplayPath: "/Users/alex/Yandex/\(sample.name)",
                remotePath: "\(sample.account == workAccountID ? "macyad-yandex-work" : "macyad-yandex"):/\(sample.name)",
                accountID: sample.account,
                conflictPolicy: .block,
                scheduleMinutes: sample.minutes,
                deletePolicy: .mirrorToYandex,
                lastKnownSeverity: sample.severity,
                lastSyncAt: now.addingTimeInterval(-sample.lastSync),
                autoSyncMode: sample.mode
            )
        }

        // A blocked run carries one issue per mismatched path, and a real pair
        // reaches several hundred. Seed that too: it is the size the panes are
        // actually asked to render, and an empty journal never exercises it.
        let issueNames = ["report", "invoice", "notes", "draft", "summary", "handout"]
        let issues = (0 ..< 500).map { index in
            let path = "Quarter \(index / 125 + 1)/\(issueNames[index % issueNames.count])-\(index).pdf"
            return ActivityFileIssue(
                relativePath: path,
                problemKind: .remoteOnlyChanged,
                differences: [.baselineMissing, .missingLocal],
                localSnapshot: nil,
                remoteSnapshot: PairSnapshotEntry(
                    path: path,
                    size: Int64(24_576 + index * 37),
                    modTime: now.addingTimeInterval(-Double(index) * minute),
                    md5: nil
                ),
                baselineSnapshot: nil,
                selectedDecision: .later
            )
        }

        // One blocked run with a reviewable issue set, and a normal-looking
        // journal around it. A screenshot of twenty identical warnings would
        // misrepresent what the app usually shows.
        let blockedEvent = ActivityEvent(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            date: now.addingTimeInterval(-3 * hour),
            message: copy.scheduledSyncBlockedTitle(.push),
            severity: .warning,
            pairID: pairs[2].id,
            details: copy.baselineMissingBlockedSummary,
            issueSet: ActivityIssueSet(issues: issues)
        )
        let routine: [(TimeInterval, String, Severity, Int)] = [
            (8 * minute, copy.scheduledSyncCompleted(.push), .healthy, 0),
            (23 * minute, copy.manualCheckCompleted, .healthy, 0),
            (41 * minute, copy.scheduledSyncCompleted(.pull), .healthy, 1),
            (55 * minute, copy.manualSyncCompleted, .healthy, 0),
            (78 * minute, copy.manualPullCompleted, .healthy, 1),
            (2 * hour, copy.scheduledSyncCompleted(.push), .healthy, 0),
            (4 * hour, copy.manualCheckWarningDetected, .warning, 1),
            (6 * hour, copy.scheduledSyncCompleted(.pull), .healthy, 1),
            (9 * hour, copy.manualSyncCompleted, .healthy, 3),
            (26 * hour, copy.manualSyncCompleted, .healthy, 3)
        ]
        let events = [blockedEvent] + routine.map { age, message, severity, pairIndex in
            ActivityEvent(
                id: UUID(),
                date: now.addingTimeInterval(-age),
                message: message,
                severity: severity,
                pairID: pairs[pairIndex].id
            )
        }

        // A configured remote, so the onboarding pane reaches its completed
        // state — the branch that only exists when pairs are present. The token
        // is a placeholder, not a credential.
        try """
        [macyad-yandex]
        type = yandex
        token = {"access_token":"seeded","token_type":"OAuth"}

        [macyad-yandex-work]
        type = yandex
        token = {"access_token":"seeded","token_type":"OAuth"}

        """.write(to: paths.rcloneConfigFile, atomically: true, encoding: .utf8)

        let preferences = AppPreferences(
            selectedLanguage: language.rawValue,
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: false
        )

        // Written synchronously, before anything reads them: the repositories
        // are actors, and a Task here would race the first load.
        let encoder = JSONEncoder()
        try encoder.encode(accounts).write(to: paths.accountsFile, options: .atomic)
        try encoder.encode(pairs).write(to: paths.pairsFile, options: .atomic)
        try encoder.encode(events).write(to: paths.activityFile, options: .atomic)
        try encoder.encode(preferences).write(to: paths.preferencesFile, options: .atomic)
    }

    private static func makePaths(
        for launchMode: AppLaunchMode,
        fileManager: FileManager = .default
    ) throws -> AppPaths {
        guard launchMode.usesEphemeralPaths else {
            return try AppPaths.live(fileManager: fileManager)
        }

        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("macyad-ui-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        var paths = AppPaths.makeForTesting(rootURL: rootURL)

        if launchMode.seededSampleLanguage != nil {
            // Where the workspace would be on a real installation. The actual
            // directory is a throwaway one, and its `/var/folders/…` path is
            // noise in a README screenshot.
            paths.workspaceDisplayPath = "/Users/alex/Library/Application Support/MacYaD/Workspace"
        }

        try fileManager.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.workspaceRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(
            at: paths.rcloneConfigFile.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(at: paths.rcloneFiltersDirectory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.conflictStateDirectory, withIntermediateDirectories: true, attributes: nil)

        return paths
    }
}
