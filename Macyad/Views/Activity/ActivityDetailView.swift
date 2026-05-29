import AppKit
import MacyadCore
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let event: ActivityEvent
    let pair: SyncPair?
    let initialOpenIssueReview: Bool
    let onApplyIssueReview: ((ActivityIssueSet) async -> ActivityReviewApplyResult)?

    @State private var displayedEvent: ActivityEvent
    @State private var didAutoOpenIssueReview = false
    @State private var hostWindow: NSWindow?

    init(
        event: ActivityEvent,
        pair: SyncPair?,
        initialOpenIssueReview: Bool = false,
        onApplyIssueReview: ((ActivityIssueSet) async -> ActivityReviewApplyResult)? = nil
    ) {
        self.event = event
        self.pair = pair
        self.initialOpenIssueReview = initialOpenIssueReview
        self.onApplyIssueReview = onApplyIssueReview
        _displayedEvent = State(initialValue: event)
    }

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbolName(for: displayedEvent.severity))
                    .foregroundStyle(color(for: displayedEvent.severity))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(severityTitle(displayedEvent.severity, copy: copy))
                        .font(.headline)
                    Text(copy.formatTimestamp(displayedEvent.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let pair {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text(copy.activityPairTitle)
                            .foregroundStyle(.secondary)
                        Text(pair.name)
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text(copy.activityLocalPathTitle)
                            .foregroundStyle(.secondary)
                        Text(pair.localFolderDisplayPath)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                    GridRow {
                        Text(copy.activityRemotePathTitle)
                            .foregroundStyle(.secondary)
                        Text(pair.remotePath)
                            .textSelection(.enabled)
                    }
                }
                .font(.callout)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(copy.activitySummaryTitle)
                    .font(.subheadline.weight(.semibold))
                Text(displayedEvent.message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if displayedEvent.issueSet != nil, onApplyIssueReview != nil {
                HStack {
                    Button(copy.reviewFilesButtonTitle) {
                        presentIssueReviewWindow()
                    }

                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(copy.activityFullDetailsTitle)
                    .font(.subheadline.weight(.semibold))
                ScrollView {
                    Text(displayedEvent.details ?? copy.activityNoDetails)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 110, maxHeight: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            HStack {
                Spacer()
                Button(copy.closeButtonTitle) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(minWidth: 480, idealWidth: 560, maxWidth: 680, minHeight: 360, idealHeight: 440)
        .background(
            WindowAccessor { window in
                hostWindow = window
            }
        )
        .onAppear {
            if initialOpenIssueReview, displayedEvent.issueSet != nil, !didAutoOpenIssueReview {
                didAutoOpenIssueReview = true
                presentIssueReviewWindow()
            }
        }
        .onDisappear {
            appModel.closeIssueReviewWindow()
        }
    }

    private func presentIssueReviewWindow() {
        guard let issueSet = displayedEvent.issueSet, let onApplyIssueReview else {
            return
        }

        let presentingWindow = hostWindow?.sheetParent ?? hostWindow
        appModel.presentIssueReviewWindow(presentingWindow, issueSet) { updatedIssueSet in
            let result = await onApplyIssueReview(updatedIssueSet)
            if let replacementEvent = result.replacementEvent {
                displayedEvent = replacementEvent
            }
            if result.shouldDismissDetail {
                dismiss()
            }
            return result
        }
    }

    private func severityTitle(_ severity: Severity, copy: AppCopy) -> String {
        switch severity {
        case .healthy:
            copy.severityHealthy
        case .info:
            copy.severityInfo
        case .warning:
            copy.severityWarning
        case .alarm:
            copy.severityAlarm
        }
    }

    private func symbolName(for severity: Severity) -> String {
        switch severity {
        case .healthy:
            "checkmark.circle.fill"
        case .info:
            "info.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .alarm:
            "xmark.octagon.fill"
        }
    }

    private func color(for severity: Severity) -> Color {
        switch severity {
        case .healthy:
            .green
        case .info:
            .blue
        case .warning:
            .orange
        case .alarm:
            .red
        }
    }
}
