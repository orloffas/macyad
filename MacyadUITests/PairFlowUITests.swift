import XCTest

final class PairFlowUITests: XCTestCase {
    @MainActor
    func testCreatePairButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_READY_STATE"]

        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        let identifierButton = app.buttons["pair.new"].firstMatch
        let localizedButton = app.buttons["Новая пара"].firstMatch
        XCTAssertTrue(identifierButton.waitForExistence(timeout: 5) || localizedButton.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 1)
    }

    @MainActor
    func testToolbarSettingsButtonOpensSettingsWindow() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_READY_STATE"]

        app.launch()

        let settingsButton = app.buttons["settings.open"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let englishWindow = app.windows["MacYaD Settings"].firstMatch
        let russianWindow = app.windows["Настройки MacYaD"].firstMatch
        XCTAssertTrue(englishWindow.waitForExistence(timeout: 5) || russianWindow.waitForExistence(timeout: 5))
    }
}
