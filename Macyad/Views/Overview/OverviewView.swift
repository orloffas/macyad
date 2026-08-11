import MacyadCore
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var viewModel: OverviewViewModel
    let onSelectPair: (UUID) -> Void
    let onChangeAutoSyncMode: (UUID, AutoSyncMode) -> Void
    @State private var selectedPairID: UUID?

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            Text(AppRoute.overview.title(using: copy))
                .font(.title2)
                .fontWeight(.semibold)

            LabeledContent(copy.overviewStatusLabel, value: appModel.statusSummary.title)
            LabeledContent(copy.overviewWorkspaceLabel) {
                HStack(spacing: 6) {
                    Text(environment.paths.workspaceDisplayPath)
                        .textSelection(.enabled)
                    Button {
                        environment.folderOpener.openFolder(atPath: environment.paths.workspaceRoot.path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(copy.openInFinderTitle)
                }
            }
            LabeledContent(copy.overviewPairsLabel, value: "\(appModel.pairs.count)")

            Table(viewModel.rows, selection: $selectedPairID) {
                TableColumn(copy.overviewNameColumn) { row in
                    Text(row.name)
                }
                TableColumn(copy.overviewStatusLabel) { row in
                    HStack(spacing: 4) {
                        if row.isPaused {
                            Image(systemName: "pause.circle")
                                .foregroundStyle(.secondary)
                            Text(pauseLabel(row.pauseSource, copy: copy))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text(copy.severityTitle(row.severity))
                                .foregroundStyle(colorForSeverity(row.severity))
                        }
                    }
                }
                TableColumn(copy.autoSyncModeLabel) { row in
                    Picker("", selection: Binding(
                        get: { row.autoSyncMode },
                        set: { onChangeAutoSyncMode(row.id, $0) }
                    )) {
                        ForEach(AutoSyncMode.allCases, id: \.self) { mode in
                            Text(copy.autoSyncModeTitle(mode)).tag(mode)
                        }
                    }
                    // A segmented control needs ~200pt and would squeeze the
                    // other columns; a popup button states the current mode in
                    // ~110pt, which is what fits a table row.
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .help(copy.autoSyncModeTooltip(row.autoSyncMode))
                }
                .width(min: 110, ideal: 125, max: 150)
                // No separate severity column: `Status` above already shows the
                // severity whenever the pair is not paused, and two columns
                // repeating "Warning" side by side taught the reader nothing.
                TableColumn(copy.overviewLastSyncColumn) { row in
                    Text(row.lastSyncTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        // The row cache lives in a view-model that outlives this view, while
        // `onChange` only fires while the view is on screen. Anything changed
        // from the pair detail page — the auto-sync mode, say — would show up
        // here as the state it had when Overview was last visible.
        .onAppear { refreshRows() }
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
        .onChange(of: appModel.pairs) { _, _ in refreshRows() }
        .onChange(of: appModel.preferences) { _, _ in refreshRows() }
        .onChange(of: appModel.activityEvents) { _, _ in refreshRows() }
    }

    private func refreshRows() {
        viewModel.update(
            pairs: appModel.pairs,
            events: appModel.activityEvents,
            preferences: appModel.preferences,
            copy: appModel.copy
        )
    }

    private func pauseLabel(_ source: OverviewPauseSource, copy: AppCopy) -> String {
        switch source {
        case .global: copy.pausedByGlobalSettingShort
        case .perPair: copy.pausedForThisPairShort
        case .none: ""
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
