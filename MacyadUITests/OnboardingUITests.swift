import XCTest

final class OnboardingUITests: XCTestCase {
    @MainActor
    func testMissingRcloneShowsRetryAndCopyControls() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_ONBOARDING_MISSING_RCLONE"]

        app.launch()

        XCTAssertTrue(app.buttons["onboarding.retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.copyCommand"].exists)
    }
}
