import XCTest
@testable import MacyadCore

final class AppPreferencesTests: XCTestCase {
    func testDefaultsMatchFirstLaunchProductPolicy() {
        XCTAssertEqual(AppPreferences.defaults.selectedLanguage, "en")
        XCTAssertTrue(AppPreferences.defaults.launchAtLoginEnabled)
        XCTAssertEqual(AppPreferences.defaults.defaultScheduleMinutes, 15)
        XCTAssertFalse(AppPreferences.defaults.isGlobalSchedulerPaused)
    }

    func testLegacyDecodeDefaultsIsGlobalSchedulerPausedToFalse() throws {
        let json = """
        {
          "selectedLanguage": "ru",
          "launchAtLoginEnabled": false,
          "defaultScheduleMinutes": 30
        }
        """
        let prefs = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(prefs.selectedLanguage, "ru")
        XCTAssertFalse(prefs.launchAtLoginEnabled)
        XCTAssertEqual(prefs.defaultScheduleMinutes, 30)
        XCTAssertFalse(prefs.isGlobalSchedulerPaused)
    }

    func testRoundTripAllFields() throws {
        let original = AppPreferences(
            selectedLanguage: "ru",
            launchAtLoginEnabled: false,
            defaultScheduleMinutes: 60,
            isGlobalSchedulerPaused: true
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: encoded)
        XCTAssertEqual(decoded.selectedLanguage, "ru")
        XCTAssertFalse(decoded.launchAtLoginEnabled)
        XCTAssertEqual(decoded.defaultScheduleMinutes, 60)
        XCTAssertTrue(decoded.isGlobalSchedulerPaused)
    }
}
