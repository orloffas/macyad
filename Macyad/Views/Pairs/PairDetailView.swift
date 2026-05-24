import MacyadCore
import SwiftUI

struct PairDetailView: View {
    let pair: SyncPair?

    var body: some View {
        Group {
            if let pair {
                VStack(alignment: .leading, spacing: 14) {
                    Text(pair.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    LabeledContent("Статус", value: severityTitle(pair.lastKnownSeverity))
                    LabeledContent("Локальная папка", value: pair.localFolderDisplayPath)
                    LabeledContent("Remote path", value: pair.remotePath)
                    LabeledContent("Интервал", value: "\(pair.scheduleMinutes) мин")
                    LabeledContent("Delete policy", value: deletePolicyTitle(pair.deletePolicy))

                    Spacer()
                }
                .padding(20)
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
}
