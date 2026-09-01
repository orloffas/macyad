import Foundation

public struct ActivityEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var date: Date
    public var message: String
    public var severity: Severity
    public var pairID: UUID?
    public var details: String?
    public var issueSet: ActivityIssueSet?
    public var routeToken: ActivityRouteToken?
    /// Human-readable name of an operation that has started but not finished.
    /// The event is written before the work begins, so the journal shows the
    /// run even if the app never gets to write its result; on the next launch
    /// a still-in-flight event is turned into an "interrupted" record.
    public var inFlightOperation: String?
    /// Whether that operation had actually begun, or was still waiting its turn
    /// in the serial queue. The two need different interrupted records: a run
    /// that never started moved no files, and telling the user otherwise sends
    /// them checking for damage that cannot exist.
    public var inFlightPhase: InFlightPhase?

    public enum InFlightPhase: String, Codable, Equatable, Sendable {
        case queued
        case running
    }

    public init(
        id: UUID,
        date: Date,
        message: String,
        severity: Severity,
        pairID: UUID?,
        details: String? = nil,
        issueSet: ActivityIssueSet? = nil,
        routeToken: ActivityRouteToken? = nil,
        inFlightOperation: String? = nil,
        inFlightPhase: InFlightPhase? = nil
    ) {
        self.id = id
        self.date = date
        self.message = message
        self.severity = severity
        self.pairID = pairID
        self.details = details
        self.issueSet = issueSet
        self.routeToken = routeToken
        self.inFlightOperation = inFlightOperation
        self.inFlightPhase = inFlightPhase
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case message
        case severity
        case pairID
        case details
        case issueSet
        case routeToken
        case inFlightOperation
        case inFlightPhase
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        message = try container.decode(String.self, forKey: .message)
        severity = try container.decode(Severity.self, forKey: .severity)
        pairID = try container.decodeIfPresent(UUID.self, forKey: .pairID)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        issueSet = try container.decodeIfPresent(ActivityIssueSet.self, forKey: .issueSet)
        routeToken = try container.decodeIfPresent(ActivityRouteToken.self, forKey: .routeToken)
        inFlightOperation = try container.decodeIfPresent(String.self, forKey: .inFlightOperation)
        // Journals written before the phase existed carry no value. Decoding
        // keeps that absence honest; `interrupted(using:at:)` is where a missing
        // phase is read as "may have been running", which is the safe reading.
        inFlightPhase = try container.decodeIfPresent(InFlightPhase.self, forKey: .inFlightPhase)
    }

    /// First sentence of the details, for the journal row. The full text runs
    /// to hundreds of lines for a blocked run, but its opening line already
    /// says why — and without it the row shows only "blocked" and the user has
    /// no reason to suspect there is anything to open.
    public var reasonLine: String? {
        guard let details else {
            return nil
        }

        let firstLine = details
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces)

        guard let firstLine, !firstLine.isEmpty, firstLine != message else {
            // Some failures put the same sentence in both fields; repeating it
            // under itself just makes the row taller.
            return nil
        }

        return firstLine
    }

    /// How many paths the run could not reconcile, when it collected them.
    public var issueCount: Int? {
        guard let issueSet, !issueSet.issues.isEmpty else {
            return nil
        }

        return issueSet.issues.count
    }

    /// The record an in-flight event becomes once we know nobody is going to
    /// finish it. Returns `nil` for events that are not in flight.
    public func interrupted(using copy: AppCopy, at date: Date = Date()) -> ActivityEvent? {
        guard let inFlightOperation else {
            return nil
        }

        if inFlightPhase == .queued {
            return ActivityEvent(
                id: id,
                date: date,
                message: copy.operationAbandonedInQueueMessage(inFlightOperation),
                severity: .info,
                pairID: pairID,
                details: copy.operationAbandonedInQueueDetails
            )
        }

        return ActivityEvent(
            id: id,
            date: date,
            message: copy.operationInterruptedMessage(inFlightOperation),
            severity: .warning,
            pairID: pairID,
            details: copy.operationInterruptedDetails
        )
    }
}

extension Array where Element == ActivityEvent {
    /// Rewrites events a previous launch left in flight. Any operation still
    /// marked as running when the app starts was cut short by a quit or a
    /// crash: its outcome is unknown, and leaving it as "running…" forever
    /// would be a lie.
    ///
    /// `startedBefore` is the current launch, and entries newer than it are
    /// left alone: the scheduler runs whether or not the main window is on
    /// screen, so a launch with no window (a login item) can be several
    /// minutes into a scheduled push by the time this pass runs.
    public func markingInterruptedRuns(
        using copy: AppCopy,
        startedBefore launchDate: Date,
        at date: Date = Date()
    ) -> [ActivityEvent] {
        map { event in
            guard event.date < launchDate else {
                return event
            }

            return event.interrupted(using: copy, at: date) ?? event
        }
    }
}
