import Foundation

public struct YandexAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var remoteName: String
    public var configPath: String
    public var isManaged: Bool
    public var remoteRootHint: String?
    public var createdAt: Date

    public init(
        id: UUID,
        displayName: String,
        remoteName: String,
        configPath: String,
        isManaged: Bool,
        remoteRootHint: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.remoteName = remoteName
        self.configPath = configPath
        self.isManaged = isManaged
        self.remoteRootHint = remoteRootHint
        self.createdAt = createdAt
    }

    public var remotePrefix: String {
        "\(remoteName):"
    }
}
