import MacyadCore
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let event: ActivityEvent
    let pair: SyncPair?

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbolName(for: event.severity))
                    .foregroundStyle(color(for: event.severity))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(severityTitle(event.severity, copy: copy))
                        .font(.headline)
                    Text(copy.formatTimestamp(event.date))
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
                Text(event.message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(copy.activityFullDetailsTitle)
                    .font(.subheadline.weight(.semibold))
                ScrollView {
                    Text(event.details ?? copy.activityNoDetails)
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
