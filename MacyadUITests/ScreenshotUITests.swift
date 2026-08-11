import XCTest

/// Produces the screenshots used by `README.md` and `README.ru.md`.
///
/// These run against `-UITEST_SEEDED_PAIRS`, which writes an invented
/// configuration into a throwaway directory — no real account, no real folder,
/// nothing from the machine that happens to be running the tests. That is the
/// point: the README must never be illustrated with someone's actual disk.
///
/// It runs with the rest of the suite, and pays for its minute and a half:
/// every screenshot here is also an assertion that the pane rendered at all,
/// which is the failure the older tests kept missing. There is no environment
/// switch to skip it — on macOS neither a plain variable nor the documented
/// `TEST_RUNNER_` prefix reaches the test process from `xcodebuild`.
///
/// To collect the images:
///
///     xcodebuild test -only-testing:MacyadUITests/ScreenshotUITests \
///       -resultBundlePath shots.xcresult
///     xcrun xcresulttool export attachments --path shots.xcresult \
///       --output-path shots      # names are in shots/manifest.json
final class ScreenshotUITests: XCTestCase {
    private struct Localized {
        let english: String
        let russian: String

        func callAsFunction(_ isRussian: Bool) -> String {
            isRussian ? russian : english
        }
    }

    /// SwiftUI puts a `Text`'s contents in `label` in some places and in
    /// `value` in others — sidebar rows and journal rows disagree — and the
    /// `app.staticTexts["…"]` subscript only matches identifier or label. This
    /// matches whichever one carries the string.
    private func staticText(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
            .firstMatch
    }

    private static let overview = Localized(english: "Overview", russian: "Обзор")
    private static let onboarding = Localized(english: "Onboarding", russian: "Подключение")
    private static let blockedRun = Localized(
        english: "Scheduled Push to Yandex blocked",
        russian: "Плановый Push to Yandex заблокирован"
    )
    private static let reviewFiles = Localized(english: "Review files", russian: "Проверить файлы")
    private static let close = Localized(english: "Close", russian: "Закрыть")
    private static let cancel = Localized(english: "Cancel", russian: "Отмена")

    func testCaptureEnglishScreenshots() {
        captureScreenshots(isRussian: false)
    }

    func testCaptureRussianScreenshots() {
        captureScreenshots(isRussian: true)
    }

    private func captureScreenshots(isRussian: Bool) {
        let suffix = isRussian ? "ru" : "en"
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_SEEDED_PAIRS"] + (isRussian ? ["-UITEST_LANG_RU"] : [])
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        // 1. A pair, selected — the app doing its actual job.
        let documentsRow = staticText(app, "Documents")
        XCTAssertTrue(documentsRow.waitForExistence(timeout: 10))
        documentsRow.click()
        save(app, "01-pair-detail", suffix)

        // 2. The blocked run and its reviewable file list — the reason the app
        // exists rather than a cron job calling rclone. Taken before Overview:
        // that pane lists the pairs by name too, and `firstMatch` would then
        // land on a table cell instead of the sidebar row.
        let projectsRow = staticText(app, "Projects")
        XCTAssertTrue(projectsRow.waitForExistence(timeout: 10))
        projectsRow.click()

        // A journal row is a Button whose label is the whole row read out —
        // message, reason, timestamp, issue count — so it matches on the
        // prefix, not on equality, and its inner Text elements are not exposed
        // separately at all.
        let blockedEvent = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", Self.blockedRun(isRussian)))
            .firstMatch
        XCTAssertTrue(blockedEvent.waitForExistence(timeout: 10), "the seeded blocked run is not in the journal")
        blockedEvent.click()

        let reviewButton = app.buttons[Self.reviewFiles(isRussian)].firstMatch
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10), "the blocked run opened without its file list")
        save(app, "03-activity-detail", suffix)
        reviewButton.click()
        // The table fills in a moment after the sheet opens; without a row the
        // screenshot would be of an empty sheet. Match the folder cell, not a
        // whole path: the table splits each issue into a path column and a file
        // column, and which file lands first is the table's business.
        let issueRow = app.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "Quarter 1", "Quarter 1"))
            .firstMatch
        XCTAssertTrue(issueRow.waitForExistence(timeout: 15), "the review sheet opened without its file list")
        save(app, "04-conflict-review", suffix)
        dismissSheets(app, isRussian: isRussian)

        // 3. The overview table, with every pair and its state.
        let overviewRow = staticText(app, Self.overview(isRussian))
        XCTAssertTrue(overviewRow.waitForExistence(timeout: 10))
        overviewRow.click()
        save(app, "02-overview", suffix)

        // 4. Creating a pair: the model the whole app is built around.
        let newPairButton = app.buttons["pair.new"].firstMatch
        XCTAssertTrue(newPairButton.waitForExistence(timeout: 10))
        newPairButton.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10), "the new pair sheet did not open")
        save(app, "05-create-pair", suffix)
        dismissSheets(app, isRussian: isRussian)

        // 5. Onboarding, which doubles as the environment check.
        let onboardingRow = staticText(app, Self.onboarding(isRussian))
        XCTAssertTrue(onboardingRow.waitForExistence(timeout: 10))
        onboardingRow.click()
        // The first visit runs the environment check. Wait for its result — the
        // stubbed rclone path — rather than for a fixed interval: until it
        // lands the checklist is a spinner.
        let rclonePath = app.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "/rclone", "/rclone"))
            .firstMatch
        XCTAssertTrue(rclonePath.waitForExistence(timeout: 15), "the environment check did not finish")
        save(app, "06-onboarding", suffix)

        // Settings is deliberately not captured: its account section shows the
        // rclone config path, which under a seeded run is a `/var/folders/…`
        // throwaway directory, and on a real installation would be somebody's
        // home directory. Neither belongs in a README.
    }

    private func dismissSheets(_ app: XCUIApplication, isRussian: Bool) {
        // Close whatever is open, innermost first. Each sheet has its own
        // button, and clicking the wrong one leaves the next screenshot
        // covered.
        for _ in 0 ..< 3 {
            let closeButton = app.buttons[Self.close(isRussian)].firstMatch
            let cancelButton = app.buttons[Self.cancel(isRussian)].firstMatch

            if cancelButton.exists, cancelButton.isHittable {
                cancelButton.click()
            } else if closeButton.exists, closeButton.isHittable {
                closeButton.click()
            } else {
                return
            }
        }
    }

    private func save(_ app: XCUIApplication, _ name: String, _ suffix: String) {
        // The app window only — never the screen, which is not ours to capture.
        write(app.windows.firstMatch.screenshot().pngRepresentation, name, suffix)
    }

    private func write(_ data: Data, _ name: String, _ suffix: String) {
        // Attachments, not files: the runner's own temporary directory is not
        // reachable afterwards. These land in the .xcresult bundle, and
        // `xcrun xcresulttool export attachments` pulls them back out.
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "macyad-\(name)-\(suffix).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
