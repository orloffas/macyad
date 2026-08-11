import MacyadCore
import SwiftUI

struct PairDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var environment: AppEnvironment
    let pair: SyncPair?
    let displaySeverity: Severity
    @ObservedObject var viewModel: PairDetailViewModel
    var preferences: AppPreferences = .defaults
    var onSyncNow: (() -> Void)? = nil
    var onCheckYandex: (() -> Void)? = nil
    var onPullFromYandex: (() -> Void)? = nil
    var onEditPair: (() -> Void)? = nil
    var onDeletePair: (() -> Void)? = nil
    var canDeletePair = true
    var onApplyIssueReview: ((ActivityEvent, ActivityIssueSet) async -> ActivityReviewApplyResult)? = nil
    var onOpenLiveMonitor: ((LiveMonitorSlot) -> Void)? = nil
    @State private var selectedActivityEvent: ActivityEvent?
    @State private var autoOpenIssueReview = false

    var body: some View {
        let copy = appModel.copy

        Group {
            if let pair {
                VStack(alignment: .leading, spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        header(pair: pair)
                        VStack(alignment: .leading, spacing: 10) {
                            titleBlock(pair: pair)
                            HStack(spacing: 10) {
                                actionButtons
                                Spacer(minLength: 0)
                                managementButtons
                            }
                        }
                    }

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text(copy.localFolderTitle)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(pair.localFolderDisplayPath)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                Button {
                                    environment.folderOpener.openFolder(atPath: pair.localFolderDisplayPath)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.borderless)
                                .help(copy.openInFinderTitle)
                            }
                        }
                        GridRow {
                            Text(copy.remotePathTitle)
                                .foregroundStyle(.secondary)
                            Text(pair.remotePath)
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text(copy.accountTitle)
                                .foregroundStyle(.secondary)
                            Text(accountName(for: pair))
                        }
                        GridRow {
                            Text(copy.scheduleFieldTitle)
                                .foregroundStyle(.secondary)
                            Text(copy.minutesValue(pair.scheduleMinutes))
                        }
                        GridRow {
                            Text(copy.deletePolicyFieldTitle)
                                .foregroundStyle(.secondary)
                            Text(deletePolicyTitle(pair.deletePolicy))
                        }
                        GridRow {
                            Text(copy.conflictPolicyFieldTitle)
                                .foregroundStyle(.secondary)
                            Text(conflictPolicyTitle(pair.conflictPolicy))
                        }
                        GridRow {
                            Text(copy.lastSyncTitle)
                                .foregroundStyle(.secondary)
                            Text(lastSyncTitle(for: pair))
                        }
                        GridRow {
                            Text(copy.nextSyncTitle)
                                .foregroundStyle(.secondary)
                            Text(nextScheduledSyncTitle(for: pair))
                        }
                    }
                    .font(.callout)

                    actionDescriptions

                    if let lastErrorMessage = viewModel.lastErrorMessage {
                        LastErrorDisclosure(message: lastErrorMessage)
                    }

                    ActivityListView(events: appModel.events(for: pair.id), selectedEvent: $selectedActivityEvent)
                        .frame(maxHeight: .infinity)
                }
                .padding(16)
                .sheet(item: $selectedActivityEvent) { event in
                    ActivityDetailView(
                        event: event,
                        pair: pair,
                        initialOpenIssueReview: autoOpenIssueReview,
                        onApplyIssueReview: { updatedIssueSet in
                            guard let onApplyIssueReview else {
                                return ActivityReviewApplyResult(replacementEvent: event, shouldDismissDetail: false)
                            }
                            return await onApplyIssueReview(event, updatedIssueSet)
                        }
                    )
                        .environmentObject(appModel)
                }
            } else {
                ContentUnavailableView(
                    copy.noPairTitle,
                    systemImage: "folder.badge.plus",
                    description: Text(copy.noPairDescription)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard let pair, let selectedEventID = appModel.selectedActivityEventID else {
                return
            }

            guard let event = appModel.events(for: pair.id).first(where: { $0.id == selectedEventID }) else {
                return
            }

            let routeToken = appModel.consumePendingActivityRoute(for: selectedEventID)
            autoOpenIssueReview = routeToken?.openIssueTable ?? false
            selectedActivityEvent = event
        }
        .onChange(of: appModel.selectedActivityEventID) { _, selectedEventID in
            guard let pair else {
                selectedActivityEvent = nil
                return
            }

            guard let selectedEventID else {
                selectedActivityEvent = nil
                return
            }

            guard let event = appModel.events(for: pair.id).first(where: { $0.id == selectedEventID }) else {
                return
            }

            let routeToken = appModel.consumePendingActivityRoute(for: selectedEventID)
            autoOpenIssueReview = routeToken?.openIssueTable ?? false
            selectedActivityEvent = event
        }
        .onChange(of: selectedActivityEvent) { _, event in
            if let event {
                appModel.selectedActivityEventID = event.id
            } else {
                autoOpenIssueReview = false
                appModel.clearSelectedActivityEvent()
            }
        }
    }

    private func header(pair: SyncPair) -> some View {
        HStack(alignment: .top) {
            titleBlock(pair: pair)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                actionButtons
                managementButtons
            }
        }
    }

    private func titleBlock(pair: SyncPair) -> some View {
        let copy = appModel.copy
        let source = viewModel.pauseSource(for: pair, preferences: preferences)

        return VStack(alignment: .leading, spacing: 5) {
            Text(pair.name)
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Text(copy.lastStatusTitle(severityTitle(displaySeverity)))
                    .foregroundStyle(.secondary)

                if source != .none {
                    let tooltip = source == .global
                        ? copy.pausedByGlobalSettingTooltip
                        : copy.pausedForThisPairTooltip
                    Image(systemName: "pause.circle")
                        .foregroundStyle(.secondary)
                        .help(tooltip)
                    Text(tooltip)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Picker(copy.autoSyncModeLabel, selection: Binding(
                get: { pair.autoSyncMode },
                set: { newValue in
                    Task { await viewModel.onChangeAutoSyncMode?(pair, newValue) }
                }
            )) {
                ForEach(AutoSyncMode.allCases, id: \.self) { mode in
                    Text(copy.autoSyncModeTitle(mode))
                        .help(copy.autoSyncModeTooltip(mode))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
            .help(copy.autoSyncModeExclusiveHint)
        }
    }

    private var actionButtons: some View {
        let copy = appModel.copy

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(copy.syncButtonTitle) { onSyncNow?() }
                    .help(copy.pushActionDescription)
                Button(copy.checkButtonTitle) { onCheckYandex?() }
                    .help(copy.checkActionDescription)
                Button(copy.pullButtonTitle) { onPullFromYandex?() }
                    .help(copy.pullActionDescription)
            }
            .disabled(viewModel.operationPhase != .idle)

            HStack(spacing: 8) {
                if viewModel.operationPhase != .idle {
                    ProgressView()
                        .controlSize(.small)
                    Text(operationPhaseTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pair {
                    let hasArchived = appModel.pairsWithArchivedLog.contains(pair.id)
                    Button(copy.showLastLogButtonTitle) { onOpenLiveMonitor?(.archived) }
                        .buttonStyle(.link)
                        .font(.caption)
                        .disabled(!hasArchived || onOpenLiveMonitor == nil)
                        .hoverTip(hasArchived ? "" : copy.showLastLogTooltipSessionOnly)
                    // Offered while queued too: the log view-model is created
                    // and seeded before the operation reaches the front of the
                    // queue, and a queued run is exactly when the user wants to
                    // know what the app is waiting for.
                    if viewModel.operationPhase != .idle,
                       viewModel.lastOperationKind != .scheduled,
                       appModel.activeManualPairIDs.contains(pair.id),
                       let onOpenLiveMonitor {
                        Button(copy.openLiveMonitorButtonTitle) { onOpenLiveMonitor(.running) }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
            }
        }
        .controlSize(.small)
    }

    private var managementButtons: some View {
        let copy = appModel.copy

        return HStack(spacing: 8) {
            Button {
                onEditPair?()
            } label: {
                Image(systemName: "pencil")
            }
            .help(copy.editPairTitle)

            Button(role: .destructive) {
                onDeletePair?()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(!canDeletePair)
            .help(canDeletePair ? copy.deletePairTitle : copy.lastPairDeleteDisabledMessage)
        }
        .controlSize(.small)
    }

    private var actionDescriptions: some View {
        let copy = appModel.copy

        return VStack(alignment: .leading, spacing: 6) {
            Text(copy.actionsHelpTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text(copy.syncButtonTitle)
                        .fontWeight(.medium)
                    Text(copy.pushActionDescription)
                }
                GridRow {
                    Text(copy.checkButtonTitle)
                        .fontWeight(.medium)
                    Text(copy.checkActionDescription)
                }
                GridRow {
                    Text(copy.pullButtonTitle)
                        .fontWeight(.medium)
                    Text(copy.pullActionDescription)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private struct LastErrorDisclosure: View {
        let message: String
        @State private var isExpanded = true

        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                ScrollView {
                    Text(message)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 120)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            } label: {
                Label(AppCopy.current.lastErrorTitle, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.callout.weight(.semibold))
            }
        }
    }

    private func severityTitle(_ severity: Severity) -> String {
        appModel.copy.severityTitle(severity)
    }

    private func deletePolicyTitle(_ policy: SyncPair.DeletePolicy) -> String {
        let copy = appModel.copy

        switch policy {
        case .mirrorToYandex:
            return copy.deletePolicyMirrorTitle
        case .keepRemoteDeletesManual:
            return copy.deletePolicyManualTitle
        }
    }

    private func conflictPolicyTitle(_ policy: ConflictPolicy) -> String {
        let copy = appModel.copy

        switch policy {
        case .block:
            return copy.conflictPolicyBlockTitle
        case .keepBoth:
            return copy.conflictPolicyKeepBothTitle
        }
    }

    private func lastSyncTitle(for pair: SyncPair) -> String {
        let copy = appModel.copy

        guard let lastSyncAt = pair.lastSyncAt else {
            return copy.neverSynced
        }

        return copy.formatTimestamp(lastSyncAt)
    }

    private func nextScheduledSyncTitle(for pair: SyncPair) -> String {
        let copy = appModel.copy

        guard let lastScheduledReferenceAt = pair.nextScheduledReferenceAt else {
            return copy.afterFirstSuccessfulSync
        }

        let nextRun = lastScheduledReferenceAt.addingTimeInterval(TimeInterval(pair.scheduleMinutes * 60))
        return copy.formatTimestamp(nextRun)
    }

    private func accountName(for pair: SyncPair) -> String {
        appModel.accounts.first(where: { $0.id == pair.accountID })?.displayName ?? pair.parsedRemoteName ?? "—"
    }

    private var operationPhaseTitle: String {
        switch viewModel.operationPhase {
        case .idle:
            return ""
        case .queued:
            return appModel.copy.operationQueued
        case .running:
            return appModel.copy.operationRunning
        }
    }
}
