import MacyadCore
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appModel.statusSummary.title)
                    .font(.headline)

                Text("Предупреждения \(appModel.statusSummary.warningCount) · Аварии \(appModel.statusSummary.alarmCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let activePair = appModel.activePair {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activePair.name)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Button("Синхр.") {
                            appModel.runSyncNowForSelectedPair()
                        }

                        Button("Проверить") {
                            appModel.runCheckForSelectedPair()
                        }

                        Button("Загрузить") {
                            appModel.runPullForSelectedPair()
                        }
                    }
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Последние события")
                    .font(.subheadline.weight(.semibold))

                if appModel.recentEvents.isEmpty {
                    Text("Пока пусто")
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

                                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Открыть главное окно") {
                appModel.openMainWindow()
            }
            .keyboardShortcut(.defaultAction)

            SettingsLink {
                Label("Настройки", systemImage: "gearshape")
            }

            Button("Завершить MacYaD") {
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
