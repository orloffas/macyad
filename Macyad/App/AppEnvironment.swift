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

        func refresh() async throws -> OnboardingState {
            state
        }
    }

    private struct NoopLoginItemService: LoginItemControlling {
        func setEnabled(_ enabled: Bool) throws {}
    }

    private struct NoopUserNotificationClient: UserNotificationSending {
        func send(title: String, body: String) async throws {}
    }

    let launchMode: AppLaunchMode
    let paths: AppPaths
    let rcloneLocator: RcloneLocating
    let statusService: StatusService
    let onboardingService: OnboardingServicing
    let onboardingViewModel: OnboardingViewModel
    let pairRepository: PairRepository
    let preferencesStore: AppPreferencesStore
    let settingsViewModel: SettingsViewModel
    let activityRepository: ActivityRepository
    let pairDetailViewModel: PairDetailViewModel
    let notificationClient: UserNotificationSending

    init(
        launchMode: AppLaunchMode,
        paths: AppPaths,
        rcloneLocator: RcloneLocating,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing,
        pairRepository: PairRepository,
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling,
        activityRepository: ActivityRepository,
        notificationClient: UserNotificationSending
    ) {
        self.launchMode = launchMode
        self.paths = paths
        self.rcloneLocator = rcloneLocator
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.pairRepository = pairRepository
        self.preferencesStore = preferencesStore
        self.activityRepository = activityRepository
        self.notificationClient = notificationClient
        self.onboardingViewModel = OnboardingViewModel(
            service: onboardingService,
            pasteboard: PasteboardBridge()
        )
        self.settingsViewModel = SettingsViewModel(
            preferencesStore: preferencesStore,
            loginItemService: loginItemService
        )
        self.pairDetailViewModel = PairDetailViewModel(activityRepository: activityRepository)
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
                    remoteCreateCommand: ""
                )
            )
        } else {
            onboardingService = OnboardingService(locator: rcloneLocator, paths: paths)
        }

        let pairRepository = PairRepository(paths: paths)
        let preferencesStore = AppPreferencesStore(paths: paths)
        let activityRepository = ActivityRepository(paths: paths)
        return .init(
            launchMode: launchMode,
            paths: paths,
            rcloneLocator: rcloneLocator,
            onboardingService: onboardingService,
            pairRepository: pairRepository,
            preferencesStore: preferencesStore,
            loginItemService: launchMode.usesEphemeralPaths ? NoopLoginItemService() : LoginItemService(),
            activityRepository: activityRepository,
            notificationClient: launchMode.usesEphemeralPaths ? NoopUserNotificationClient() : UserNotificationClient()
        )
    }

    func makeBackgroundSyncController(
        stateDidChange: @escaping BackgroundSyncController.StateDidChange
    ) -> BackgroundSyncController {
        let scheduler = SchedulerService(syncServiceProvider: { [rcloneLocator, configPath = paths.rcloneConfigFile.path] in
            guard let executablePath = try await rcloneLocator.locate() else {
                throw BackgroundSyncBootstrapError.rcloneUnavailable
            }

            return SyncService(
                processClient: RcloneProcessClient(executablePath: executablePath),
                configPath: configPath
            )
        })

        return BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairRepository,
            activityStore: activityRepository,
            notificationClient: notificationClient,
            stateDidChange: stateDidChange
        )
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

        return paths
    }
}
