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

        if launchMode.seedsSamplePairs {
            try seedSamplePairs(at: paths)
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

    /// Writes a small, fixed configuration so UI tests can exercise the panes
    /// that only do anything once pairs exist. Ephemeral paths only — this must
    /// never touch a real installation.
    private static func seedSamplePairs(at paths: AppPaths) throws {
        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let account = YandexAccount(
            id: accountID,
            displayName: "macyad-yandex",
            remoteName: "macyad-yandex",
            configPath: paths.rcloneConfigFile.path,
            isManaged: false,
            createdAt: Date(timeIntervalSince1970: 1_716_000_000)
        )
        let pairs = ["Documents", "Photos"].enumerated().map { index, name in
            SyncPair(
                id: UUID(uuidString: "2222222\(index)-2222-2222-2222-222222222222")!,
                name: name,
                localFolderBookmark: Data("bookmark".utf8),
                localFolderDisplayPath: paths.workspaceRoot.appendingPathComponent(name).path,
                remotePath: "macyad-yandex:/\(name)",
                accountID: accountID,
                conflictPolicy: .block,
                scheduleMinutes: 15,
                deletePolicy: .mirrorToYandex,
                lastKnownSeverity: index == 0 ? .healthy : .warning,
                autoSyncMode: index == 0 ? .push : .off
            )
        }

        // A blocked run carries one issue per mismatched path, and a real pair
        // reaches several hundred. Seed that too: it is the size the panes are
        // actually asked to render, and an empty journal never exercises it.
        let issues = (0 ..< 500).map { index in
            ActivityFileIssue(
                relativePath: "Folder \(index / 50)/file-\(index).pdf",
                problemKind: .remoteOnlyChanged,
                differences: [.baselineMissing, .missingLocal],
                localSnapshot: nil,
                remoteSnapshot: PairSnapshotEntry(
                    path: "Folder \(index / 50)/file-\(index).pdf",
                    size: 991,
                    modTime: Date(timeIntervalSince1970: 1_716_000_000),
                    md5: nil
                ),
                baselineSnapshot: nil,
                selectedDecision: .later
            )
        }
        let events = (0 ..< 20).map { index in
            ActivityEvent(
                id: UUID(),
                date: Date().addingTimeInterval(Double(index * -60)),
                message: "Scheduled Push to Yandex blocked",
                severity: .warning,
                pairID: pairs[0].id,
                details: "The agreed baseline is missing. Push/Pull is blocked until the current state is reconciled.",
                issueSet: ActivityIssueSet(issues: issues)
            )
        }

        // A configured remote, so the onboarding pane reaches its completed
        // state — the branch that only exists when pairs are present.
        try """
        [macyad-yandex]
        type = yandex
        token = {"access_token":"seeded","token_type":"OAuth"}

        """.write(to: paths.rcloneConfigFile, atomically: true, encoding: .utf8)

        // Written synchronously, before anything reads them: the repositories
        // are actors, and a Task here would race the first load.
        let encoder = JSONEncoder()
        try encoder.encode([account]).write(to: paths.accountsFile, options: .atomic)
        try encoder.encode(pairs).write(to: paths.pairsFile, options: .atomic)
        try encoder.encode(events).write(to: paths.activityFile, options: .atomic)
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
        let paths = AppPaths.makeForTesting(rootURL: rootURL)

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
