import XCTest

final class PairFlowUITests: XCTestCase {
    @MainActor
    func testCreatePairButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_READY_STATE"]

        app.launch()

        XCTAssertTrue(app.buttons["pair.new"].waitForExistence(timeout: 5))
    }
}
