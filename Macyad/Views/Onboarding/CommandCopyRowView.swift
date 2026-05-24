import SwiftUI

struct CommandCopyRowView: View {
    let title: LocalizedStringKey
    let command: String
    let copied: Bool
    let accessibilityIdentifier: String?
    let onCopy: () -> Void

    var body: some View {
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
            .help(copied ? String(localized: "common.copied") : String(localized: "common.copy"))
            .accessibilityLabel(copied ? String(localized: "common.copied") : String(localized: "common.copy"))
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
