import Foundation

public enum ActivityFileProblemKind: String, Codable, CaseIterable, Equatable, Sendable {
    case remoteOnlyChanged
    case localOnlyChanged
    case conflict
    case deleteVsModifyConflict
}

public enum ActivityFileDifference: String, Codable, CaseIterable, Equatable, Sendable {
    case sizeDiffers
    case mtimeDiffers
    case hashDiffers
    case missingLocal
    case missingRemote
    case deleteVsModify
    case baselineMissing
}

public enum FileResolutionDecision: String, Codable, CaseIterable, Equatable, Sendable {
    case keepLocal
    case keepRemote
    case keepBoth
    case later
}

public struct ActivityFileIssue: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String
    public let fileName: String
    public let problemKind: ActivityFileProblemKind
    public let differences: [ActivityFileDifference]
    public let localSnapshot: PairSnapshotEntry?
    public let remoteSnapshot: PairSnapshotEntry?
    public let baselineSnapshot: PairSnapshotEntry?
    public var selectedDecision: FileResolutionDecision

    public init(
        relativePath: String,
        problemKind: ActivityFileProblemKind,
        differences: [ActivityFileDifference],
        localSnapshot: PairSnapshotEntry?,
        remoteSnapshot: PairSnapshotEntry?,
        baselineSnapshot: PairSnapshotEntry?,
        selectedDecision: FileResolutionDecision
    ) {
        self.relativePath = relativePath
        self.fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        self.problemKind = problemKind
        self.differences = differences
        self.localSnapshot = localSnapshot
        self.remoteSnapshot = remoteSnapshot
        self.baselineSnapshot = baselineSnapshot
        self.selectedDecision = selectedDecision
    }
}

public struct ActivityIssueSet: Codable, Equatable, Sendable {
    public var issues: [ActivityFileIssue]

    public init(issues: [ActivityFileIssue]) {
        self.issues = issues.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    public var isEmpty: Bool {
        issues.isEmpty
    }
}

public struct ActivityRouteToken: Codable, Equatable, Sendable {
    public static let pairIDUserInfoKey = "pairID"
    public static let eventIDUserInfoKey = "eventID"
    public static let openIssueTableUserInfoKey = "openIssueTable"

    public let pairID: UUID
    public let eventID: UUID
    public let openIssueTable: Bool

    public init(pairID: UUID, eventID: UUID, openIssueTable: Bool) {
        self.pairID = pairID
        self.eventID = eventID
        self.openIssueTable = openIssueTable
    }

    public var notificationUserInfo: [AnyHashable: Any] {
        [
            Self.pairIDUserInfoKey: pairID.uuidString,
            Self.eventIDUserInfoKey: eventID.uuidString,
            Self.openIssueTableUserInfoKey: openIssueTable,
        ]
    }

    public init?(notificationUserInfo: [AnyHashable: Any]) {
        guard
            let pairIDRaw = notificationUserInfo[Self.pairIDUserInfoKey] as? String,
            let eventIDRaw = notificationUserInfo[Self.eventIDUserInfoKey] as? String,
            let pairID = UUID(uuidString: pairIDRaw),
            let eventID = UUID(uuidString: eventIDRaw)
        else {
            return nil
        }

        self.init(
            pairID: pairID,
            eventID: eventID,
            openIssueTable: notificationUserInfo[Self.openIssueTableUserInfoKey] as? Bool ?? false
        )
    }
}
