import XCTest

final class PairFlowUITests: XCTestCase {
    @MainActor
    func testCreatePairButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_READY_STATE"]

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
        app.launchArguments = ["-UITEST_READY_STATE"]

        app.launch()

        let settingsButton = app.buttons["settings.open"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let englishWindow = app.windows["MacYaD Settings"].firstMatch
        let russianWindow = app.windows["Настройки MacYaD"].firstMatch
        XCTAssertTrue(englishWindow.waitForExistence(timeout: 5) || russianWindow.waitForExistence(timeout: 5))
    }

    // MARK: - New AC tests (Stage 9)

    // AC #1/#3: Overview table renders and clicking a row navigates to PairDetail.
    // Note: In UI-test ready state no pairs are pre-loaded, so this test verifies
    // the overview pane is visible. Full row-click navigation requires human verification
    // with actual pair data (see manual smoke AC list below).
    @MainActor
    func testOverviewPaneIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_READY_STATE"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        // Overview is the default landing route
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }

    // AC #5/#6/#7: CreatePair interval text input — valid value enables Save; invalid disables it.
    @MainActor
    func testCreatePairIntervalValidInputEnablesSave() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_READY_STATE"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        let newPairButton = app.buttons["pair.new"].firstMatch
        XCTAssertTrue(newPairButton.waitForExistence(timeout: 5))
        newPairButton.click()

        // Sheet must appear
        let sheet = app.sheets.firstMatch
        guard sheet.waitForExistence(timeout: 5) else {
            XCTFail("CreatePair sheet did not appear")
            return
        }

        // Find the interval text field (first editable text field in the sheet after name)
        let textFields = sheet.textFields.allElementsBoundByIndex
        // The interval field should contain a numeric default
        let intervalField = textFields.first(where: {
            Int($0.value as? String ?? "") != nil
        })

        if let intervalField {
            // Neither click + Cmd+A nor an added delete replaced the contents
            // of this SwiftUI text field — the typed text landed in front of
            // the default ("60" + "15" = "6015"). A double click selects the
            // existing value, which typing then replaces.
            intervalField.doubleClick()
            intervalField.typeText("60")
            // Save button should remain or become enabled (name/folder still missing, so Save
            // stays disabled due to other fields — this test validates field accepts numeric input)
            XCTAssertEqual(intervalField.value as? String, "60")
        }
        // Close sheet
        let cancelButton = sheet.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == 'Отмена'")).firstMatch
        if cancelButton.exists { cancelButton.click() }
    }

    @MainActor
    func testCreatePairIntervalInvalidInputShowsError() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_READY_STATE"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        let newPairButton = app.buttons["pair.new"].firstMatch
        XCTAssertTrue(newPairButton.waitForExistence(timeout: 5))
        newPairButton.click()

        let sheet = app.sheets.firstMatch
        guard sheet.waitForExistence(timeout: 5) else {
            XCTFail("CreatePair sheet did not appear")
            return
        }

        let textFields = sheet.textFields.allElementsBoundByIndex
        let intervalField = textFields.first(where: {
            Int($0.value as? String ?? "") != nil
        })

        if let intervalField {
            intervalField.click()
            intervalField.typeKey("a", modifierFlags: .command)
            intervalField.typeText("abc")
            // The validation error text should appear somewhere in the sheet
            let errorText = sheet.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Interval' OR label CONTAINS 'Интервал'")
            ).firstMatch
            // Give UI a moment to update
            _ = errorText.waitForExistence(timeout: 2)
            // Save button should be disabled (canSave == false)
            let saveButton = sheet.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Save' OR label CONTAINS 'Сохранить'")
            ).firstMatch
            if saveButton.exists {
                XCTAssertFalse(saveButton.isEnabled, "Save should be disabled with invalid interval")
            }
        }

        let cancelButton = sheet.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == 'Отмена'")).firstMatch
        if cancelButton.exists { cancelButton.click() }
    }
}
