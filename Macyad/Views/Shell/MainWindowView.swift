import MacyadCore
import SwiftUI

struct MainWindowView: View {
    private enum PairOperationKind {
        case syncNow
        case checkYandex
        case pullFromYandex

        var successMessage: String {
            switch self {
            case .syncNow:
                "Sync Now завершён"
            case .checkYandex:
                "Проверка Yandex завершена"
            case .pullFromYandex:
                "Pull From Yandex завершён"
            }
        }

        var failurePrefix: String {
            switch self {
            case .syncNow:
                "Не удалось выполнить Sync Now"
            case .checkYandex:
                "Не удалось выполнить Check Yandex"
            case .pullFromYandex:
                "Не удалось выполнить Pull From Yandex"
            }
        }
    }

    private enum PairOperationError: LocalizedError {
        case missingRclone

        var errorDescription: String? {
            switch self {
            case .missingRclone:
                "Сначала установите `rclone`, затем повторите действие."
            }
        }
    }

    @Environment(AppModel.self) private var appModel
    @Environment(AppEnvironment.self) private var environment
    @State private var createPairViewModel = CreatePairViewModel(
        folderPicker: FolderPickerBridge(),
        pairService: PairService()
    )
    @State private var didLoadPairs = false

    var body: some View {
        NavigationSplitView {
            List(
                selection: Binding(
                    get: { appModel.sidebarSelection },
                    set: { appModel.sidebarSelection = $0 ?? .route(.overview) }
                )
            ) {
                Section("Приложение") {
                    ForEach(AppRoute.allCases, id: \.self) { route in
                        Label(route.title, systemImage: route.systemImage)
                            .tag(SidebarSelection.route(route))
                    }
                }

                Section("Pairs") {
                    ForEach(appModel.pairs) { pair in
                        PairListRowView(pair: pair)
                            .tag(SidebarSelection.pair(pair.id))
                    }
                }
            }
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("pair.new") {
                        presentCreatePairSheet()
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
        Group {
            switch appModel.sidebarSelection {
            case .route(.onboarding):
                OnboardingView(viewModel: environment.onboardingViewModel)
            case .route(.overview):
                VStack(alignment: .leading, spacing: 14) {
                    Text(appModel.route.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    LabeledContent("Status", value: appModel.statusSummary.title)
                    LabeledContent("Workspace", value: environment.paths.workspaceRoot.path)
                    LabeledContent("Pairs", value: "\(appModel.pairs.count)")

                    Spacer()
                }
                .padding(20)
            case .pair:
                PairDetailView(
                    pair: appModel.selectedPair,
                    viewModel: environment.pairDetailViewModel,
                    onSyncNow: { runSelectedPairAction(.syncNow) },
                    onCheckYandex: { runSelectedPairAction(.checkYandex) },
                    onPullFromYandex: { runSelectedPairAction(.pullFromYandex) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inspector")
                .font(.headline)

            LabeledContent("Warnings", value: "\(appModel.statusSummary.warningCount)")
            LabeledContent("Alarms", value: "\(appModel.statusSummary.alarmCount)")

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 260, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor
    private func presentCreatePairSheet() {
        createPairViewModel = CreatePairViewModel(
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
            await MainActor.run {
                appModel.pairs = pairs
                appModel.refreshStatusSummary(using: environment.statusService)
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
    }

    @MainActor
    private func configureQuickActions() {
        appModel.runSyncNowForSelectedPair = {
            runSelectedPairAction(.syncNow)
        }
        appModel.runCheckForSelectedPair = {
            runSelectedPairAction(.checkYandex)
        }
        appModel.runPullForSelectedPair = {
            runSelectedPairAction(.pullFromYandex)
        }
    }

    @MainActor
    private func runSelectedPairAction(_ operation: PairOperationKind) {
        guard let selectedPair = appModel.selectedPair else {
            return
        }

        Task {
            await run(operation, for: selectedPair)
        }
    }

    private func run(_ operation: PairOperationKind, for pair: SyncPair) async {
        await MainActor.run {
            environment.pairDetailViewModel.setOperationInFlight(true)
            environment.pairDetailViewModel.setError(nil)
        }

        do {
            let syncService = try await makeSyncService()
            let updatedPair = try await perform(operation, with: syncService, for: pair)
            try await replacePair(updatedPair)

            await environment.pairDetailViewModel.record(
                ActivityEvent(
                    id: UUID(),
                    date: Date(),
                    message: operation.successMessage,
                    severity: updatedPair.lastKnownSeverity,
                    pairID: updatedPair.id
                ),
                latestSeverity: updatedPair.lastKnownSeverity
            )
        } catch {
            var failedPair = pair
            failedPair.lastKnownSeverity = .alarm
            try? await replacePair(failedPair)

            let failureMessage = "\(operation.failurePrefix): \(error.localizedDescription)"
            await environment.pairDetailViewModel.record(
                ActivityEvent(
                    id: UUID(),
                    date: Date(),
                    message: failureMessage,
                    severity: .alarm,
                    pairID: pair.id
                ),
                latestSeverity: .alarm
            )
            await MainActor.run {
                environment.pairDetailViewModel.setError(failureMessage)
            }
        }

        await MainActor.run {
            environment.pairDetailViewModel.setOperationInFlight(false)
        }
    }

    private func perform(_ operation: PairOperationKind, with syncService: SyncService, for pair: SyncPair) async throws -> SyncPair {
        var updatedPair = pair

        switch operation {
        case .syncNow:
            try await syncService.push(pair)
            updatedPair.lastKnownSeverity = .healthy
        case .checkYandex:
            updatedPair.lastKnownSeverity = try await syncService.check(pair)
        case .pullFromYandex:
            try await syncService.pull(pair)
            updatedPair.lastKnownSeverity = .healthy
        }

        return updatedPair
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

        return SyncService(processClient: RcloneProcessClient(executablePath: executablePath))
    }
}
