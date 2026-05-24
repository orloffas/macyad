import MacyadCore
import SwiftUI

struct PairListRowView: View {
    let pair: SyncPair

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: pair.lastKnownSeverity == .alarm ? "exclamationmark.triangle.fill" : "folder")
                .foregroundStyle(pair.lastKnownSeverity == .alarm ? .orange : .secondary)

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
}
