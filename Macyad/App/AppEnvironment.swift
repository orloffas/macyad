import Foundation
import MacyadCore
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let statusService: StatusService

    init(paths: AppPaths, statusService: StatusService = StatusService()) {
        self.paths = paths
        self.statusService = statusService
    }

    static func bootstrap() throws -> AppEnvironment {
        try .init(paths: .live())
    }
}
