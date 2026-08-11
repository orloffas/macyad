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
            pasteboard: PasteboardBridge()
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
