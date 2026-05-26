import MacyadCore
import SwiftUI

struct IssueReviewSheetView: View {
    private enum IssueFilter: String, CaseIterable, Identifiable {
        case all
        case conflicts
        case remoteOnly
        case localOnly
        case deleteVsModify
        case baselineMissing

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let onApply: (ActivityIssueSet) async -> ActivityReviewApplyResult

    @State private var issues: [ActivityFileIssue]
    @State private var selectedIssueIDs = Set<ActivityFileIssue.ID>()
    @State private var searchText = ""
    @State private var filter: IssueFilter = .all
    @State private var isApplying = false

    init(issueSet: ActivityIssueSet, onApply: @escaping (ActivityIssueSet) async -> ActivityReviewApplyResult) {
        self.onApply = onApply
        _issues = State(initialValue: issueSet.issues)
    }

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(copy.issueReviewTitle)
                    .font(.title3.weight(.semibold))

                Spacer()

                TextField(copy.issueReviewSearchPlaceholder, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
            }

            HStack(spacing: 10) {
                Picker(copy.issueReviewFilterLabel, selection: $filter) {
                    ForEach(IssueFilter.allCases) { item in
                        Text(title(for: item, copy: copy)).tag(item)
                    }
                }
                .pickerStyle(.menu)

                Button(copy.issueReviewSelectAllVisible) {
                    selectedIssueIDs = Set(filteredIssues.map(\.id))
                }
                .disabled(filteredIssues.isEmpty)

                Button(copy.issueReviewClearSelection) {
                    selectedIssueIDs.removeAll()
                }
                .disabled(selectedIssueIDs.isEmpty)

                Menu(copy.issueReviewSetSelectedTo) {
                    decisionButtons(copy: copy) { decision in
                        apply(decision: decision, to: selectedIssueIDs)
                    }
                }
                .disabled(selectedIssueIDs.isEmpty)

                Menu(copy.issueReviewSetAllVisibleTo) {
                    decisionButtons(copy: copy) { decision in
                        apply(decision: decision, to: Set(filteredIssues.map(\.id)))
                    }
                }
                .disabled(filteredIssues.isEmpty)

                Spacer()
            }

            if filteredIssues.isEmpty {
                ContentUnavailableView(
                    copy.issueReviewNoIssues,
                    systemImage: "doc.text.magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredIssues, selection: $selectedIssueIDs) {
                    TableColumn(copy.issueReviewPathColumnTitle) { issue in
                        Text(issue.relativePath)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(2)
                    }
                    .width(min: 220, ideal: 320)

                    TableColumn(copy.issueReviewFileColumnTitle) { issue in
                        Text(issue.fileName)
                            .lineLimit(2)
                    }
                    .width(min: 120, ideal: 170)

                    TableColumn(copy.issueReviewProblemColumnTitle) { issue in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(problemTitle(for: issue.problemKind, copy: copy))
                            Text(differencesTitle(for: issue.differences, copy: copy))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 170, ideal: 210)

                    TableColumn(copy.issueReviewLocalColumnTitle) { issue in
                        Text(snapshotSummary(issue.localSnapshot))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 170, ideal: 220)

                    TableColumn(copy.issueReviewRemoteColumnTitle) { issue in
                        Text(snapshotSummary(issue.remoteSnapshot))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 170, ideal: 220)

                    TableColumn(copy.issueReviewDecisionColumnTitle) { issue in
                        Picker("", selection: decisionBinding(for: issue.id)) {
                            Text(copy.issueDecisionKeepLocalTitle).tag(FileResolutionDecision.keepLocal)
                            Text(copy.issueDecisionKeepRemoteTitle).tag(FileResolutionDecision.keepRemote)
                            Text(copy.issueDecisionKeepBothTitle).tag(FileResolutionDecision.keepBoth)
                            Text(copy.issueDecisionLaterTitle).tag(FileResolutionDecision.later)
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .width(min: 140, ideal: 150)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 360)
            }

            HStack {
                Text(copy.issueReviewSummary(
                    visibleCount: filteredIssues.count,
                    selectedCount: selectedIssueIDs.count,
                    unresolvedCount: issues.filter { $0.selectedDecision == .later }.count
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(copy.cancelButtonTitle) {
                    dismiss()
                }

                Button(copy.issueReviewApplyButtonTitle) {
                    Task { await applyDecisions() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying || issues.allSatisfy { $0.selectedDecision == .later })
            }
        }
        .padding(18)
        .frame(minWidth: 980, idealWidth: 1120, minHeight: 620, idealHeight: 700)
    }

    private var filteredIssues: [ActivityFileIssue] {
        issues.filter { issue in
            matchesFilter(issue) && matchesSearch(issue)
        }
    }

    private func decisionBinding(for issueID: ActivityFileIssue.ID) -> Binding<FileResolutionDecision> {
        Binding(
            get: {
                issues.first(where: { $0.id == issueID })?.selectedDecision ?? .later
            },
            set: { newValue in
                guard let index = issues.firstIndex(where: { $0.id == issueID }) else {
                    return
                }
                issues[index].selectedDecision = newValue
            }
        )
    }

    @ViewBuilder
    private func decisionButtons(copy: AppCopy, apply: @escaping (FileResolutionDecision) -> Void) -> some View {
        Button(copy.issueDecisionKeepLocalTitle) { apply(.keepLocal) }
        Button(copy.issueDecisionKeepRemoteTitle) { apply(.keepRemote) }
        Button(copy.issueDecisionKeepBothTitle) { apply(.keepBoth) }
        Button(copy.issueDecisionLaterTitle) { apply(.later) }
    }

    private func apply(decision: FileResolutionDecision, to issueIDs: Set<ActivityFileIssue.ID>) {
        issues = issues.map { issue in
            guard issueIDs.contains(issue.id) else {
                return issue
            }

            var updatedIssue = issue
            updatedIssue.selectedDecision = decision
            return updatedIssue
        }
    }

    private func applyDecisions() async {
        isApplying = true
        defer { isApplying = false }

        let result = await onApply(ActivityIssueSet(issues: issues))
        if let replacementEvent = result.replacementEvent, let replacementIssueSet = replacementEvent.issueSet {
            issues = replacementIssueSet.issues
            selectedIssueIDs = selectedIssueIDs.intersection(Set(issues.map(\.id)))
        }

        if result.shouldDismissDetail {
            dismiss()
        }
    }

    private func matchesFilter(_ issue: ActivityFileIssue) -> Bool {
        switch filter {
        case .all:
            return true
        case .conflicts:
            return issue.problemKind == .conflict
        case .remoteOnly:
            return issue.problemKind == .remoteOnlyChanged
        case .localOnly:
            return issue.problemKind == .localOnlyChanged
        case .deleteVsModify:
            return issue.problemKind == .deleteVsModifyConflict
        case .baselineMissing:
            return issue.differences.contains(.baselineMissing)
        }
    }

    private func matchesSearch(_ issue: ActivityFileIssue) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        return issue.relativePath.localizedCaseInsensitiveContains(trimmed)
            || issue.fileName.localizedCaseInsensitiveContains(trimmed)
    }

    private func title(for filter: IssueFilter, copy: AppCopy) -> String {
        switch filter {
        case .all:
            copy.issueReviewFilterAll
        case .conflicts:
            copy.issueReviewFilterConflicts
        case .remoteOnly:
            copy.issueReviewFilterRemoteOnly
        case .localOnly:
            copy.issueReviewFilterLocalOnly
        case .deleteVsModify:
            copy.issueReviewFilterDeleteVsModify
        case .baselineMissing:
            copy.issueReviewFilterBaselineMissing
        }
    }

    private func problemTitle(for kind: ActivityFileProblemKind, copy: AppCopy) -> String {
        let isRussian = copy.language == .russian

        return switch kind {
        case .remoteOnlyChanged:
            isRussian ? "Изменён только remote" : "Remote only changed"
        case .localOnlyChanged:
            isRussian ? "Изменён только local" : "Local only changed"
        case .conflict:
            isRussian ? "Конфликт изменений" : "Conflict"
        case .deleteVsModifyConflict:
            isRussian ? "Удаление vs изменение" : "Delete vs modify"
        }
    }

    private func differencesTitle(for differences: [ActivityFileDifference], copy: AppCopy) -> String {
        let isRussian = copy.language == .russian

        let labels = differences.map { difference -> String in
            switch difference {
            case .sizeDiffers:
                return isRussian ? "разный размер" : "size differs"
            case .mtimeDiffers:
                return isRussian ? "разный mtime" : "mtime differs"
            case .hashDiffers:
                return isRussian ? "разный hash" : "hash differs"
            case .missingLocal:
                return isRussian ? "нет на local" : "missing on local"
            case .missingRemote:
                return isRussian ? "нет на remote" : "missing on remote"
            case .deleteVsModify:
                return isRussian ? "удаление vs изменение" : "delete vs modify"
            case .baselineMissing:
                return isRussian ? "нет baseline" : "baseline missing"
            }
        }

        return labels.joined(separator: " · ")
    }

    private func snapshotSummary(_ snapshot: PairSnapshotEntry?) -> String {
        guard let snapshot else {
            return appModel.copy.language == .russian ? "<нет>" : "<missing>"
        }

        let formatter = ISO8601DateFormatter()
        let mtime = snapshot.modTime.map { formatter.string(from: $0) } ?? "<nil>"
        let hash = snapshot.md5 ?? "<nil>"
        return "size=\(snapshot.size)\nmtime=\(mtime)\nmd5=\(hash)"
    }
}
