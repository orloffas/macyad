import AppKit
import Combine
import Foundation
import MacyadCore

@MainActor
final class AppModel: ObservableObject {
    @Published var language = AppLanguageState.current
    @Published var sidebarSelection: SidebarSelection = .route(.onboarding)
    @Published var isCreatePairSheetPresented = false
    @Published var onboardingState = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: "",
        configPath: ""
    )
    @Published var accounts: [YandexAccount] = []
    @Published var pairs: [SyncPair] = []
    @Published private(set) var activityEvents: [ActivityEvent] = []
    @Published var recentEvents: [ActivityEvent] = []
    @Published var selectedActivityEventID: UUID?
    @Published var pendingActivityRoute: ActivityRouteToken?
    @Published var statusSummary = MenuBarSummary(title: AppCopy.current.statusSetupRequired, alarmCount: 0, warningCount: 0)
    @Published var preferences: AppPreferences = .defaults
    var openMainWindow: () -> Void = {}
    var quitApplication: () -> Void = {}
    var refreshBackgroundState: () -> Void = {}
    var presentCreatePairSheet: () -> Void = {}
    var runSyncNowForSelectedPair: () -> Void = {}
    var runCheckForSelectedPair: () -> Void = {}
    var runPullForSelectedPair: () -> Void = {}
    var presentIssueReviewWindow: (_ presentingWindow: NSWindow?, _ issueSet: ActivityIssueSet, _ onApply: @escaping (ActivityIssueSet) async -> ActivityReviewApplyResult) -> Void = { _, _, _ in }
    var closeIssueReviewWindow: () -> Void = {}
    var liveMonitorPresenter: LiveMonitorPresenting?
    var openLiveMonitor: ((SyncPair) -> Void)?
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

    var selectedActivityEvent: ActivityEvent? {
        activityEvents.first { $0.id == selectedActivityEventID }
    }

    var copy: AppCopy {
        AppCopy(language: language)
    }

    func refreshStatusSummary(using service: StatusService) {
        statusSummary = service.makeSummary(onboardingStep: onboardingState.step, pairs: pairs)
    }

    func applyOnboardingState(_ state: OnboardingState, using service: StatusService) {
        onboardingState = state
        refreshStatusSummary(using: service)
        normalizeSelection()
    }

    func applyPersistedState(pairs: [SyncPair], accounts: [YandexAccount], events: [ActivityEvent], using service: StatusService) {
        self.pairs = pairs
        self.accounts = accounts
        setActivityEvents(events)

        if let selectedPairID, !pairs.contains(where: { $0.id == selectedPairID }) {
            self.selectedPairID = pairs.first?.id
        }

        if let selectedActivityEventID, !activityEvents.contains(where: { $0.id == selectedActivityEventID }) {
            self.selectedActivityEventID = nil
            pendingActivityRoute = nil
        }

        refreshStatusSummary(using: service)
        normalizeSelection()
    }

    func events(for pairID: UUID?) -> [ActivityEvent] {
        guard let pairID else {
            return activityEvents
        }

        return activityEvents.filter { $0.pairID == pairID }
    }

    func appendActivityEvent(_ event: ActivityEvent) {
        var updatedEvents = activityEvents
        updatedEvents.append(event)
        setActivityEvents(updatedEvents)
    }

    func replaceActivityEvent(_ event: ActivityEvent) {
        var updatedEvents = activityEvents
        if let index = updatedEvents.firstIndex(where: { $0.id == event.id }) {
            updatedEvents[index] = event
        } else {
            updatedEvents.append(event)
        }
        setActivityEvents(updatedEvents)
    }

    func removeActivityEvents(forPairID pairID: UUID) {
        setActivityEvents(activityEvents.filter { $0.pairID != pairID })
        if selectedActivityEvent?.pairID == pairID {
            selectedActivityEventID = nil
            pendingActivityRoute = nil
        }
    }

    func applyActivityRoute(_ routeToken: ActivityRouteToken) {
        selectedPairID = routeToken.pairID
        selectedActivityEventID = routeToken.eventID
        pendingActivityRoute = routeToken
    }

    func consumePendingActivityRoute(for eventID: UUID) -> ActivityRouteToken? {
        guard pendingActivityRoute?.eventID == eventID else {
            return nil
        }

        defer { pendingActivityRoute = nil }
        return pendingActivityRoute
    }

    func clearSelectedActivityEvent() {
        selectedActivityEventID = nil
        pendingActivityRoute = nil
    }

    func applyInitialPairSelectionIfNeeded() {
        guard !didAutoSelectInitialPair else {
            return
        }

        didAutoSelectInitialPair = true

        guard let firstPair = pairs.first,
              case .route(.onboarding) = sidebarSelection,
              !shouldKeepOnboardingVisible else {
            return
        }

        sidebarSelection = .pair(firstPair.id)
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

    private func setActivityEvents(_ events: [ActivityEvent]) {
        activityEvents = events.sorted { $0.date > $1.date }
        recentEvents = Array(activityEvents.prefix(3))
    }
}
