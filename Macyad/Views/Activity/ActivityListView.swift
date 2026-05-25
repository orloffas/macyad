import MacyadCore
import SwiftUI

struct ActivityListView: View {
    @EnvironmentObject private var appModel: AppModel
    let events: [ActivityEvent]
    @Binding var selectedEvent: ActivityEvent?

    init(events: [ActivityEvent], selectedEvent: Binding<ActivityEvent?>) {
        self.events = events
        self._selectedEvent = selectedEvent
    }

    var body: some View {
        let copy = appModel.copy

        GroupBox(copy.journalTitle) {
            if events.isEmpty {
                Label(copy.journalEmptyHint, systemImage: "clock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(events) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                row(for: event, copy: copy)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(.vertical, 7)

                            if event.id != events.last?.id {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(for event: ActivityEvent, copy: AppCopy) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName(for: event.severity))
                .foregroundStyle(color(for: event.severity))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.message)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)

                Text(copy.formatTimestamp(event.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
