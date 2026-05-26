import MacyadCore
import SwiftUI

struct PairListRowView: View {
    let pair: SyncPair
    let severity: Severity
    let accountLabel: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .lineLimit(1)

                Text(pair.remotePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let accountLabel {
                    Text(accountLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let statusColor {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color? {
        switch severity {
        case .healthy:
            return nil
        case .info:
            return .blue
        case .warning:
            return .orange
        case .alarm:
            return .red
        }
    }
}
