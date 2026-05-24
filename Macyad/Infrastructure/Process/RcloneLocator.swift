import Foundation

public protocol RcloneLocating: Sendable {
    func locate() async throws -> String?
}

public struct RcloneLocator: RcloneLocating {
    private let candidates: [String]
    private let fileExists: @Sendable (String) -> Bool

    public init(
        candidates: [String] = [
            "/opt/homebrew/bin/rclone",
            "/usr/local/bin/rclone",
            "/usr/bin/rclone"
        ],
        fileExists: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        }
    ) {
        self.candidates = candidates
        self.fileExists = fileExists
    }

    public func locate() async throws -> String? {
        candidates.first(where: fileExists)
    }
}
