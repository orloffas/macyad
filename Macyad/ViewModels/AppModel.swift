import Foundation
import MacyadCore
import Observation

@MainActor
@Observable
final class AppModel {
    var route: AppRoute = .onboarding
    var isCreatePairSheetPresented = false
    var isInspectorVisible = true
    var selectedPairID: UUID?
    var onboardingState = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: ""
    )
    var pairs: [SyncPair] = []
    var statusSummary = MenuBarSummary(title: "Setup required", alarmCount: 0, warningCount: 0)
    var openMainWindow: () -> Void = {}
    var runSyncNowForSelectedPair: () -> Void = {}
    var runCheckForSelectedPair: () -> Void = {}
    var runPullForSelectedPair: () -> Void = {}

    var selectedPair: SyncPair? {
        pairs.first { $0.id == selectedPairID }
    }

    func refreshStatusSummary(using service: StatusService) {
        statusSummary = service.makeSummary(onboardingStep: onboardingState.step, pairs: pairs)
    }
}
