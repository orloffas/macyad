import MacyadCore
import SwiftUI

struct ActivityListView: View {
    @EnvironmentObject private var appModel: AppModel
    let events: [ActivityEvent]
    @Binding var selectedEvent: ActivityEvent?
    @State private var expandedRunIDs = Set<ActivityEventRun.ID>()

    init(events: [ActivityEvent], selectedEvent: Binding<ActivityEvent?>) {
        self.events = events
        self._selectedEvent = selectedEvent
    }

    var body: some View {
        let copy = appModel.copy
        let runs = ActivityEventRun.makeRuns(from: events)

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
                        ForEach(runs) { run in
                            if run.isCollapsedByDefault {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedRunIDs.contains(run.id) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedRunIDs.insert(run.id)
                                            } else {
                                                expandedRunIDs.remove(run.id)
                                            }
                                        }
                                    )
                                ) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(run.events) { event in
                                            Button {
                                                selectedEvent = event
                                            } label: {
                                                row(for: event, copy: copy, isNested: true)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Rectangle())
                                            .padding(.vertical, 6)

                                            if event.id != run.events.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    collapsedRow(for: run, copy: copy)
                                }
                                .padding(.vertical, 7)
                            } else if let event = run.events.first {
                                Button {
                                    selectedEvent = event
                                } label: {
                                    row(for: event, copy: copy)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .padding(.vertical, 7)
                            }

                            if run.id != runs.last?.id {
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

    private func row(for event: ActivityEvent, copy: AppCopy, isNested: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if isNested {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
            }

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

    private func collapsedRow(for run: ActivityEventRun, copy: AppCopy) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName(for: run.representative.severity))
                .foregroundStyle(color(for: run.representative.severity))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(run.representative.message)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)

                HStack(spacing: 6) {
                    Text(copy.activityCollapsedRunSummary(count: run.count))
                    Text("·")
                    Text(copy.formatTimestamp(run.representative.date))
                }
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
