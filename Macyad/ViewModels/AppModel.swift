import Foundation
import MacyadCore
import Observation

@MainActor
@Observable
final class AppModel {
    var sidebarSelection: SidebarSelection = .route(.onboarding)
    var isCreatePairSheetPresented = false
    var isInspectorVisible = true
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

    var route: AppRoute {
        get {
            if case let .route(route) = sidebarSelection {
                return route
            }

            return .overview
        }
        set {
            sidebarSelection = .route(newValue)
        }
    }

    var selectedPairID: UUID? {
        get {
            if case let .pair(id) = sidebarSelection {
                return id
            }

            return nil
        }
        set {
            if let newValue {
                sidebarSelection = .pair(newValue)
            } else {
                sidebarSelection = .route(.overview)
            }
        }
    }

    var selectedPair: SyncPair? {
        pairs.first { $0.id == selectedPairID }
    }

    func refreshStatusSummary(using service: StatusService) {
        statusSummary = service.makeSummary(onboardingStep: onboardingState.step, pairs: pairs)
    }
}
