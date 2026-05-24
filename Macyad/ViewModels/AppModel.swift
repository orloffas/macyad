import Combine
import Foundation
import MacyadCore

@MainActor
final class AppModel: ObservableObject {
    @Published var sidebarSelection: SidebarSelection = .route(.onboarding)
    @Published var isCreatePairSheetPresented = false
    @Published var isInspectorVisible = true
    @Published var onboardingState = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: ""
    )
    @Published var pairs: [SyncPair] = []
    @Published var recentEvents: [ActivityEvent] = []
    @Published var statusSummary = MenuBarSummary(title: "Требуется настройка", alarmCount: 0, warningCount: 0)
    var openMainWindow: () -> Void = {}
    var openSettings: () -> Void = {}
    var quitApplication: () -> Void = {}
    var refreshBackgroundState: () -> Void = {}
    var runSyncNowForSelectedPair: () -> Void = {}
    var runCheckForSelectedPair: () -> Void = {}
    var runPullForSelectedPair: () -> Void = {}
    private var didAutoSelectInitialPair = false

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

    var activePair: SyncPair? {
        selectedPair ?? pairs.first
    }

    func refreshStatusSummary(using service: StatusService) {
        statusSummary = service.makeSummary(onboardingStep: onboardingState.step, pairs: pairs)
    }

    func applyOnboardingState(_ state: OnboardingState, using service: StatusService) {
        onboardingState = state
        refreshStatusSummary(using: service)
        normalizeSelection()
    }

    func applyPersistedState(pairs: [SyncPair], events: [ActivityEvent], using service: StatusService) {
        self.pairs = pairs
        recentEvents = Array(events.prefix(3))

        if let selectedPairID, !pairs.contains(where: { $0.id == selectedPairID }) {
            self.selectedPairID = pairs.first?.id
        }

        refreshStatusSummary(using: service)
        if !didAutoSelectInitialPair, let firstPair = pairs.first, case .route(.onboarding) = sidebarSelection, !shouldKeepOnboardingVisible {
            sidebarSelection = .pair(firstPair.id)
            didAutoSelectInitialPair = true
        }
        normalizeSelection()
    }

    private func normalizeSelection() {
        if shouldKeepOnboardingVisible {
            sidebarSelection = .route(.onboarding)
            return
        }

        if case let .pair(id) = sidebarSelection, !pairs.contains(where: { $0.id == id }) {
            sidebarSelection = pairs.first.map { .pair($0.id) } ?? .route(.overview)
        }
    }

    private var shouldKeepOnboardingVisible: Bool {
        guard pairs.isEmpty else {
            return false
        }

        switch onboardingState.step {
        case .installRclone, .configureRemote, .createFirstPair:
            return true
        case .complete:
            return false
        }
    }
}
