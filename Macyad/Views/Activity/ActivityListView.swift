import MacyadCore
import SwiftUI

struct ActivityListView: View {
    let events: [ActivityEvent]

    var body: some View {
        GroupBox("Activity") {
            if events.isEmpty {
                ContentUnavailableView(
                    "Пока пусто",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("События этой pair появятся после `Sync`, `Check` или `Pull`.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                List(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: symbolName(for: event.severity))
                            .foregroundStyle(color(for: event.severity))
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.message)
                                .lineLimit(2)

                            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
                .frame(minHeight: 180)
            }
        }
    }

    private func symbolName(for severity: Severity) -> String {
        switch severity {
        case .healthy:
            "checkmark.circle.fill"
        case .info:
            "info.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .alarm:
            "xmark.octagon.fill"
        }
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
