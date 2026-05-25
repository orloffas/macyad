import MacyadCore
import SwiftUI

struct PairDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let pair: SyncPair?
    @ObservedObject var viewModel: PairDetailViewModel
    var onSyncNow: (() -> Void)? = nil
    var onCheckYandex: (() -> Void)? = nil
    var onPullFromYandex: (() -> Void)? = nil
    @State private var selectedActivityEvent: ActivityEvent?

    var body: some View {
        let copy = appModel.copy

        Group {
            if let pair {
                VStack(alignment: .leading, spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        header(pair: pair)
                        VStack(alignment: .leading, spacing: 10) {
                            titleBlock(pair: pair)
                            actionButtons
                        }
                    }

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text(copy.localFolderTitle)
                                .foregroundStyle(.secondary)
                            Text(pair.localFolderDisplayPath)
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                        GridRow {
                            Text(copy.remotePathTitle)
                                .foregroundStyle(.secondary)
                            Text(pair.remotePath)
                                .textSelection(.enabled)
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

                    if let lastErrorMessage = viewModel.lastErrorMessage {
                        LastErrorDisclosure(message: lastErrorMessage)
                    }

                    ActivityListView(events: viewModel.events, selectedEvent: $selectedActivityEvent)
                        .frame(maxHeight: .infinity)
                }
                .padding(16)
                .sheet(item: $selectedActivityEvent) { event in
                    ActivityDetailView(event: event, pair: pair)
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
    }

    private func header(pair: SyncPair) -> some View {
        HStack(alignment: .top) {
            titleBlock(pair: pair)

            Spacer(minLength: 12)

            actionButtons
        }
    }

    private func titleBlock(pair: SyncPair) -> some View {
        let copy = appModel.copy

        return VStack(alignment: .leading, spacing: 5) {
            Text(pair.name)
                .font(.title2)
                .fontWeight(.semibold)

            Text(copy.lastStatusTitle(severityTitle(viewModel.latestSeverity)))
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        let copy = appModel.copy

        return HStack(spacing: 8) {
            Button(copy.syncButtonTitle) { onSyncNow?() }
            Button(copy.checkButtonTitle) { onCheckYandex?() }
            Button(copy.pullButtonTitle) { onPullFromYandex?() }
        }
        .controlSize(.small)
        .disabled(viewModel.isRunningOperation)
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
        let copy = appModel.copy

        switch severity {
        case .healthy:
            return copy.severityHealthy
        case .info:
            return copy.severityInfo
        case .warning:
            return copy.severityWarning
        case .alarm:
            return copy.severityAlarm
        }
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

    private func lastSyncTitle(for pair: SyncPair) -> String {
        let copy = appModel.copy

        guard let lastSyncAt = pair.lastSyncAt else {
            return copy.neverSynced
        }

        return copy.formatTimestamp(lastSyncAt)
    }

    private func nextScheduledSyncTitle(for pair: SyncPair) -> String {
        let copy = appModel.copy

        guard let lastSyncAt = pair.lastSyncAt else {
            return copy.afterFirstSuccessfulSync
        }

        let nextRun = lastSyncAt.addingTimeInterval(TimeInterval(pair.scheduleMinutes * 60))
        return copy.formatTimestamp(nextRun)
    }
}
