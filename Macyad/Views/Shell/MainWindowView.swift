import MacyadCore
import SwiftUI

struct MainWindowView: View {
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
                    Button("New Pair") {
                        presentCreatePairSheet()
                    }
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
                PairDetailView(pair: appModel.selectedPair)
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
    }
}
