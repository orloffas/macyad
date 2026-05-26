import Foundation

public enum ConflictPolicy: String, Codable, CaseIterable, Sendable {
    case block
    case keepBoth
}
