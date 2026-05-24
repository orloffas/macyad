import Foundation

struct WorkspaceLayoutManager {
    let paths: AppPaths

    func ensureLayout() throws {
        try FileManager.default.createDirectory(
            at: paths.appSupportRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try FileManager.default.createDirectory(
            at: paths.workspaceRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
