public struct AppPreferences: Codable, Equatable, Sendable {
    public var selectedLanguage: String
    public var launchAtLoginEnabled: Bool
    public var defaultScheduleMinutes: Int

    public var appLanguage: AppLanguage {
        AppLanguage(code: selectedLanguage)
    }

    public static let defaults = AppPreferences(
        selectedLanguage: "en",
        launchAtLoginEnabled: true,
        defaultScheduleMinutes: 15
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
