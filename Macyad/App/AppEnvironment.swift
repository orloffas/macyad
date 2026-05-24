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

    init(
        paths: AppPaths,
        statusService: StatusService = StatusService(),
        onboardingService: OnboardingServicing
    ) {
        self.paths = paths
        self.statusService = statusService
        self.onboardingService = onboardingService
        self.onboardingViewModel = OnboardingViewModel(
            service: onboardingService,
            pasteboard: PasteboardBridge()
        )
    }

    static func bootstrap() throws -> AppEnvironment {
        let paths = try AppPaths.live()
        let onboardingService = OnboardingService(locator: RcloneLocator(), paths: paths)
        return .init(paths: paths, onboardingService: onboardingService)
    }
}
