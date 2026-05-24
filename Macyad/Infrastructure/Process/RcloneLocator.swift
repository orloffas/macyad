import Foundation

protocol RcloneLocating: Sendable {
    func locate() async throws -> String?
}

struct RcloneLocator: RcloneLocating {
    private let candidates: [String]
    private let fileExists: @Sendable (String) -> Bool

    init(
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

    func locate() async throws -> String? {
        candidates.first(where: fileExists)
    }
}
