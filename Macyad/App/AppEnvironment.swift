import Foundation
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let paths: AppPaths

    init(paths: AppPaths) {
        self.paths = paths
    }

    static func bootstrap() throws -> AppEnvironment {
        try .init(paths: .live())
    }
}
