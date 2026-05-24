import MacyadCore
import SwiftUI

struct ActivityListView: View {
    let events: [ActivityEvent]

    var body: some View {
        GroupBox("Журнал") {
            if events.isEmpty {
                Label("События появятся после синхронизации, проверки или загрузки.", systemImage: "clock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: symbolName(for: event.severity))
                                    .foregroundStyle(color(for: event.severity))
                                    .frame(width: 14)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.message)
                                        .lineLimit(nil)
                                        .textSelection(.enabled)

                                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 7)

                            if event.id != events.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(minHeight: 96, idealHeight: 150, maxHeight: 220)
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
