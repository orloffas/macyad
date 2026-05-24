import Foundation
import MacyadCore
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let statusService: StatusService
    let onboardingService: OnboardingServicing
    let onboardingViewModel: OnboardingViewModel
    let pairRepository: PairRepository

    init(
        paths: AppPaths,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing,
        pairRepository: PairRepository
    ) {
        self.paths = paths
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.pairRepository = pairRepository
        self.onboardingViewModel = OnboardingViewModel(
            service: onboardingService,
            pasteboard: PasteboardBridge()
        )
    }

    static func bootstrap() throws -> AppEnvironment {
        let paths = try AppPaths.live()
        let onboardingService = OnboardingService(locator: RcloneLocator(), paths: paths)
        let pairRepository = PairRepository(paths: paths)
        return .init(paths: paths, onboardingService: onboardingService, pairRepository: pairRepository)
    }
}
