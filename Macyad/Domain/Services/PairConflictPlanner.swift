import Foundation

public struct PairConflictPlanner: Sendable {
    public enum PathDisposition: String, Equatable, Sendable {
        case unchanged
        case localOnlyChanged
        case remoteOnlyChanged
        case bothChangedIdentical
        case conflict
        case deleteVsModifyConflict
    }

    public struct PathResult: Equatable, Sendable {
        public let path: String
        public let disposition: PathDisposition
        public let baselineLocal: PairSnapshotEntry?
        public let baselineRemote: PairSnapshotEntry?
        public let local: PairSnapshotEntry?
        public let remote: PairSnapshotEntry?
    }

    public struct Analysis: Equatable, Sendable {
        public let pathResults: [PathResult]

        public var localOnlyChanged: [PathResult] {
            pathResults.filter { $0.disposition == .localOnlyChanged }
        }

        public var remoteOnlyChanged: [PathResult] {
            pathResults.filter { $0.disposition == .remoteOnlyChanged }
        }

        public var bothChangedIdentical: [PathResult] {
            pathResults.filter { $0.disposition == .bothChangedIdentical }
        }

        public var conflicts: [PathResult] {
            pathResults.filter { $0.disposition == .conflict || $0.disposition == .deleteVsModifyConflict }
        }

        public var changeCountForPushBlock: Int {
            remoteOnlyChanged.count + conflicts.count
        }

        public var changeCountForPullBlock: Int {
            localOnlyChanged.count + conflicts.count
        }

        public var sampleRemoteDriftPath: String? {
            (remoteOnlyChanged + conflicts).first?.path
        }

        public var sampleLocalDriftPath: String? {
            (localOnlyChanged + conflicts).first?.path
        }

        public var isClean: Bool {
            pathResults.allSatisfy { $0.disposition == .unchanged || $0.disposition == .bothChangedIdentical }
        }
    }

    public enum BootstrapDisposition: Equatable, Sendable {
        case baselineCreated(PairConflictBaselineState)
        case baselineMissingWithDrift(Analysis)
    }

    public init() {}

    public func bootstrapDisposition(
        pairID: UUID,
        localSnapshot: PairSnapshot,
        remoteSnapshot: PairSnapshot,
        now: Date
    ) -> BootstrapDisposition {
        if localSnapshot.isEquivalent(to: remoteSnapshot) {
            return .baselineCreated(
                PairConflictBaselineState(
                    pairID: pairID,
                    localSnapshot: localSnapshot,
                    remoteSnapshot: remoteSnapshot,
                    updatedAt: now
                )
            )
        }

        let emptyBaseline = PairConflictBaselineState(
            pairID: pairID,
            localSnapshot: PairSnapshot(entries: []),
            remoteSnapshot: PairSnapshot(entries: []),
            updatedAt: now
        )
        return .baselineMissingWithDrift(analyze(baseline: emptyBaseline, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot))
    }

    public func analyze(
        baseline: PairConflictBaselineState,
        localSnapshot: PairSnapshot,
        remoteSnapshot: PairSnapshot
    ) -> Analysis {
        let baselineLocal = baseline.localSnapshot.byPath
        let baselineRemote = baseline.remoteSnapshot.byPath
        let local = localSnapshot.byPath
        let remote = remoteSnapshot.byPath
        let allPaths = Set(baselineLocal.keys).union(baselineRemote.keys).union(local.keys).union(remote.keys)

        let pathResults = allPaths.sorted().map { path -> PathResult in
            let baselineLocalEntry = baselineLocal[path]
            let baselineRemoteEntry = baselineRemote[path]
            let localEntry = local[path]
            let remoteEntry = remote[path]
            let localChanged = entry(localEntry, differsFrom: baselineLocalEntry)
            let remoteChanged = entry(remoteEntry, differsFrom: baselineRemoteEntry)

            let disposition: PathDisposition
            switch (localChanged, remoteChanged) {
            case (false, false):
                disposition = .unchanged
            case (true, false):
                disposition = .localOnlyChanged
            case (false, true):
                disposition = .remoteOnlyChanged
            case (true, true):
                if entriesEquivalent(localEntry, remoteEntry) {
                    disposition = .bothChangedIdentical
                } else if localEntry == nil || remoteEntry == nil {
                    disposition = .deleteVsModifyConflict
                } else {
                    disposition = .conflict
                }
            }

            return PathResult(
                path: path,
                disposition: disposition,
                baselineLocal: baselineLocalEntry,
                baselineRemote: baselineRemoteEntry,
                local: localEntry,
                remote: remoteEntry
            )
        }

        return Analysis(pathResults: pathResults)
    }

    private func entry(_ entry: PairSnapshotEntry?, differsFrom baselineEntry: PairSnapshotEntry?) -> Bool {
        switch (entry, baselineEntry) {
        case (nil, nil):
            return false
        case let (.some(entry), .some(baselineEntry)):
            return !entry.isEquivalent(to: baselineEntry)
        case (.some, nil), (nil, .some):
            return true
        }
    }

    private func entriesEquivalent(_ lhs: PairSnapshotEntry?, _ rhs: PairSnapshotEntry?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.isEquivalent(to: rhs)
        case (.some, nil), (nil, .some):
            return false
        }
    }
}
