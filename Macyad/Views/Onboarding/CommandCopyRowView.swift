import SwiftUI

struct CommandCopyRowView: View {
    @EnvironmentObject private var appModel: AppModel
    let title: String
    let command: String
    let copied: Bool
    let accessibilityIdentifier: String?
    let onCopy: () -> Void

    var body: some View {
        let copy = appModel.copy

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(copied ? copy.copiedButtonTitle : copy.copyButtonTitle)
            .accessibilityLabel(copied ? copy.copiedButtonTitle : copy.copyButtonTitle)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
