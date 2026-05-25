import MacyadCore
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appModel.statusSummary.title)
                    .font(.headline)

                Text(copy.warningsAndAlarmsSummary(
                    warnings: appModel.statusSummary.warningCount,
                    alarms: appModel.statusSummary.alarmCount
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let activePair = appModel.activePair {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activePair.name)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Button(copy.syncShortButtonTitle) {
                            appModel.runSyncNowForSelectedPair()
                        }
                        .help(copy.pushActionDescription)

                        Button(copy.checkShortButtonTitle) {
                            appModel.runCheckForSelectedPair()
                        }
                        .help(copy.checkActionDescription)

                        Button(copy.pullShortButtonTitle) {
                            appModel.runPullForSelectedPair()
                        }
                        .help(copy.pullActionDescription)
                    }
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.recentEventsTitle)
                    .font(.subheadline.weight(.semibold))

                if appModel.recentEvents.isEmpty {
                    Text(copy.emptyEventsTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.recentEvents) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(color(for: event.severity))
                                .frame(width: 7, height: 7)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.message)
                                    .font(.callout)
                                    .lineLimit(2)

                                Text(copy.formatTimestamp(event.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(copy.openMainWindowTitle) {
                appModel.openMainWindow()
            }
            .keyboardShortcut(.defaultAction)

            Button(copy.quitApplicationTitle) {
                appModel.quitApplication()
            }
        }
        .padding(14)
        .frame(width: 360, alignment: .leading)
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
