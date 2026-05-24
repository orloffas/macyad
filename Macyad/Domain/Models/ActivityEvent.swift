import Foundation

public struct ActivityEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var date: Date
    public var message: String
    public var severity: Severity
    public var pairID: UUID?

    public init(id: UUID, date: Date, message: String, severity: Severity, pairID: UUID?) {
        self.id = id
        self.date = date
        self.message = message
        self.severity = severity
        self.pairID = pairID
    }
}
