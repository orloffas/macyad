import Foundation
import MacyadCore
import Observation

@Observable
@MainActor
final class AppEnvironment {
    enum LaunchMode: Sendable, Equatable {
        case normal
        case uiTestOnboardingMissingRclone
        case uiTestReadyState

        init(arguments: [String]) {
            if arguments.contains("UITEST_ONBOARDING_MISSING_RCLONE") {
                self = .uiTestOnboardingMissingRclone
            } else if arguments.contains("UITEST_READY_STATE") {
                self = .uiTestReadyState
            } else {
                self = .normal
            }
        }

        var shouldForceForegroundWindow: Bool {
            switch self {
            case .normal:
                false
            case .uiTestOnboardingMissingRclone, .uiTestReadyState:
                true
            }
        }

        var stubbedRcloneLocation: String? {
            switch self {
            case .normal, .uiTestOnboardingMissingRclone:
                nil
            case .uiTestReadyState:
                "/opt/homebrew/bin/rclone"
            }
        }

        var usesEphemeralPaths: Bool {
            switch self {
            case .normal:
                false
            case .uiTestOnboardingMissingRclone, .uiTestReadyState:
                true
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

    let launchMode: LaunchMode
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

    init(
        launchMode: LaunchMode,
        paths: AppPaths,
        rcloneLocator: RcloneLocating,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing,
        pairRepository: PairRepository,
        preferencesStore: AppPreferencesStore,
        loginItemService: LoginItemControlling,
        activityRepository: ActivityRepository
    ) {
        self.launchMode = launchMode
        self.paths = paths
        self.rcloneLocator = rcloneLocator
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.pairRepository = pairRepository
        self.preferencesStore = preferencesStore
        self.activityRepository = activityRepository
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
        let launchMode = LaunchMode(arguments: arguments)
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
            activityRepository: activityRepository
        )
    }

    private static func makePaths(
        for launchMode: LaunchMode,
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

        return paths
    }
}
