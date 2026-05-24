struct AppPreferences: Codable, Equatable, Sendable {
    var launchAtLoginEnabled: Bool

    static let defaults = AppPreferences(launchAtLoginEnabled: false)
}
