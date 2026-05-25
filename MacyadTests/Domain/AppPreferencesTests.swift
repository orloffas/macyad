import XCTest
@testable import MacyadCore

final class AppPreferencesTests: XCTestCase {
    func testDefaultsMatchFirstLaunchProductPolicy() {
        XCTAssertEqual(AppPreferences.defaults.selectedLanguage, "en")
        XCTAssertTrue(AppPreferences.defaults.launchAtLoginEnabled)
        XCTAssertEqual(AppPreferences.defaults.defaultScheduleMinutes, 15)
    }
}
