import XCTest
@testable import MacyadCore

final class AppCopyTests: XCTestCase {
    func testEnglishCopyUsesEnglishLabels() {
        let copy = AppCopy(language: .english)

        XCTAssertEqual(copy.onboardingTitle, "Onboarding")
        XCTAssertEqual(copy.settingsTitle, "Settings")
        XCTAssertEqual(copy.statusReady, "Ready")
        XCTAssertEqual(copy.syncButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.syncShortButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.manualSyncCompleted, "Push to Yandex completed")
        XCTAssertEqual(copy.scheduledSyncCompleted, "Scheduled Push to Yandex completed")
        XCTAssertEqual(copy.scheduledPushBlockedTitle, "Scheduled Push to Yandex blocked")
    }

    func testRussianCopyUsesRussianLabels() {
        let copy = AppCopy(language: .russian)

        XCTAssertEqual(copy.onboardingTitle, "Подключение")
        XCTAssertEqual(copy.settingsTitle, "Настройки")
        XCTAssertEqual(copy.statusReady, "Готово")
        XCTAssertEqual(copy.syncButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.syncShortButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.manualSyncCompleted, "Push to Yandex завершён")
        XCTAssertEqual(copy.scheduledSyncCompleted, "Плановый Push to Yandex завершён")
        XCTAssertEqual(copy.scheduledPushBlockedTitle, "Плановый Push to Yandex заблокирован")
    }
}
