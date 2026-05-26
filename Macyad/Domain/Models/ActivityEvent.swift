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

    public init(
        id: UUID,
        date: Date,
        message: String,
        severity: Severity,
        pairID: UUID?,
        details: String? = nil,
        issueSet: ActivityIssueSet? = nil,
        routeToken: ActivityRouteToken? = nil
    ) {
        self.id = id
        self.date = date
        self.message = message
        self.severity = severity
        self.pairID = pairID
        self.details = details
        self.issueSet = issueSet
        self.routeToken = routeToken
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
    }
}
