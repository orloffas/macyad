import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.statusSummary.title)
                .font(.headline)

            Text("Warnings \(appModel.statusSummary.warningCount) · Alarms \(appModel.statusSummary.alarmCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let selectedPair = appModel.selectedPair {
                Divider()

                Text(selectedPair.name)
                    .font(.subheadline.weight(.medium))

                Button("Sync Now") {
                    appModel.runSyncNowForSelectedPair()
                }

                Button("Check Yandex") {
                    appModel.runCheckForSelectedPair()
                }

                Button("Pull From Yandex") {
                    appModel.runPullForSelectedPair()
                }
            }

            Divider()

            Button("Open Main Window") {
                appModel.openMainWindow()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
    }
}
