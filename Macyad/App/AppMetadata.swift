import Foundation

enum AppMetadata {
    static let bundleIdentifier = "me.orloff.macyad"
    static let displayName = "MacYaD"
    static let loggingSubsystem = "me.orloff.macyad"

    /// Marketing version, e.g. `0.1.0`. Set by `MARKETING_VERSION` in
    /// `project.yml`, and checked against the tag when a release is built.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// What the user is asked to quote in a bug report: `0.1.0 (4)`.
    static var versionDisplay: String {
        "\(version) (\(build))"
    }
}
