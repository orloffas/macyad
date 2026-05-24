import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationSplitView {
            List(
                AppRoute.allCases,
                id: \.self,
                selection: Binding(
                    get: { appModel.route },
                    set: { appModel.route = $0 ?? .overview }
                )
            ) { route in
                Label(route.title, systemImage: route.systemImage)
                    .tag(route)
            }
            .listStyle(.sidebar)
        } detail: {
            HSplitView {
                contentPane

                if appModel.isInspectorVisible {
                    inspectorPane
                }
            }
        }
    }

    private var contentPane: some View {
        Group {
            switch appModel.route {
            case .onboarding:
                OnboardingView(viewModel: environment.onboardingViewModel)
            case .overview:
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
}
