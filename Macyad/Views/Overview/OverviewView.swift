import MacyadCore
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var viewModel: OverviewViewModel
    let onSelectPair: (UUID) -> Void
    let onToggleAutoPush: (UUID, Bool) -> Void
    @State private var selectedPairID: UUID?

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            Text(AppRoute.overview.title(using: copy))
                .font(.title2)
                .fontWeight(.semibold)

            LabeledContent(copy.overviewStatusLabel, value: appModel.statusSummary.title)
            LabeledContent(copy.overviewWorkspaceLabel, value: environment.paths.workspaceRoot.path)
            LabeledContent(copy.overviewPairsLabel, value: "\(appModel.pairs.count)")

            Table(viewModel.rows, selection: $selectedPairID) {
                TableColumn("Name") { row in
                    Text(row.name)
                }
                TableColumn("Status") { row in
                    HStack(spacing: 4) {
                        if row.isPaused {
                            Image(systemName: "pause.circle")
                                .foregroundStyle(.secondary)
                        }
                        Text(row.severity.rawValue.capitalized)
                            .foregroundStyle(colorForSeverity(row.severity))
                    }
                }
                TableColumn("Auto-push") { row in
                    Toggle("", isOn: Binding(
                        get: { row.isAutoPushEnabled },
                        set: { onToggleAutoPush(row.id, $0) }
                    ))
                    .labelsHidden()
                }
                TableColumn("Last sync") { row in
                    Text(row.lastSyncTitle)
                        .foregroundStyle(.secondary)
                }
                TableColumn("Severity") { row in
                    Text(row.severity.rawValue.capitalized)
                        .foregroundStyle(colorForSeverity(row.severity))
                }
            }
        }
        .padding(20)
        .onChange(of: selectedPairID) { _, newValue in
            if let newValue { onSelectPair(newValue) }
        }
        .onChange(of: appModel.sidebarSelection) { _, _ in
            if case .pair(let id) = appModel.sidebarSelection {
                selectedPairID = id
            } else {
                selectedPairID = nil
            }
        }
    }

    private func colorForSeverity(_ severity: Severity) -> Color {
        switch severity {
        case .healthy: .primary
        case .info: .blue
        case .warning: .orange
        case .alarm: .red
        }
    }
}
