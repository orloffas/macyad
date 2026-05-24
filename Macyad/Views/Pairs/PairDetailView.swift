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
                                Text("Локальная папка")
                                    .foregroundStyle(.secondary)
                                Text(pair.localFolderDisplayPath)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }
                            GridRow {
                                Text("Путь на Yandex")
                                    .foregroundStyle(.secondary)
                                Text(pair.remotePath)
                                    .textSelection(.enabled)
                            }
                            GridRow {
                                Text("Интервал")
                                    .foregroundStyle(.secondary)
                                Text("\(pair.scheduleMinutes) мин")
                            }
                            GridRow {
                                Text("Политика удаления")
                                    .foregroundStyle(.secondary)
                                Text(deletePolicyTitle(pair.deletePolicy))
                            }
                            GridRow {
                                Text("Последняя синхронизация")
                                    .foregroundStyle(.secondary)
                                Text(lastSyncTitle(for: pair))
                            }
                            GridRow {
                                Text("Следующая синхронизация")
                                    .foregroundStyle(.secondary)
                                Text(nextScheduledSyncTitle(for: pair))
                            }
                        }
                        .font(.callout)

                        if let lastErrorMessage = viewModel.lastErrorMessage {
                            LastErrorDisclosure(message: lastErrorMessage)
                        }

                        ActivityListView(events: viewModel.events)
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "Пара не выбрана",
                    systemImage: "folder.badge.plus",
                    description: Text("Выберите существующую пару в боковой панели или создайте новую.")
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
        VStack(alignment: .leading, spacing: 5) {
            Text(pair.name)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Последний статус: \(severityTitle(viewModel.latestSeverity))")
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Синхронизировать") { onSyncNow?() }
            Button("Проверить Yandex") { onCheckYandex?() }
            Button("Загрузить из Yandex") { onPullFromYandex?() }
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
                Label("Последняя ошибка", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.callout.weight(.semibold))
            }
        }
    }

    private func severityTitle(_ severity: Severity) -> String {
        switch severity {
        case .healthy:
            "Норма"
        case .info:
            "Информация"
        case .warning:
            "Предупреждение"
        case .alarm:
            "Авария"
        }
    }

    private func deletePolicyTitle(_ policy: SyncPair.DeletePolicy) -> String {
        switch policy {
        case .mirrorToYandex:
            "Зеркалить в Yandex"
        case .keepRemoteDeletesManual:
            "Удаления на Yandex вручную"
        }
    }

    private func lastSyncTitle(for pair: SyncPair) -> String {
        guard let lastSyncAt = pair.lastSyncAt else {
            return "Ещё не выполнялась"
        }

        return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func nextScheduledSyncTitle(for pair: SyncPair) -> String {
        guard let lastSyncAt = pair.lastSyncAt else {
            return "После первой успешной синхронизации"
        }

        let nextRun = lastSyncAt.addingTimeInterval(TimeInterval(pair.scheduleMinutes * 60))
        return nextRun.formatted(date: .abbreviated, time: .shortened)
    }
}
