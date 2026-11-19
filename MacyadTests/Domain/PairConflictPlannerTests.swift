import XCTest
@testable import MacyadCore

final class PairConflictPlannerTests: XCTestCase {
    func testAnalyzeClassifiesRemoteOnlyAndConflictPaths() {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: snapshot(
                ("unchanged.txt", "aaa"),
                ("remote-only.txt", "bbb"),
                ("conflict.txt", "ccc")
            ),
            remoteSnapshot: snapshot(
                ("unchanged.txt", "aaa"),
                ("remote-only.txt", "bbb"),
                ("conflict.txt", "ccc")
            ),
            updatedAt: Date()
        )

        let local = snapshot(
            ("unchanged.txt", "aaa"),
            ("remote-only.txt", "bbb"),
            ("conflict.txt", "local")
        )
        let remote = snapshot(
            ("unchanged.txt", "aaa"),
            ("remote-only.txt", "remote"),
            ("conflict.txt", "remote")
        )

        let analysis = planner.analyze(baseline: baseline, localSnapshot: local, remoteSnapshot: remote)

        XCTAssertEqual(analysis.remoteOnlyChanged.map(\.path), ["remote-only.txt"])
        XCTAssertEqual(analysis.conflicts.map(\.path), ["conflict.txt"])
        XCTAssertEqual(analysis.changeCountForPushBlock, 2)
        XCTAssertEqual(analysis.sampleRemoteDriftPath, "remote-only.txt")
    }

    func testAnalyzeClassifiesDeleteVsModifyConflict() {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: snapshot(("Docs/file.txt", "aaa")),
            remoteSnapshot: snapshot(("Docs/file.txt", "aaa")),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: snapshot(),
            remoteSnapshot: snapshot(("Docs/file.txt", "remote"))
        )

        XCTAssertEqual(analysis.conflicts.count, 1)
        XCTAssertEqual(analysis.conflicts.first?.disposition, .deleteVsModifyConflict)
    }

    func testAnalyzeKeepsObservedDifferencesAlongsideDisposition() throws {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: PairSnapshot(entries: [
                PairSnapshotEntry(path: "Docs/file.txt", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "same")
            ]),
            remoteSnapshot: PairSnapshot(entries: [
                PairSnapshotEntry(path: "Docs/file.txt", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "same")
            ]),
            updatedAt: Date()
        )

        let local = PairSnapshot(entries: [
            PairSnapshotEntry(path: "Docs/file.txt", size: 12, modTime: Date(timeIntervalSince1970: 2_000), md5: "local")
        ])
        let remote = PairSnapshot(entries: [
            PairSnapshotEntry(path: "Docs/file.txt", size: 18, modTime: Date(timeIntervalSince1970: 3_000), md5: "remote")
        ])

        let analysis = planner.analyze(baseline: baseline, localSnapshot: local, remoteSnapshot: remote)
        let result = try XCTUnwrap(analysis.pathResults.first)

        XCTAssertEqual(result.disposition, .conflict)
        XCTAssertTrue(result.observedDifferences.contains(.mtimeDiffers))
        XCTAssertTrue(result.observedDifferences.contains(.sizeDiffers))
        XCTAssertTrue(result.observedDifferences.contains(.hashDiffers))
    }

    func testAnalyzeIgnoresMtimeOnlyChangeWhenHashesMatch() throws {
        // A re-upload stamps a new remote mtime; the bytes are the same, so nothing should block a push.
        let planner = PairConflictPlanner()
        let file = { (mtime: Double) in
            PairSnapshotEntry(path: "Docs/scan.pdf", size: 12, modTime: Date(timeIntervalSince1970: mtime), md5: "same")
        }
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: PairSnapshot(entries: [file(1_000)]),
            remoteSnapshot: PairSnapshot(entries: [file(1_000)]),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: PairSnapshot(entries: [file(1_000)]),
            remoteSnapshot: PairSnapshot(entries: [file(5_000)])
        )

        XCTAssertTrue(analysis.isClean)
        XCTAssertEqual(analysis.changeCountForPushBlock, 0)
    }

    func testAnalyzeTreatsMatchingHashesAsIdenticalEvenWithoutBaselineHash() throws {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: nil)]),
            remoteSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: nil)]),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "h")]),
            remoteSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 9_000), md5: "h")])
        )

        XCTAssertEqual(try XCTUnwrap(analysis.pathResults.first).disposition, .bothChangedIdentical)
    }

    func testRemoteWhoseHashVanishedStillCountsAsChanged() throws {
        // Baseline knew the hash; the new listing has none. Same size and mtime must not read as "unchanged",
        // or a local deletion would be pushed over a remote edit.
        let planner = PairConflictPlanner()
        let known = PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "b")
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: PairSnapshot(entries: [known]),
            remoteSnapshot: PairSnapshot(entries: [known]),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: PairSnapshot(entries: []),
            remoteSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: nil)])
        )

        XCTAssertEqual(try XCTUnwrap(analysis.pathResults.first).disposition, .deleteVsModifyConflict)
    }

    func testHashOnOneSideOnlyIsNotTreatedAsIdentical() throws {
        let planner = PairConflictPlanner()
        let base = PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "b")
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: PairSnapshot(entries: [base]),
            remoteSnapshot: PairSnapshot(entries: [base]),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "x")]),
            remoteSnapshot: PairSnapshot(entries: [PairSnapshotEntry(path: "a.pdf", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: nil)])
        )

        XCTAssertEqual(try XCTUnwrap(analysis.pathResults.first).disposition, .conflict)
    }

    func testBootstrapCreatesBaselineOnlyWhenSnapshotsMatch() {
        let planner = PairConflictPlanner()
        let now = Date(timeIntervalSince1970: 1_000)
        let cleanSnapshot = snapshot(("Docs/file.txt", "aaa"))

        switch planner.bootstrapDisposition(pairID: UUID(), localSnapshot: cleanSnapshot, remoteSnapshot: cleanSnapshot, now: now) {
        case let .baselineCreated(state):
            XCTAssertEqual(state.localSnapshot, cleanSnapshot)
            XCTAssertEqual(state.remoteSnapshot, cleanSnapshot)
            XCTAssertEqual(state.updatedAt, now)
        case .baselineMissingWithDrift:
            XCTFail("Expected clean bootstrap")
        }
    }

    func testAnalysisMarksPureRemoteAdditionsAsSafeInitialPull() {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: snapshot(),
            remoteSnapshot: snapshot(),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: snapshot(("Docs/shared.txt", "same")),
            remoteSnapshot: snapshot(("Docs/shared.txt", "same"), ("Docs/remote-only.txt", "remote"))
        )

        XCTAssertTrue(analysis.allowsSafeInitialPull)
        XCTAssertFalse(analysis.allowsSafeInitialPush)
    }

    func testAnalysisDoesNotMarkMixedOneSidedDriftAsSafeInitialAddition() {
        let planner = PairConflictPlanner()
        let baseline = PairConflictBaselineState(
            pairID: UUID(),
            localSnapshot: snapshot(),
            remoteSnapshot: snapshot(),
            updatedAt: Date()
        )

        let analysis = planner.analyze(
            baseline: baseline,
            localSnapshot: snapshot(("Docs/local-only.txt", "local")),
            remoteSnapshot: snapshot(("Docs/remote-only.txt", "remote"))
        )

        XCTAssertFalse(analysis.allowsSafeInitialPull)
        XCTAssertFalse(analysis.allowsSafeInitialPush)
    }

    private func snapshot(_ files: (String, String)...) -> PairSnapshot {
        PairSnapshot(entries: files.map { path, hash in
            PairSnapshotEntry(path: path, size: Int64(hash.count), modTime: Date(timeIntervalSince1970: 1_000), md5: hash)
        })
    }
}
