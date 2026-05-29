import AppKit
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

    private enum SnapshotField {
        case path
        case size
        case mtime
        case md5
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let onApply: (ActivityIssueSet) async -> ActivityReviewApplyResult
    let onClose: (() -> Void)?

    @State private var issues: [ActivityFileIssue]
    @State private var selectedIssueIDs = Set<ActivityFileIssue.ID>()
    @State private var searchText = ""
    @State private var filter: IssueFilter = .all
    @State private var isApplying = false
    @State private var isRawComparisonExpanded = false

    init(
        issueSet: ActivityIssueSet,
        onApply: @escaping (ActivityIssueSet) async -> ActivityReviewApplyResult,
        onClose: (() -> Void)? = nil
    ) {
        self.onApply = onApply
        self.onClose = onClose
        _issues = State(initialValue: issueSet.issues)
    }

    var body: some View {
        let copy = appModel.copy
        let formatter = ActivityIssueFormatter(copy: copy)
        let columnWidths = ActivityIssueTableLayout.columnWidths(for: filteredIssues, formatter: formatter)

        VStack(alignment: .leading, spacing: 10) {
            headerRow(copy: copy)
            actionRow(copy: copy)

            VSplitView {
                reviewTable(copy: copy, formatter: formatter, columnWidths: columnWidths)
                    .frame(minHeight: 260, idealHeight: 360, maxHeight: .infinity)

                reviewDetailsPane(copy: copy, formatter: formatter)
                    .frame(minHeight: 260, idealHeight: 340, maxHeight: .infinity)
            }
            .frame(minHeight: 560)

            footerRow(copy: copy)
        }
        .controlSize(.small)
        .font(.callout)
        .padding(14)
        .frame(minWidth: 980, idealWidth: 1160, minHeight: 660, idealHeight: 780)
        .background(
            WindowAccessor { window in
                window.title = copy.issueReviewTitle
                window.minSize = NSSize(width: 980, height: 660)
            }
        )
        .onChange(of: singleSelectedIssue?.id) { _, _ in
            isRawComparisonExpanded = false
        }
        .onChange(of: visibleIssueIDs) { _, visibleIDs in
            selectedIssueIDs.formIntersection(Set(visibleIDs))
        }
    }

    private var filteredIssues: [ActivityFileIssue] {
        issues.filter { issue in
            matchesFilter(issue) && matchesSearch(issue)
        }
    }

    private var visibleIssueIDs: [ActivityFileIssue.ID] {
        filteredIssues.map(\.id)
    }

    private var selectedIssues: [ActivityFileIssue] {
        issues.filter { selectedIssueIDs.contains($0.id) }
    }

    private var singleSelectedIssue: ActivityFileIssue? {
        selectedIssues.count == 1 ? selectedIssues[0] : nil
    }

    private func headerRow(copy: AppCopy) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(copy.issueReviewTitle)
                .font(.headline.weight(.semibold))

            Spacer()

            TextField(copy.issueReviewSearchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
        }
    }

    private func actionRow(copy: AppCopy) -> some View {
        HStack(spacing: 8) {
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
    }

    private func footerRow(copy: AppCopy) -> some View {
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
                closeReviewSurface()
            }

            Button(copy.issueReviewApplyButtonTitle) {
                Task { await applyDecisions() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isApplying || issues.allSatisfy { $0.selectedDecision == .later })
        }
    }

    @ViewBuilder
    private func reviewTable(
        copy: AppCopy,
        formatter: ActivityIssueFormatter,
        columnWidths: ActivityIssueTableLayout.ColumnWidths
    ) -> some View {
        if filteredIssues.isEmpty {
            ContentUnavailableView(
                copy.issueReviewNoIssues,
                systemImage: "doc.text.magnifyingglass"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(filteredIssues, selection: $selectedIssueIDs) {
                TableColumn(copy.issueReviewPathColumnTitle) { issue in
                    Text(issue.directoryPath)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .width(min: 70, ideal: columnWidths.pathIdeal, max: 180)

                TableColumn(copy.issueReviewFileColumnTitle) { issue in
                    Text(issue.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .width(min: 120, ideal: columnWidths.fileIdeal, max: 300)

                TableColumn(copy.issueReviewProblemColumnTitle) { issue in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatter.problemTitle(for: issue.problemKind))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatter.differencesTitle(for: issue.differences))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .width(min: 160, ideal: columnWidths.problemIdeal, max: 320)

                TableColumn(copy.issueReviewDecisionColumnTitle) { issue in
                    decisionPicker(copy: copy, selection: decisionBinding(for: issue.id))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .width(min: columnWidths.decisionIdeal, ideal: columnWidths.decisionIdeal, max: columnWidths.decisionIdeal)

                TableColumn("") { _ in
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func reviewDetailsPane(copy: AppCopy, formatter: ActivityIssueFormatter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let issue = singleSelectedIssue {
                selectedIssueDetails(issue, copy: copy, formatter: formatter)
            } else if selectedIssues.isEmpty {
                ContentUnavailableView(
                    copy.issueReviewNoSelectionTitle,
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    description: Text(copy.issueReviewNoSelectionMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                multiSelectionSummary(copy: copy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 4)
    }

    private func selectedIssueDetails(
        _ issue: ActivityFileIssue,
        copy: AppCopy,
        formatter: ActivityIssueFormatter
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.fileName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                Text(issue.directoryPath)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    narrativeColumn(issue: issue, copy: copy, formatter: formatter)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    snapshotsColumn(issue: issue, copy: copy, formatter: formatter)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 340, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    narrativeColumn(issue: issue, copy: copy, formatter: formatter)
                    snapshotsColumn(issue: issue, copy: copy, formatter: formatter)
                }
            }

            DisclosureGroup(isExpanded: $isRawComparisonExpanded) {
                ScrollView(.vertical) {
                    Text(formatter.rawComparisonBlock(for: issue))
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .frame(minHeight: 84, idealHeight: 110, maxHeight: 140)
            } label: {
                Text(copy.issueReviewRawSectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func narrativeColumn(
        issue: ActivityFileIssue,
        copy: AppCopy,
        formatter: ActivityIssueFormatter
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection(copy.issueReviewMeaningSectionTitle) {
                Text(formatter.issueMeaning(for: issue))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            detailSection(copy.issueReviewDecisionSectionTitle) {
                decisionPicker(copy: copy, selection: decisionBinding(for: issue.id))
                Text(formatter.problemTitle(for: issue.problemKind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func snapshotsColumn(
        issue: ActivityFileIssue,
        copy: AppCopy,
        formatter: ActivityIssueFormatter
    ) -> some View {
        detailSection(copy.issueReviewSnapshotsSectionTitle) {
            VStack(alignment: .leading, spacing: 8) {
                snapshotSection(title: copy.issueReviewLocalColumnTitle, snapshot: issue.localSnapshot, copy: copy, formatter: formatter)
                snapshotSection(title: copy.issueReviewRemoteColumnTitle, snapshot: issue.remoteSnapshot, copy: copy, formatter: formatter)
                snapshotSection(title: copy.issueReviewBaselineSectionTitle, snapshot: issue.baselineSnapshot, copy: copy, formatter: formatter)
            }
        }
    }

    private func multiSelectionSummary(copy: AppCopy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.issueReviewMultipleSelectionTitle(count: selectedIssues.count))
                .font(.title3.weight(.semibold))

            Text(copy.issueReviewMultipleSelectionMessage(unresolvedCount: selectedIssues.filter { $0.selectedDecision == .later }.count))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            summaryRow(label: copy.issueReviewFilterConflicts, value: selectedIssues.filter { $0.problemKind == .conflict }.count)
            summaryRow(label: copy.issueReviewFilterRemoteOnly, value: selectedIssues.filter { $0.problemKind == .remoteOnlyChanged }.count)
            summaryRow(label: copy.issueReviewFilterLocalOnly, value: selectedIssues.filter { $0.problemKind == .localOnlyChanged }.count)
            summaryRow(label: copy.issueReviewFilterDeleteVsModify, value: selectedIssues.filter { $0.problemKind == .deleteVsModifyConflict }.count)
            summaryRow(label: copy.issueDecisionLaterTitle, value: selectedIssues.filter { $0.selectedDecision == .later }.count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func snapshotSection(
        title: String,
        snapshot: PairSnapshotEntry?,
        copy: AppCopy,
        formatter: ActivityIssueFormatter
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let snapshot {
                snapshotRow(label: snapshotFieldTitle(.path, copy: copy), value: snapshot.path)
                snapshotRow(label: snapshotFieldTitle(.size, copy: copy), value: "\(snapshot.size)")
                snapshotRow(label: snapshotFieldTitle(.mtime, copy: copy), value: snapshot.modTime?.ISO8601Format() ?? "<nil>")
                snapshotRow(label: snapshotFieldTitle(.md5, copy: copy), value: snapshot.md5 ?? "<nil>")
            } else {
                Text(formatter.snapshotSummary(nil))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func snapshotRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func snapshotFieldTitle(_ field: SnapshotField, copy: AppCopy) -> String {
        switch (copy.language, field) {
        case (.russian, .path):
            "Путь"
        case (.english, .path):
            "Path"
        case (.russian, .size):
            "Размер"
        case (.english, .size):
            "Size"
        case (.russian, .mtime):
            "mtime"
        case (.english, .mtime):
            "mtime"
        case (.russian, .md5):
            "md5"
        case (.english, .md5):
            "md5"
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

    private func decisionPicker(copy: AppCopy, selection: Binding<FileResolutionDecision>) -> some View {
        Picker("", selection: selection) {
            Text(copy.issueDecisionKeepLocalTitle).tag(FileResolutionDecision.keepLocal)
            Text(copy.issueDecisionKeepRemoteTitle).tag(FileResolutionDecision.keepRemote)
            Text(copy.issueDecisionKeepBothTitle).tag(FileResolutionDecision.keepBoth)
            Text(copy.issueDecisionLaterTitle).tag(FileResolutionDecision.later)
        }
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
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
            closeReviewSurface()
        }
    }

    private func closeReviewSurface() {
        if let onClose {
            onClose()
        } else {
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

    private func summaryRow(label: String, value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(.callout, design: .monospaced))
        }
    }
}
