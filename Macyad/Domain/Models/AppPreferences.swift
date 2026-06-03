public struct AppPreferences: Codable, Equatable, Sendable {
    public var selectedLanguage: String
    public var launchAtLoginEnabled: Bool
    public var defaultScheduleMinutes: Int
    public var isGlobalSchedulerPaused: Bool

    public var appLanguage: AppLanguage {
        AppLanguage(code: selectedLanguage)
    }

    public static let defaults = AppPreferences(
        selectedLanguage: "en",
        launchAtLoginEnabled: true,
        defaultScheduleMinutes: 15,
        isGlobalSchedulerPaused: false
    )

    public init(
        selectedLanguage: String,
        launchAtLoginEnabled: Bool,
        defaultScheduleMinutes: Int,
        isGlobalSchedulerPaused: Bool = false
    ) {
        self.selectedLanguage = selectedLanguage
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.defaultScheduleMinutes = defaultScheduleMinutes
        self.isGlobalSchedulerPaused = isGlobalSchedulerPaused
    }

    enum CodingKeys: String, CodingKey {
        case selectedLanguage
        case launchAtLoginEnabled
        case defaultScheduleMinutes
        case isGlobalSchedulerPaused
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedLanguage = try container.decode(String.self, forKey: .selectedLanguage)
        launchAtLoginEnabled = try container.decode(Bool.self, forKey: .launchAtLoginEnabled)
        defaultScheduleMinutes = try container.decode(Int.self, forKey: .defaultScheduleMinutes)
        isGlobalSchedulerPaused = try container.decodeIfPresent(Bool.self, forKey: .isGlobalSchedulerPaused) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedLanguage, forKey: .selectedLanguage)
        try container.encode(launchAtLoginEnabled, forKey: .launchAtLoginEnabled)
        try container.encode(defaultScheduleMinutes, forKey: .defaultScheduleMinutes)
        try container.encode(isGlobalSchedulerPaused, forKey: .isGlobalSchedulerPaused)
    }
}
