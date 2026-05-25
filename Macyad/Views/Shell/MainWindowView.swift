import MacyadCore
import SwiftUI

struct MainWindowView: View {
    private struct PairOperationOutcome {
        let pair: SyncPair
        let message: String
        let details: String?
    }

    private enum PairOperationKind {
        case syncNow
        case checkYandex
        case pullFromYandex

        func successMessage(using copy: AppCopy) -> String {
            switch self {
            case .syncNow:
                copy.manualSyncCompleted
            case .checkYandex:
                copy.manualCheckCompleted
            case .pullFromYandex:
                copy.manualPullCompleted
            }
        }

        func failurePrefix(using copy: AppCopy) -> String {
            switch self {
            case .syncNow:
                copy.manualSyncFailedPrefix
            case .checkYandex:
                copy.manualCheckFailedPrefix
            case .pullFromYandex:
                copy.manualPullFailedPrefix
            }
        }
    }

    private enum PairOperationError: Error {
        case missingRclone
    }

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var environment: AppEnvironment
    @State private var createPairViewModel = CreatePairViewModel(
        folderPicker: FolderPickerBridge(),
        pairService: PairService()
    )
    @State private var didLoadPairs = false

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
                        PairListRowView(pair: pair)
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
                        Task {
                            await presentCreatePairSheet()
                        }
                    }
                    .accessibilityIdentifier("pair.new")
                }
            }
        } detail: {
            HSplitView {
                contentPane

                if appModel.isInspectorVisible {
                    inspectorPane
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { appModel.isCreatePairSheetPresented },
                set: { appModel.isCreatePairSheetPresented = $0 }
            )
        ) {
            CreatePairSheetView(viewModel: createPairViewModel) { pair in
                try await savePair(pair)
            }
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
        let copy = appModel.copy

        return Group {
            switch appModel.sidebarSelection {
            case .route(.onboarding):
                OnboardingView(viewModel: environment.onboardingViewModel)
            case .route(.overview):
                VStack(alignment: .leading, spacing: 14) {
                    Text(appModel.route.title(using: copy))
                        .font(.title2)
                        .fontWeight(.semibold)

                    LabeledContent(copy.overviewStatusLabel, value: appModel.statusSummary.title)
                    LabeledContent(copy.overviewWorkspaceLabel, value: environment.paths.workspaceRoot.path)
                    LabeledContent(copy.overviewPairsLabel, value: "\(appModel.pairs.count)")

                    Spacer()
                }
                .padding(20)
            case .pair:
                PairDetailView(
                    pair: appModel.selectedPair,
                    viewModel: environment.pairDetailViewModel,
                    onSyncNow: { runActivePairAction(.syncNow) },
                    onCheckYandex: { runActivePairAction(.checkYandex) },
                    onPullFromYandex: { runActivePairAction(.pullFromYandex) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inspectorPane: some View {
        let copy = appModel.copy

        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.inspectorTitle)
                .font(.headline)

            LabeledContent(copy.warningsLabel, value: "\(appModel.statusSummary.warningCount)")
            LabeledContent(copy.alarmsLabel, value: "\(appModel.statusSummary.alarmCount)")

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 260, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor
    private func presentCreatePairSheet() async {
        let defaultScheduleMinutes = (try? await environment.preferencesStore.load())?.defaultScheduleMinutes
            ?? AppPreferences.defaults.defaultScheduleMinutes
        createPairViewModel = CreatePairViewModel(
            folderPicker: FolderPickerBridge(),
            pairService: PairService(),
            defaultScheduleMinutes: defaultScheduleMinutes
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
            let events = try await environment.activityRepository.load()
            await MainActor.run {
                appModel.applyPersistedState(pairs: pairs, events: events.sorted { $0.date > $1.date }, using: environment.statusService)
                configureQuickActions()
            }
        } catch {
            await MainActor.run {
                didLoadPairs = false
            }
        }
    }

    @MainActor
    private func savePair(_ pair: SyncPair) async throws {
        var updatedPairs = appModel.pairs
        updatedPairs.append(pair)
        try await environment.pairRepository.save(updatedPairs)

        appModel.pairs = updatedPairs
        appModel.sidebarSelection = .pair(pair.id)
        appModel.isCreatePairSheetPresented = false
        appModel.refreshStatusSummary(using: environment.statusService)
        configureQuickActions()
        appModel.refreshBackgroundState()
    }

    @MainActor
    private func configureQuickActions() {
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
        await MainActor.run {
            environment.pairDetailViewModel.setOperationInFlight(true)
            environment.pairDetailViewModel.setError(nil)
        }

        do {
            let syncService = try await makeSyncService()
            let outcome = try await perform(operation, with: syncService, for: pair)
            let updatedPair = outcome.pair
            try await replacePair(updatedPair)
            let copy = AppCopy.current

            await environment.pairDetailViewModel.record(
                ActivityEvent(
                    id: UUID(),
                    date: Date(),
                    message: outcome.message,
                    severity: updatedPair.lastKnownSeverity,
                    pairID: updatedPair.id,
                    details: outcome.details
                ),
                latestSeverity: updatedPair.lastKnownSeverity
            )
            await MainActor.run {
                appModel.refreshBackgroundState()
            }
        } catch {
            let copy = AppCopy.current
            let localizedError = localizedMessage(for: error, copy: copy)
            let detailedError = detailedMessage(for: error, copy: copy)

            if case .syncNow = operation,
               error is SyncService.LocalFolderEmptyPushBlockedError {
                var blockedPair = pair
                blockedPair.lastKnownSeverity = .warning
                try? await replacePair(blockedPair)

                await environment.pairDetailViewModel.record(
                    ActivityEvent(
                        id: UUID(),
                        date: Date(),
                        message: copy.manualPushBlockedTitle,
                        severity: .warning,
                        pairID: pair.id,
                        details: localizedError
                    ),
                    latestSeverity: .warning
                )
                try? await environment.notificationClient.send(
                    title: copy.pushBlockedNotificationTitle,
                    body: "\(pair.name): \(localizedError)"
                )
                await MainActor.run {
                    environment.pairDetailViewModel.setError(localizedError)
                    appModel.refreshBackgroundState()
                }
            } else {
                var failedPair = pair
                failedPair.lastKnownSeverity = .alarm
                try? await replacePair(failedPair)

                await environment.pairDetailViewModel.record(
                    ActivityEvent(
                        id: UUID(),
                        date: Date(),
                        message: operation.failurePrefix(using: copy),
                        severity: .alarm,
                        pairID: pair.id,
                        details: detailedError
                    ),
                    latestSeverity: .alarm
                )
                await MainActor.run {
                    environment.pairDetailViewModel.setError(detailedError)
                    appModel.refreshBackgroundState()
                }
            }
        }

        await MainActor.run {
            environment.pairDetailViewModel.setOperationInFlight(false)
        }
    }

    private func perform(_ operation: PairOperationKind, with syncService: SyncService, for pair: SyncPair) async throws -> PairOperationOutcome {
        var updatedPair = pair

        switch operation {
        case .syncNow:
            try await syncService.push(pair)
            updatedPair.lastKnownSeverity = .healthy
            updatedPair.lastSyncAt = Date()
            return PairOperationOutcome(
                pair: updatedPair,
                message: AppCopy.current.manualSyncCompleted,
                details: nil
            )
        case .checkYandex:
            let outcome = try await syncService.check(pair)
            updatedPair.lastKnownSeverity = outcome.severity
            let details = outcome.severity == .warning
                ? AppCopy.current.checkWarningDetails(logDescription: outcome.log.detailedDescription)
                : nil
            return PairOperationOutcome(
                pair: updatedPair,
                message: outcome.severity == .warning
                    ? AppCopy.current.manualCheckWarningDetected
                    : AppCopy.current.manualCheckCompleted,
                details: details
            )
        case .pullFromYandex:
            try await syncService.pull(pair)
            updatedPair.lastKnownSeverity = .healthy
            return PairOperationOutcome(
                pair: updatedPair,
                message: AppCopy.current.manualPullCompleted,
                details: nil
            )
        }
    }

    private func localizedMessage(for error: Error, copy: AppCopy) -> String {
        if let pairError = error as? PairOperationError, case .missingRclone = pairError {
            return copy.missingRcloneForManualAction
        }

        return error.localizedDescription
    }

    private func detailedMessage(for error: Error, copy: AppCopy) -> String {
        if let commandError = error as? SyncService.CommandFailedError {
            return commandError.detailedDescription
        }

        return localizedMessage(for: error, copy: copy)
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
            configPath: environment.paths.rcloneConfigFile.path
        )
    }
}
