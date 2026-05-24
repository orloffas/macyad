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
