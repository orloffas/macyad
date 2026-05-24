import Foundation

struct ActivityEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var date: Date
    var message: String
    var severity: Severity
    var pairID: UUID?
}
