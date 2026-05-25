import MacyadCore
import SwiftUI

struct PairListRowView: View {
    let pair: SyncPair
    let severity: Severity

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .lineLimit(1)

                Text(pair.remotePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var symbolName: String {
        switch severity {
        case .healthy, .info:
            return "folder"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .alarm:
            return "xmark.octagon.fill"
        }
    }

    private var symbolColor: Color {
        switch severity {
        case .healthy, .info:
            return .secondary
        case .warning:
            return .orange
        case .alarm:
            return .red
        }
    }
}
