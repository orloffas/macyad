public struct AppPreferences: Codable, Equatable, Sendable {
    public var selectedLanguage: String
    public var launchAtLoginEnabled: Bool
    public var defaultScheduleMinutes: Int

    public static let defaults = AppPreferences(
        selectedLanguage: "ru",
        launchAtLoginEnabled: false,
        defaultScheduleMinutes: 30
    )

    public init(
        selectedLanguage: String,
        launchAtLoginEnabled: Bool,
        defaultScheduleMinutes: Int
    ) {
        self.selectedLanguage = selectedLanguage
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.defaultScheduleMinutes = defaultScheduleMinutes
    }
}
