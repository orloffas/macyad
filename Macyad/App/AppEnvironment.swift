import Foundation
import MacyadCore
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let rcloneLocator: RcloneLocating
    let statusService: StatusService
    let onboardingService: OnboardingServicing
    let onboardingViewModel: OnboardingViewModel
    let pairRepository: PairRepository
    let activityRepository: ActivityRepository
    let pairDetailViewModel: PairDetailViewModel

    init(
        paths: AppPaths,
        rcloneLocator: RcloneLocating,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing,
        pairRepository: PairRepository,
        activityRepository: ActivityRepository
    ) {
        self.paths = paths
        self.rcloneLocator = rcloneLocator
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.pairRepository = pairRepository
        self.activityRepository = activityRepository
        self.onboardingViewModel = OnboardingViewModel(
            service: onboardingService,
            pasteboard: PasteboardBridge()
        )
        self.pairDetailViewModel = PairDetailViewModel(activityRepository: activityRepository)
    }

    static func bootstrap() throws -> AppEnvironment {
        let paths = try AppPaths.live()
        let rcloneLocator = RcloneLocator()
        let onboardingService = OnboardingService(locator: rcloneLocator, paths: paths)
        let pairRepository = PairRepository(paths: paths)
        let activityRepository = ActivityRepository(paths: paths)
        return .init(
            paths: paths,
            rcloneLocator: rcloneLocator,
            onboardingService: onboardingService,
            pairRepository: pairRepository,
            activityRepository: activityRepository
        )
    }
}
