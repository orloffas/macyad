import AppKit
import Foundation

public struct ActivityIssueFormatter: Sendable {
    public let copy: AppCopy

    public init(copy: AppCopy) {
        self.copy = copy
    }

    public func problemTitle(for kind: ActivityFileProblemKind) -> String {
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

    public func differencesTitle(for differences: [ActivityFileDifference]) -> String {
        let isRussian = copy.language == .russian
        let labels = differences.map { difference -> String in
            switch difference {
            case .sizeDiffers:
                isRussian ? "разный размер" : "size differs"
            case .mtimeDiffers:
                isRussian ? "разный mtime" : "mtime differs"
            case .hashDiffers:
                isRussian ? "разный hash" : "hash differs"
            case .missingLocal:
                isRussian ? "нет на local" : "missing on local"
            case .missingRemote:
                isRussian ? "нет на remote" : "missing on remote"
            case .deleteVsModify:
                isRussian ? "удаление vs изменение" : "delete vs modify"
            case .baselineMissing:
                isRussian ? "нет baseline" : "baseline missing"
            }
        }

        return labels.joined(separator: " · ")
    }

    public func issueMeaning(for issue: ActivityFileIssue) -> String {
        let primary: String = switch (copy.language, issue.problemKind) {
        case (.russian, .remoteOnlyChanged):
            "Файл сейчас существует только на стороне remote. На стороне local его нет."
        case (.english, .remoteOnlyChanged):
            "The file currently exists only on the remote side. The local side does not have it."
        case (.russian, .localOnlyChanged):
            "Файл сейчас существует только на стороне local. На стороне remote его нет."
        case (.english, .localOnlyChanged):
            "The file currently exists only on the local side. The remote side does not have it."
        case (.russian, .conflict):
            "Файл изменился и на local, и на remote, при этом текущие версии не совпадают между собой."
        case (.english, .conflict):
            "The file changed on both local and remote, and the current versions do not match each other."
        case (.russian, .deleteVsModifyConflict):
            "На одной стороне файл удалён, а на другой стороне осталась изменённая или просто всё ещё существующая версия."
        case (.english, .deleteVsModifyConflict):
            "One side deleted the file while the other side still has a changed or surviving version."
        }

        var sentences = [primary]

        if issue.differences.contains(.baselineMissing) {
            sentences.append(copy.language == .russian
                ? "Для этого пути ещё нет согласованного baseline, поэтому приложение не может считать текущее состояние уже подтверждённым."
                : "There is no agreed baseline for this path yet, so the app cannot treat the current state as already reconciled.")
        }

        let comparisonSummary = differencesTitle(for: issue.differences.filter {
            $0 != .baselineMissing
        })
        if !comparisonSummary.isEmpty {
            sentences.append(copy.language == .russian
                ? "Наблюдаемые признаки: \(comparisonSummary)."
                : "Observed signals: \(comparisonSummary).")
        }

        return sentences.joined(separator: " ")
    }

    public func rawComparisonBlock(for issue: ActivityFileIssue) -> String {
        """
        Path: \(issue.directoryPath)
        File: \(issue.fileName)
        Problem: \(rawProblemValue(for: issue.problemKind))
        Differences: \(rawDifferencesValue(for: issue.differences))
        Local: \(snapshotSummary(issue.localSnapshot))
        Remote: \(snapshotSummary(issue.remoteSnapshot))
        Baseline: \(snapshotSummary(issue.baselineSnapshot))
        """
    }

    public func rawProblemValue(for kind: ActivityFileProblemKind) -> String {
        problemCode(for: kind)
    }

    public func rawDifferencesValue(for differences: [ActivityFileDifference]) -> String {
        differenceCodes(for: differences)
    }

    public func issueDetailsBlock(for issue: ActivityFileIssue) -> String {
        """
        \(copy.issueReviewMeaningSectionTitle): \(issueMeaning(for: issue))

        \(rawComparisonBlock(for: issue))
        """
    }

    public func issueSetDetails(prefix: String, issueSet: ActivityIssueSet) -> String {
        guard !issueSet.issues.isEmpty else {
            return prefix
        }

        let issueBlocks = issueSet.issues.map { issueDetailsBlock(for: $0) }.joined(separator: "\n\n")
        return "\(prefix)\n\n\(issueBlocks)"
    }

    public func snapshotSummary(_ snapshot: PairSnapshotEntry?) -> String {
        guard let snapshot else {
            return copy.language == .russian ? "<нет>" : "<missing>"
        }

        let modTime = snapshot.modTime?.ISO8601Format() ?? "<nil>"
        let hash = snapshot.md5 ?? "<nil>"
        return "size=\(snapshot.size), mtime=\(modTime), md5=\(hash)"
    }

    public func snapshotDetailLines(_ snapshot: PairSnapshotEntry?) -> [String] {
        guard let snapshot else {
            return [copy.language == .russian ? "<нет>" : "<missing>"]
        }

        return [
            "path=\(snapshot.path)",
            "size=\(snapshot.size)",
            "mtime=\(snapshot.modTime?.ISO8601Format() ?? "<nil>")",
            "md5=\(snapshot.md5 ?? "<nil>")",
        ]
    }

    private func problemCode(for kind: ActivityFileProblemKind) -> String {
        switch kind {
        case .remoteOnlyChanged:
            "remote-only changed"
        case .localOnlyChanged:
            "local-only changed"
        case .conflict:
            "conflict"
        case .deleteVsModifyConflict:
            "delete-vs-modify conflict"
        }
    }

    private func differenceCodes(for differences: [ActivityFileDifference]) -> String {
        differences.map(\.rawValue).joined(separator: ", ")
    }
}

public enum ActivityIssueTableLayout {
    public struct ColumnWidths: Equatable, Sendable {
        public let pathIdeal: CGFloat
        public let fileIdeal: CGFloat
        public let problemIdeal: CGFloat
        public let decisionIdeal: CGFloat

        public init(pathIdeal: CGFloat, fileIdeal: CGFloat, problemIdeal: CGFloat, decisionIdeal: CGFloat) {
            self.pathIdeal = pathIdeal
            self.fileIdeal = fileIdeal
            self.problemIdeal = problemIdeal
            self.decisionIdeal = decisionIdeal
        }
    }

    public static func columnWidths(for issues: [ActivityFileIssue], formatter: ActivityIssueFormatter) -> ColumnWidths {
        let bodyFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let captionFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let monoFont = NSFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        let copy = formatter.copy

        let pathIdeal = idealWidth(
            header: copy.issueReviewPathColumnTitle,
            values: issues.map(\.directoryPath),
            font: monoFont,
            min: 70,
            max: 180
        )

        let fileIdeal = idealWidth(
            header: copy.issueReviewFileColumnTitle,
            values: issues.map(\.fileName),
            font: bodyFont,
            min: 120,
            max: 300
        )

        let problemIdeal = clamp(
            max(
                measuredWidth(copy.issueReviewProblemColumnTitle, font: bodyFont),
                issues.map { issue in
                    max(
                        measuredWidth(formatter.problemTitle(for: issue.problemKind), font: bodyFont),
                        measuredWidth(formatter.differencesTitle(for: issue.differences), font: captionFont)
                    )
                }.max() ?? 0
            ) + 28,
            min: 160,
            max: 320
        )

        let decisionIdeal = clamp(
            max(
                measuredWidth(copy.issueReviewDecisionColumnTitle, font: bodyFont) + 44,
                [
                    copy.issueDecisionKeepLocalTitle,
                    copy.issueDecisionKeepRemoteTitle,
                    copy.issueDecisionKeepBothTitle,
                    copy.issueDecisionLaterTitle,
                ]
                .map { measuredWidth($0, font: bodyFont) + 58 }
                .max() ?? 0
            ),
            min: 150,
            max: 260
        )

        return ColumnWidths(
            pathIdeal: pathIdeal,
            fileIdeal: fileIdeal,
            problemIdeal: problemIdeal,
            decisionIdeal: decisionIdeal
        )
    }

    private static func idealWidth(
        header: String,
        values: [String],
        font: NSFont,
        min: CGFloat,
        max upperBound: CGFloat
    ) -> CGFloat {
        clamp(
            Swift.max(measuredWidth(header, font: font), values.map { measuredWidth($0, font: font) }.max() ?? 0) + 28,
            min: min,
            max: upperBound
        )
    }

    private static func measuredWidth(_ value: String, font: NSFont) -> CGFloat {
        ceil((value as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

public enum IssueReviewWindowLayout {
    public static func defaultFrame(for visibleFrame: CGRect, preferredMinimumSize: CGSize) -> CGRect {
        let minimumSize = clampedMinimumSize(for: visibleFrame, preferredMinimumSize: preferredMinimumSize)
        return CGRect(
            origin: visibleFrame.origin,
            size: CGSize(
                width: max(visibleFrame.width, minimumSize.width),
                height: max(visibleFrame.height, minimumSize.height)
            )
        ).integral
    }

    public static func clampedMinimumSize(for visibleFrame: CGRect, preferredMinimumSize: CGSize) -> CGSize {
        CGSize(
            width: min(preferredMinimumSize.width, visibleFrame.width),
            height: min(preferredMinimumSize.height, visibleFrame.height)
        )
    }
}
