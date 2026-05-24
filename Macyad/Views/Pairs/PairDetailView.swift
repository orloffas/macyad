import MacyadCore
import SwiftUI

struct PairDetailView: View {
    let pair: SyncPair?
    @ObservedObject var viewModel: PairDetailViewModel
    var onSyncNow: (() -> Void)? = nil
    var onCheckYandex: (() -> Void)? = nil
    var onPullFromYandex: (() -> Void)? = nil

    var body: some View {
        Group {
            if let pair {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(pair.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Последний статус: \(severityTitle(viewModel.latestSeverity))")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button("Sync Now") { onSyncNow?() }
                                Button("Check Yandex") { onCheckYandex?() }
                                Button("Pull From Yandex") { onPullFromYandex?() }
                            }
                            .controlSize(.small)
                            .disabled(viewModel.isRunningOperation)
                        }

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Text("Локальная папка")
                                    .foregroundStyle(.secondary)
                                Text(pair.localFolderDisplayPath)
                            }
                            GridRow {
                                Text("Remote path")
                                    .foregroundStyle(.secondary)
                                Text(pair.remotePath)
                            }
                            GridRow {
                                Text("Интервал")
                                    .foregroundStyle(.secondary)
                                Text("\(pair.scheduleMinutes) мин")
                            }
                            GridRow {
                                Text("Delete policy")
                                    .foregroundStyle(.secondary)
                                Text(deletePolicyTitle(pair.deletePolicy))
                            }
                            GridRow {
                                Text("Последний sync")
                                    .foregroundStyle(.secondary)
                                Text(lastSyncTitle(for: pair))
                            }
                            GridRow {
                                Text("Следующий scheduled sync")
                                    .foregroundStyle(.secondary)
                                Text(nextScheduledSyncTitle(for: pair))
                            }
                        }
                        .font(.callout)

                        if let lastErrorMessage = viewModel.lastErrorMessage {
                            Text(lastErrorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        ActivityListView(events: viewModel.events)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "Пара не выбрана",
                    systemImage: "folder.badge.plus",
                    description: Text("Выберите существующую pair в sidebar или создайте новую.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func severityTitle(_ severity: Severity) -> String {
        switch severity {
        case .healthy:
            "Healthy"
        case .info:
            "Info"
        case .warning:
            "Warning"
        case .alarm:
            "Alarm"
        }
    }

    private func deletePolicyTitle(_ policy: SyncPair.DeletePolicy) -> String {
        switch policy {
        case .mirrorToYandex:
            "Mirror to Yandex"
        case .keepRemoteDeletesManual:
            "Keep remote deletes manual"
        }
    }

    private func lastSyncTitle(for pair: SyncPair) -> String {
        guard let lastSyncAt = pair.lastSyncAt else {
            return "Ещё не выполнялся"
        }

        return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func nextScheduledSyncTitle(for pair: SyncPair) -> String {
        guard let lastSyncAt = pair.lastSyncAt else {
            return "Сразу после первого удачного Sync Now"
        }

        let nextRun = lastSyncAt.addingTimeInterval(TimeInterval(pair.scheduleMinutes * 60))
        return nextRun.formatted(date: .abbreviated, time: .shortened)
    }
}
