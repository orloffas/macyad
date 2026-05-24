import XCTest

final class PairFlowUITests: XCTestCase {
    @MainActor
    func testCreatePairButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_READY_STATE"]

        app.launch()

        let identifierButton = app.buttons["pair.new"].firstMatch
        let localizedButton = app.buttons["Новая пара"].firstMatch
        XCTAssertTrue(identifierButton.waitForExistence(timeout: 5) || localizedButton.waitForExistence(timeout: 5))
    }
}
