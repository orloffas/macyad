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
        XCTAssertEqual(copy.pullShortButtonTitle, "Pull from Yandex")
        XCTAssertEqual(copy.pullButtonTitle, "Pull from Yandex")
        XCTAssertEqual(copy.manualSyncCompleted, "Push to Yandex completed")
        XCTAssertEqual(copy.manualCheckWarningDetected, "Yandex check detected remote changes")
        XCTAssertEqual(copy.scheduledSyncCompleted, "Scheduled Push to Yandex completed")
        XCTAssertEqual(copy.scheduledPushBlockedTitle, "Scheduled Push to Yandex blocked")
        XCTAssertTrue(copy.syncExcludesDescription.contains("Push to Yandex"))
        XCTAssertTrue(copy.checkAdditionalExcludesDescription.contains("includes Sync excludes first"))
        XCTAssertEqual(copy.actionsHelpTitle, "What each action does")
        XCTAssertEqual(copy.issueReviewMeaningSectionTitle, "What it means")
        XCTAssertEqual(copy.issueReviewRawSectionTitle, "Raw comparison")
        XCTAssertEqual(copy.issueReviewSnapshotsSectionTitle, "Snapshots")
        XCTAssertEqual(copy.issueReviewBaselineSectionTitle, "Baseline")
        XCTAssertEqual(copy.issueReviewDecisionSectionTitle, "Decision")
        XCTAssertEqual(copy.accountRemovalBlockedMessage(pairNames: ["Docs"]), "This account can't be removed while pair Docs still references it.")
        XCTAssertEqual(copy.activityCollapsedRunSummary(count: 3), "3 identical events")
    }

    func testRussianCopyUsesRussianLabels() {
        let copy = AppCopy(language: .russian)

        XCTAssertEqual(copy.onboardingTitle, "Подключение")
        XCTAssertEqual(copy.settingsTitle, "Настройки")
        XCTAssertEqual(copy.statusReady, "Готово")
        XCTAssertEqual(copy.syncButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.syncShortButtonTitle, "Push to Yandex")
        XCTAssertEqual(copy.pullShortButtonTitle, "Pull from Yandex")
        XCTAssertEqual(copy.pullButtonTitle, "Pull from Yandex")
        XCTAssertEqual(copy.manualSyncCompleted, "Push to Yandex завершён")
        XCTAssertEqual(copy.manualCheckWarningDetected, "Проверка Yandex обнаружила изменения")
        XCTAssertEqual(copy.scheduledSyncCompleted, "Плановый Push to Yandex завершён")
        XCTAssertEqual(copy.scheduledPushBlockedTitle, "Плановый Push to Yandex заблокирован")
        XCTAssertTrue(copy.syncExcludesDescription.contains("Push to Yandex"))
        XCTAssertTrue(copy.checkAdditionalExcludesDescription.contains("всегда использует Sync excludes"))
        XCTAssertEqual(copy.actionsHelpTitle, "Что делает каждая команда")
        XCTAssertEqual(copy.issueReviewMeaningSectionTitle, "Что это значит")
        XCTAssertEqual(copy.issueReviewRawSectionTitle, "Raw comparison")
        XCTAssertEqual(copy.issueReviewSnapshotsSectionTitle, "Снимки")
        XCTAssertEqual(copy.issueReviewBaselineSectionTitle, "Baseline")
        XCTAssertEqual(copy.issueReviewDecisionSectionTitle, "Решение")
        XCTAssertEqual(copy.accountRemovalBlockedMessage(pairNames: ["Docs", "Photos"]), "Account нельзя удалить, пока к нему привязаны pair: Docs, Photos.")
        XCTAssertEqual(copy.activityCollapsedRunSummary(count: 3), "3 одинаковых события")
    }
}
