import MacyadCore
import SwiftUI

struct ActivityReviewApplyResult {
    let replacementEvent: ActivityEvent?
    let shouldDismissDetail: Bool
}

struct MainWindowView: View {
    private struct PairOperationOutcome {
        let pair: SyncPair
        let message: String
        let details: String?
        let issueSet: ActivityIssueSet?
    }

    private enum PairOperationKind: Equatable {
        case syncNow
        case checkYandex
        case pullFromYandex

        var queueLabel: String {
            switch self {
            case .syncNow:
                "push"
            case .checkYandex:
                "check"
            case .pullFromYandex:
                "pull"
            }
        }
    }

    private enum PairOperationError: Error {
        case missingRclone
    }

    private struct LiveMonitorClosureObserver: RcloneOutputObserver {
        let onLineCallback: @Sendable @MainActor (String) -> Void
        func onLine(_ line: String) async {
            await onLineCallback(line)
        }
    }

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var environment: AppEnvironment
    @State private var createPairViewModel = CreatePairViewModel(
        accounts: [],
        folderPicker: FolderPickerBridge(),
        pairService: PairService()
    )
    @State private var didLoadPairs = false
    @State private var pairPendingDeletion: SyncPair?

    var body: some View {
        let copy = appModel.copy

        NavigationSplitView {
            List(
                selection: Binding(
                    get: { appModel.sidebarSelection },
                    set: { appModel.sidebarSelection = $0 ?? .route(.overview) }
                )
            ) {
                Section(copy.applicationSectionTitle) {
                    ForEach(AppRoute.allCases, id: \.self) { route in
                        Label(route.title(using: copy), systemImage: route.systemImage)
                            .tag(SidebarSelection.route(route))
                    }
                }

                Section(copy.pairsSectionTitle) {
                    ForEach(appModel.pairs) { pair in
                        PairListRowView(
                            pair: pair,
                            severity: pair.lastKnownSeverity,
                            accountLabel: appModel.accounts.first(where: { $0.id == pair.accountID })?.displayName
                        )
                            .tag(SidebarSelection.pair(pair.id))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 360)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(copy.settingsTitle, systemImage: "gearshape") {
                        openSettings()
                    }
                    .accessibilityIdentifier("settings.open")

                    Button(copy.newPairButtonTitle, systemImage: "plus") {
                        appModel.presentCreatePairSheet()
                    }
                    .accessibilityIdentifier("pair.new")
                }
            }
        } detail: {
            contentPane
        }
        .sheet(
            isPresented: Binding(
                get: { appModel.isCreatePairSheetPresented },
                set: { appModel.isCreatePairSheetPresented = $0 }
            )
        ) {
            CreatePairSheetView(viewModel: createPairViewModel) { pair in
                try await persistPair(pair)
            }
        }
        .alert(
            copy.deletePairConfirmationTitle,
            isPresented: Binding(
                get: { pairPendingDeletion != nil },
                set: { if !$0 { pairPendingDeletion = nil } }
            ),
            presenting: pairPendingDeletion
        ) { pair in
            Button(copy.deletePairConfirmButtonTitle, role: .destructive) {
                Task {
                    await deletePair(pair)
                }
            }
            Button(copy.cancelButtonTitle, role: .cancel) {
                pairPendingDeletion = nil
            }
        } message: { pair in
            Text(copy.deletePairConfirmationMessage(pair.name))
        }
        .task {
            await loadPairsIfNeeded()
        }
        .task(id: appModel.selectedPairID) {
            await environment.pairDetailViewModel.load(for: appModel.selectedPair)
        }
        .onAppear {
            configureQuickActions()
        }
    }

    private var contentPane: some View {
        Group {
            switch appModel.sidebarSelection {
            case .route(.onboarding):
                OnboardingView(viewModel: environment.onboardingViewModel)
            case .route(.overview):
                OverviewView(
                    viewModel: environment.overviewViewModel,
                    onSelectPair: { id in appModel.sidebarSelection = .pair(id) },
                    onToggleAutoPush: { id, value in
                        if let index = appModel.pairs.firstIndex(where: { $0.id == id }) {
                            appModel.pairs[index].isAutoPushEnabled = value
                            Task { try? await environment.pairRepository.save(appModel.pairs) }
                        }
                    }
                )
            case .pair:
                PairDetailView(
                    pair: appModel.selectedPair,
                    displaySeverity: appModel.selectedPair?.lastKnownSeverity ?? .healthy,
                    viewModel: environment.pairDetailViewModel,
                    preferences: appModel.preferences,
                    onSyncNow: { runActivePairAction(.syncNow) },
                    onCheckYandex: { runActivePairAction(.checkYandex) },
                    onPullFromYandex: { runActivePairAction(.pullFromYandex) },
                    onEditPair: { presentEditPairSheet() },
                    onDeletePair: { pairPendingDeletion = appModel.selectedPair },
                    canDeletePair: appModel.pairs.count > 1,
                    onApplyIssueReview: applyIssueReview,
                    onOpenLiveMonitor: {
                        if let pair = appModel.selectedPair {
                            appModel.openLiveMonitor?(pair)
                        }
                    }
                )
                .onAppear {
                    environment.pairDetailViewModel.onToggleAutoPush = { pair, newValue in
                        if let index = appModel.pairs.firstIndex(where: { $0.id == pair.id }) {
                            appModel.pairs[index].isAutoPushEnabled = newValue
                            try? await environment.pairRepository.save(appModel.pairs)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor
    private func presentCreatePairSheet() async {
        let defaultScheduleMinutes = (try? await environment.preferencesStore.load())?.defaultScheduleMinutes
            ?? AppPreferences.defaults.defaultScheduleMinutes

        do {
            let previousPairs = appModel.pairs
            let reconciled = try await environment.reconcileAccountsAndPairs(pairs: appModel.pairs)
            appModel.applyPersistedState(
                pairs: reconciled.pairs,
                accounts: reconciled.accounts,
                events: appModel.events(for: nil),
                using: environment.statusService
            )
            if reconciled.pairs != previousPairs {
                await environment.pairDetailViewModel.load(for: appModel.selectedPair)
            }
        } catch {
            environment.pairDetailViewModel.setError(error.localizedDescription)
        }

        createPairViewModel = CreatePairViewModel(
            accounts: appModel.accounts,
            folderPicker: FolderPickerBridge(),
            pairService: PairService(),
            defaultScheduleMinutes: defaultScheduleMinutes
        )
        appModel.isCreatePairSheetPresented = true
    }

    @MainActor
    private func presentEditPairSheet() {
        guard let pair = appModel.selectedPair else {
            return
        }

        createPairViewModel = CreatePairViewModel(
            existingPair: pair,
            accounts: appModel.accounts,
            folderPicker: FolderPickerBridge(),
            pairService: PairService()
        )
        appModel.isCreatePairSheetPresented = true
    }

    private func loadPairsIfNeeded() async {
        guard !didLoadPairs else {
            return
        }

        didLoadPairs = true

        do {
            let pairs = try await environment.pairRepository.load()
            let reconciled = try await environment.reconcileAccountsAndPairs(pairs: pairs)
            let events = try await environment.activityRepository.load()
            let preferences = (try? await environment.preferencesStore.load()) ?? .defaults
            await MainActor.run {
                appModel.preferences = preferences
                appModel.applyPersistedState(
                    pairs: reconciled.pairs,
                    accounts: reconciled.accounts,
                    events: events.sorted { $0.date > $1.date },
                    using: environment.statusService
                )
                environment.overviewViewModel.update(
                    pairs: reconciled.pairs,
                    events: events,
                    preferences: preferences,
                    copy: appModel.copy
                )
                appModel.applyInitialPairSelectionIfNeeded()
                configureQuickActions()
            }
        } catch {
            await MainActor.run {
                didLoadPairs = false
            }
        }
    }

    @MainActor
    private func persistPair(_ pair: SyncPair) async throws {
        var updatedPairs = appModel.pairs
        if let pairIndex = updatedPairs.firstIndex(where: { $0.id == pair.id }) {
            updatedPairs[pairIndex] = pair
        } else {
            updatedPairs.append(pair)
        }
        try await environment.pairRepository.save(updatedPairs)

        appModel.pairs = updatedPairs
        appModel.sidebarSelection = .pair(pair.id)
        appModel.isCreatePairSheetPresented = false
        appModel.refreshStatusSummary(using: environment.statusService)
        configureQuickActions()
        await environment.pairDetailViewModel.load(for: pair)
        appModel.refreshBackgroundState()
    }

    @MainActor
    private func deletePair(_ pair: SyncPair) async {
        pairPendingDeletion = nil
        guard appModel.pairs.count > 1 else {
            environment.pairDetailViewModel.setError(appModel.copy.lastPairDeleteDisabledMessage)
            return
        }

        do {
            let updatedPairs = try PairService().removePair(pair, from: appModel.pairs)
            try await environment.pairRepository.save(updatedPairs)
            try await environment.conflictStateRepository.remove(pairID: pair.id)

            let updatedEvents = appModel.activityEvents.filter { $0.pairID != pair.id }
            try await environment.activityRepository.save(updatedEvents)

            appModel.applyPersistedState(
                pairs: updatedPairs,
                accounts: appModel.accounts,
                events: updatedEvents.sorted { $0.date > $1.date },
                using: environment.statusService
            )
            await environment.pairDetailViewModel.load(for: appModel.selectedPair)
            configureQuickActions()
            appModel.refreshBackgroundState()
        } catch {
            environment.pairDetailViewModel.setError(error.localizedDescription)
        }
    }

    @MainActor
    private func configureQuickActions() {
        appModel.presentCreatePairSheet = {
            Task {
                await presentCreatePairSheet()
            }
        }
        appModel.runSyncNowForSelectedPair = {
            runActivePairAction(.syncNow)
        }
        appModel.runCheckForSelectedPair = {
            runActivePairAction(.checkYandex)
        }
        appModel.runPullForSelectedPair = {
            runActivePairAction(.pullFromYandex)
        }
    }

    @MainActor
    private func runActivePairAction(_ operation: PairOperationKind) {
        guard let activePair = appModel.activePair else {
            return
        }

        Task {
            await run(operation, for: activePair)
        }
    }

    private func run(_ operation: PairOperationKind, for pair: SyncPair) async {
        let bridge = appModel.liveMonitorPresenter as? LiveMonitorWindowBridge
        let liveMonitorViewModel = await MainActor.run {
            bridge?.existingViewModel(for: pair.id) ?? LiveMonitorViewModel()
        }
        let observer = LiveMonitorClosureObserver { [weak liveMonitorViewModel] line in
            liveMonitorViewModel?.appendLine(line)
        }

        await MainActor.run {
            environment.pairDetailViewModel.setOperationPhase(.queued, kind: .manual)
            environment.pairDetailViewModel.setError(nil)
            appModel.openLiveMonitor = { [weak appModel] openPair in
                guard let appModel else { return }
                bridge?.present(
                    pair: openPair,
                    viewModel: liveMonitorViewModel,
                    copy: appModel.copy,
                    restartIfExisting: true
                )
            }
        }

        do {
            let syncService = try await makeSyncService()
            let outcome = try await environment.operationCoordinator.enqueue(pairID: pair.id, label: operation.queueLabel) {
                await MainActor.run {
                    environment.pairDetailViewModel.setOperationPhase(.running, kind: .manual)
                }
                return await perform(operation, with: syncService, for: pair, observer: observer)
            }
            let updatedPair = outcome.pair
            try await replacePair(updatedPair)
            let eventID = UUID()
            let routeToken = outcome.issueSet.map { _ in
                ActivityRouteToken(pairID: updatedPair.id, eventID: eventID, openIssueTable: true)
            }
            let event = ActivityEvent(
                id: eventID,
                date: Date(),
                message: outcome.message,
                severity: updatedPair.lastKnownSeverity,
                pairID: updatedPair.id,
                details: outcome.details,
                issueSet: outcome.issueSet,
                routeToken: routeToken
            )
            try await environment.activityRepository.append(event)

            if operation == .syncNow, updatedPair.lastKnownSeverity == .warning {
                try? await environment.notificationClient.send(
                    title: AppCopy.current.pushBlockedNotificationTitle,
                    body: "\(pair.name): \(outcome.details ?? outcome.message)",
                    routeToken: routeToken
                )
            }

            await MainActor.run {
                appModel.appendActivityEvent(event)
                environment.pairDetailViewModel.setLatestSeverity(updatedPair.lastKnownSeverity)
                appModel.refreshBackgroundState()
                liveMonitorViewModel.setExitStatus(.success)
            }
        } catch {
            let copy = AppCopy.current
            let localizedError = localizedMessage(for: error, copy: copy)
            let detailedError = detailedMessage(for: error, copy: copy)

            var failedPair = pair
            failedPair.lastKnownSeverity = .alarm
            try? await replacePair(failedPair)
            let event = ActivityEvent(
                id: UUID(),
                date: Date(),
                message: failureMessage(for: operation, copy: copy),
                severity: .alarm,
                pairID: pair.id,
                details: detailedError
            )
            try? await environment.activityRepository.append(event)
            await MainActor.run {
                appModel.appendActivityEvent(event)
                environment.pairDetailViewModel.setError(localizedError)
                environment.pairDetailViewModel.setLatestSeverity(.alarm)
                appModel.refreshBackgroundState()
                liveMonitorViewModel.setExitStatus(.failed(code: 1))
            }
        }

        await MainActor.run {
            environment.pairDetailViewModel.setOperationPhase(.idle)
        }
    }

    private func perform(_ operation: PairOperationKind, with syncService: SyncService, for pair: SyncPair, observer: RcloneOutputObserver? = nil) async -> PairOperationOutcome {
        var updatedPair = pair

        switch operation {
        case .syncNow:
            let outcome = await syncService.push(pair, observer: observer)
            updatedPair.lastKnownSeverity = outcome.severity
            if outcome.shouldUpdateLastSync {
                updatedPair.lastSyncAt = Date()
            }
            return PairOperationOutcome(
                pair: updatedPair,
                message: eventMessage(for: operation, outcome: outcome),
                details: outcome.details,
                issueSet: outcome.issueSet
            )
        case .checkYandex:
            let outcome = await syncService.check(pair, observer: observer)
            updatedPair.lastKnownSeverity = outcome.severity
            return PairOperationOutcome(
                pair: updatedPair,
                message: eventMessage(for: operation, outcome: outcome),
                details: outcome.details,
                issueSet: outcome.issueSet
            )
        case .pullFromYandex:
            let outcome = await syncService.pull(pair, observer: observer)
            updatedPair.lastKnownSeverity = outcome.severity
            return PairOperationOutcome(
                pair: updatedPair,
                message: eventMessage(for: operation, outcome: outcome),
                details: outcome.details,
                issueSet: outcome.issueSet
            )
        }
    }

    private func applyIssueReview(_ sourceEvent: ActivityEvent, issueSet: ActivityIssueSet) async -> ActivityReviewApplyResult {
        guard let pair = await MainActor.run(body: { appModel.pairs.first(where: { $0.id == sourceEvent.pairID }) }) else {
            return ActivityReviewApplyResult(replacementEvent: nil, shouldDismissDetail: true)
        }

        await MainActor.run {
            environment.pairDetailViewModel.setOperationPhase(.queued)
            environment.pairDetailViewModel.setError(nil)
        }

        do {
            let syncService = try await makeSyncService()
            let outcome = try await environment.operationCoordinator.enqueue(pairID: pair.id, label: "review-files") {
                await MainActor.run {
                    environment.pairDetailViewModel.setOperationPhase(.running)
                }
                return await syncService.applyResolutions(issueSet, for: pair)
            }

            var updatedPair = pair
            updatedPair.lastKnownSeverity = outcome.severity
            if outcome.updatedBaseline {
                updatedPair.lastSyncAt = Date()
            }
            try await replacePair(updatedPair)

            if let remainingIssueSet = outcome.issueSet {
                let replacementEvent = ActivityEvent(
                    id: sourceEvent.id,
                    date: Date(),
                    message: outcome.summary,
                    severity: outcome.severity,
                    pairID: pair.id,
                    details: outcome.details,
                    issueSet: remainingIssueSet,
                    routeToken: ActivityRouteToken(pairID: pair.id, eventID: sourceEvent.id, openIssueTable: true)
                )
                try await environment.activityRepository.replace(replacementEvent)
                await MainActor.run {
                    appModel.replaceActivityEvent(replacementEvent)
                    environment.pairDetailViewModel.setLatestSeverity(outcome.severity)
                    environment.pairDetailViewModel.setOperationPhase(.idle)
                }
                return ActivityReviewApplyResult(replacementEvent: replacementEvent, shouldDismissDetail: false)
            }

            let closedSourceEvent = ActivityEvent(
                id: sourceEvent.id,
                date: sourceEvent.date,
                message: sourceEvent.message,
                severity: sourceEvent.severity,
                pairID: sourceEvent.pairID,
                details: sourceEvent.details,
                issueSet: nil,
                routeToken: nil
            )
            let resultEvent = ActivityEvent(
                id: UUID(),
                date: Date(),
                message: outcome.summary,
                severity: outcome.severity,
                pairID: pair.id,
                details: outcome.details
            )
            try await environment.activityRepository.replace(closedSourceEvent)
            try await environment.activityRepository.append(resultEvent)
            await MainActor.run {
                appModel.replaceActivityEvent(closedSourceEvent)
                appModel.appendActivityEvent(resultEvent)
                environment.pairDetailViewModel.setLatestSeverity(outcome.severity)
                environment.pairDetailViewModel.setOperationPhase(.idle)
            }
            return ActivityReviewApplyResult(replacementEvent: nil, shouldDismissDetail: true)
        } catch {
            let copy = AppCopy.current
            let errorMessage = detailedMessage(for: error, copy: copy)
            let failedEvent = ActivityEvent(
                id: sourceEvent.id,
                date: Date(),
                message: copy.manualSyncFailedPrefix,
                severity: .alarm,
                pairID: pair.id,
                details: errorMessage,
                issueSet: sourceEvent.issueSet,
                routeToken: sourceEvent.routeToken
            )
            try? await environment.activityRepository.replace(failedEvent)
            await MainActor.run {
                appModel.replaceActivityEvent(failedEvent)
                environment.pairDetailViewModel.setLatestSeverity(.alarm)
                environment.pairDetailViewModel.setError(error.localizedDescription)
                environment.pairDetailViewModel.setOperationPhase(.idle)
            }
            return ActivityReviewApplyResult(replacementEvent: failedEvent, shouldDismissDetail: false)
        }
    }

    private func localizedMessage(for error: Error, copy: AppCopy) -> String {
        if let pairError = error as? PairOperationError, case .missingRclone = pairError {
            return copy.missingRcloneForManualAction
        }

        return error.localizedDescription
    }

    private func detailedMessage(for error: Error, copy: AppCopy) -> String {
        localizedMessage(for: error, copy: copy)
    }

    private func replacePair(_ pair: SyncPair) async throws {
        guard let pairIndex = await MainActor.run(body: { appModel.pairs.firstIndex(where: { $0.id == pair.id }) }) else {
            return
        }

        var updatedPairs = await MainActor.run(body: { appModel.pairs })
        updatedPairs[pairIndex] = pair
        try await environment.pairRepository.save(updatedPairs)

        await MainActor.run {
            appModel.pairs = updatedPairs
            appModel.refreshStatusSummary(using: environment.statusService)
        }
    }

    private func makeSyncService() async throws -> SyncService {
        guard let executablePath = try await environment.rcloneLocator.locate() else {
            throw PairOperationError.missingRclone
        }

        return SyncService(
            processClient: RcloneProcessClient(executablePath: executablePath),
            configPath: environment.paths.rcloneConfigFile.path,
            excludeFileStore: PersistentRcloneExcludeFileStore(paths: environment.paths),
            baselineRepository: environment.conflictStateRepository,
            operationInspector: SystemRcloneOperationInspector()
        )
    }

    private func failureMessage(for operation: PairOperationKind, copy: AppCopy) -> String {
        switch operation {
        case .syncNow:
            return copy.manualSyncFailedPrefix
        case .checkYandex:
            return copy.manualCheckFailedPrefix
        case .pullFromYandex:
            return copy.manualPullFailedPrefix
        }
    }

    private func eventMessage(for operation: PairOperationKind, outcome: SyncService.OperationOutcome) -> String {
        let copy = AppCopy.current

        switch operation {
        case .syncNow:
            if outcome.severity == .healthy {
                return copy.manualSyncCompleted
            }
            return outcome.shouldUpdateLastSync ? copy.manualConflictReconciledTitle : copy.manualPushBlockedTitle
        case .checkYandex:
            return outcome.summary
        case .pullFromYandex:
            if outcome.severity == .healthy {
                return copy.manualPullCompleted
            }
            return outcome.updatedBaseline ? copy.manualConflictReconciledTitle : copy.manualPullBlockedTitle
        }
    }
}
