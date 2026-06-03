import XCTest
@testable import MacyadCore

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testIsGlobalSchedulerPausedDefaultsToFalse() {
        XCTAssertFalse(AppPreferences.defaults.isGlobalSchedulerPaused)
    }

    func testCurrentPreferencesReflectsIsGlobalSchedulerPaused() {
        let prefs = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )
        XCTAssertTrue(prefs.isGlobalSchedulerPaused)
        XCTAssertEqual(prefs.selectedLanguage, "en")
        XCTAssertEqual(prefs.defaultScheduleMinutes, 15)
    }

    func testRoundTripIsGlobalSchedulerPaused() throws {
        let original = AppPreferences(
            selectedLanguage: "ru",
            launchAtLoginEnabled: false,
            defaultScheduleMinutes: 30,
            isGlobalSchedulerPaused: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertTrue(decoded.isGlobalSchedulerPaused)
        XCTAssertFalse(decoded.launchAtLoginEnabled)
        XCTAssertEqual(decoded.defaultScheduleMinutes, 30)
    }
}
