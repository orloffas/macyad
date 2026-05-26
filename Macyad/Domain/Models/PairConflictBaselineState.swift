import Foundation

public struct PairConflictBaselineState: Codable, Equatable, Sendable {
    public let pairID: UUID
    public var localSnapshot: PairSnapshot
    public var remoteSnapshot: PairSnapshot
    public var updatedAt: Date

    public init(
        pairID: UUID,
        localSnapshot: PairSnapshot,
        remoteSnapshot: PairSnapshot,
        updatedAt: Date
    ) {
        self.pairID = pairID
        self.localSnapshot = localSnapshot
        self.remoteSnapshot = remoteSnapshot
        self.updatedAt = updatedAt
    }
}

public struct PairSnapshot: Codable, Equatable, Sendable {
    public var entries: [PairSnapshotEntry]

    public init(entries: [PairSnapshotEntry]) {
        self.entries = entries.sorted { $0.path < $1.path }
    }

    public var byPath: [String: PairSnapshotEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
    }

    public func isEquivalent(to other: PairSnapshot) -> Bool {
        let lhs = byPath
        let rhs = other.byPath
        guard lhs.count == rhs.count else {
            return false
        }

        for (path, entry) in lhs {
            guard entry.isEquivalent(to: rhs[path]) else {
                return false
            }
        }

        return true
    }
}

public struct PairSnapshotEntry: Codable, Equatable, Hashable, Sendable {
    public var path: String
    public var size: Int64
    public var modTime: Date?
    public var md5: String?

    public init(path: String, size: Int64, modTime: Date?, md5: String?) {
        self.path = path
        self.size = size
        self.modTime = modTime
        self.md5 = md5
    }

    public func isEquivalent(to other: PairSnapshotEntry?) -> Bool {
        guard let other else {
            return false
        }

        if let md5, let otherMD5 = other.md5 {
            return size == other.size && md5 == otherMD5
        }

        return size == other.size && modTime == other.modTime
    }
}
