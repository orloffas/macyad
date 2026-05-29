import XCTest
@testable import MacyadCore

final class ActivityIssueFormatterTests: XCTestCase {
    func testRemoteOnlyIssueExplanationIncludesHumanMeaningAndRawAppendix() {
        let formatter = ActivityIssueFormatter(copy: AppCopy(language: .english))
        let issue = ActivityFileIssue(
            relativePath: "Docs/report.txt",
            problemKind: .remoteOnlyChanged,
            differences: [.baselineMissing, .missingLocal],
            localSnapshot: nil,
            remoteSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 18, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote"),
            baselineSnapshot: nil,
            selectedDecision: .later
        )

        let details = formatter.issueDetailsBlock(for: issue)

        XCTAssertTrue(details.contains("What it means: The file currently exists only on the remote side."))
        XCTAssertTrue(details.contains("Path: /Docs"))
        XCTAssertTrue(details.contains("File: report.txt"))
        XCTAssertTrue(details.contains("Problem: remote-only changed"))
        XCTAssertTrue(details.contains("Differences: baselineMissing, missingLocal"))
    }

    func testLocalOnlyIssueExplanationIncludesHumanMeaningAndRawAppendix() {
        let formatter = ActivityIssueFormatter(copy: AppCopy(language: .english))
        let issue = ActivityFileIssue(
            relativePath: "Docs/report.txt",
            problemKind: .localOnlyChanged,
            differences: [.baselineMissing, .missingRemote],
            localSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 18, modTime: Date(timeIntervalSince1970: 2_000), md5: "local"),
            remoteSnapshot: nil,
            baselineSnapshot: nil,
            selectedDecision: .later
        )

        let details = formatter.issueDetailsBlock(for: issue)

        XCTAssertTrue(details.contains("What it means: The file currently exists only on the local side."))
        XCTAssertTrue(details.contains("Path: /Docs"))
        XCTAssertTrue(details.contains("File: report.txt"))
        XCTAssertTrue(details.contains("Problem: local-only changed"))
        XCTAssertTrue(details.contains("Differences: baselineMissing, missingRemote"))
    }

    func testConflictIssueExplanationIncludesHumanMeaningAndRawAppendix() {
        let formatter = ActivityIssueFormatter(copy: AppCopy(language: .english))
        let issue = ActivityFileIssue(
            relativePath: "Docs/report.txt",
            problemKind: .conflict,
            differences: [.hashDiffers, .mtimeDiffers, .sizeDiffers],
            localSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 12, modTime: Date(timeIntervalSince1970: 2_000), md5: "local"),
            remoteSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 18, modTime: Date(timeIntervalSince1970: 3_000), md5: "remote"),
            baselineSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 10, modTime: Date(timeIntervalSince1970: 1_000), md5: "base"),
            selectedDecision: .later
        )

        let details = formatter.issueDetailsBlock(for: issue)

        XCTAssertTrue(details.contains("What it means: The file changed on both local and remote, and the current versions do not match each other."))
        XCTAssertTrue(details.contains("Path: /Docs"))
        XCTAssertTrue(details.contains("File: report.txt"))
        XCTAssertTrue(details.contains("Problem: conflict"))
        XCTAssertTrue(details.contains("Differences: hashDiffers, mtimeDiffers, sizeDiffers"))
    }

    func testDeleteVsModifyExplanationIncludesHumanMeaningAndRawAppendix() {
        let formatter = ActivityIssueFormatter(copy: AppCopy(language: .english))
        let issue = ActivityFileIssue(
            relativePath: "Docs/report.txt",
            problemKind: .deleteVsModifyConflict,
            differences: [.deleteVsModify, .missingLocal],
            localSnapshot: nil,
            remoteSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 18, modTime: Date(timeIntervalSince1970: 3_000), md5: "remote"),
            baselineSnapshot: PairSnapshotEntry(path: "Docs/report.txt", size: 10, modTime: Date(timeIntervalSince1970: 1_000), md5: "base"),
            selectedDecision: .later
        )

        let details = formatter.issueDetailsBlock(for: issue)

        XCTAssertTrue(details.contains("What it means: One side deleted the file while the other side still has a changed or surviving version."))
        XCTAssertTrue(details.contains("Path: /Docs"))
        XCTAssertTrue(details.contains("File: report.txt"))
        XCTAssertTrue(details.contains("Problem: delete-vs-modify conflict"))
        XCTAssertTrue(details.contains("Differences: deleteVsModify, missingLocal"))
    }

    func testTopLevelFilesUseRootDirectoryPath() {
        let issue = ActivityFileIssue(
            relativePath: "1Password.zip",
            problemKind: .remoteOnlyChanged,
            differences: [.baselineMissing, .missingLocal],
            localSnapshot: nil,
            remoteSnapshot: nil,
            baselineSnapshot: nil,
            selectedDecision: .later
        )

        XCTAssertEqual(issue.directoryPath, "/")
        XCTAssertEqual(issue.fileName, "1Password.zip")
    }

    func testNestedFilesKeepDirectoryPathSeparateFromFileName() {
        let issue = ActivityFileIssue(
            relativePath: "Docs/Archive/2026/report.txt",
            problemKind: .remoteOnlyChanged,
            differences: [.baselineMissing, .missingLocal],
            localSnapshot: nil,
            remoteSnapshot: nil,
            baselineSnapshot: nil,
            selectedDecision: .later
        )

        XCTAssertEqual(issue.directoryPath, "/Docs/Archive/2026")
        XCTAssertEqual(issue.fileName, "report.txt")
    }

    func testTableColumnWidthsFollowVisibleContentAndClampRanges() {
        let formatter = ActivityIssueFormatter(copy: AppCopy(language: .english))
        let shortIssue = ActivityFileIssue(
            relativePath: "a.txt",
            problemKind: .remoteOnlyChanged,
            differences: [.missingLocal],
            localSnapshot: nil,
            remoteSnapshot: nil,
            baselineSnapshot: nil,
            selectedDecision: .later
        )
        let longIssue = ActivityFileIssue(
            relativePath: "Very/Deep/Folder/Structure/with-long-name/report-with-a-very-long-file-name.txt",
            problemKind: .deleteVsModifyConflict,
            differences: [.baselineMissing, .deleteVsModify, .missingLocal, .mtimeDiffers, .sizeDiffers, .hashDiffers],
            localSnapshot: nil,
            remoteSnapshot: nil,
            baselineSnapshot: nil,
            selectedDecision: .later
        )

        let shortWidths = ActivityIssueTableLayout.columnWidths(for: [shortIssue], formatter: formatter)
        let mixedWidths = ActivityIssueTableLayout.columnWidths(for: [shortIssue, longIssue], formatter: formatter)

        XCTAssertGreaterThan(mixedWidths.pathIdeal, shortWidths.pathIdeal)
        XCTAssertGreaterThan(mixedWidths.fileIdeal, shortWidths.fileIdeal)
        XCTAssertGreaterThan(mixedWidths.problemIdeal, shortWidths.problemIdeal)
        XCTAssertGreaterThanOrEqual(mixedWidths.pathIdeal, 70)
        XCTAssertLessThanOrEqual(mixedWidths.pathIdeal, 180)
        XCTAssertGreaterThanOrEqual(mixedWidths.fileIdeal, 120)
        XCTAssertLessThanOrEqual(mixedWidths.fileIdeal, 300)
        XCTAssertGreaterThanOrEqual(mixedWidths.problemIdeal, 160)
        XCTAssertLessThanOrEqual(mixedWidths.problemIdeal, 320)
        XCTAssertEqual(shortWidths.decisionIdeal, mixedWidths.decisionIdeal)
        XCTAssertGreaterThanOrEqual(mixedWidths.decisionIdeal, 150)
    }

    func testReviewWindowLayoutUsesVisibleFrameAndClampsMinimumSizeToScreen() {
        let visibleFrame = CGRect(x: 120, y: 80, width: 1512, height: 947)
        let preferredMinimum = CGSize(width: 980, height: 660)

        XCTAssertEqual(
            IssueReviewWindowLayout.defaultFrame(
                for: visibleFrame,
                preferredMinimumSize: preferredMinimum
            ),
            visibleFrame
        )
        XCTAssertEqual(
            IssueReviewWindowLayout.clampedMinimumSize(
                for: CGRect(x: 0, y: 0, width: 860, height: 620),
                preferredMinimumSize: preferredMinimum
            ),
            CGSize(width: 860, height: 620)
        )
    }
}
