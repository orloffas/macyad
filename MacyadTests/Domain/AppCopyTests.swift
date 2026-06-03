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

    func testNewKeysEnglish() {
        let copy = AppCopy(language: .english)

        XCTAssertEqual(copy.pauseAllSchedulesToggleTitle, "Pause all scheduled pushes")
        XCTAssertEqual(copy.scheduledPushSectionTitle, "Scheduled push")
        XCTAssertEqual(copy.pausedByGlobalSettingTooltip, "Paused by global setting")
        XCTAssertEqual(copy.pausedForThisPairTooltip, "Paused for this pair")
        XCTAssertEqual(copy.openLiveMonitorButtonTitle, "Open Live monitor")
        XCTAssertEqual(copy.liveMonitorWindowTitle("MyPair"), "Live monitor — MyPair")
        XCTAssertEqual(copy.intervalValidationError, "Interval must be 1–1440 minutes")
        XCTAssertEqual(copy.liveMonitorRunningFooter, "Running…")
        XCTAssertEqual(copy.liveMonitorExitedSuccessFooter, "Exited successfully")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 1), "Failed (code 1)")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 127), "Failed (code 127)")
    }

    func testNewKeysRussian() {
        let copy = AppCopy(language: .russian)

        XCTAssertEqual(copy.pauseAllSchedulesToggleTitle, "Приостановить все scheduled push")
        XCTAssertEqual(copy.scheduledPushSectionTitle, "Scheduled push")
        XCTAssertEqual(copy.pausedByGlobalSettingTooltip, "Приостановлено глобальной настройкой")
        XCTAssertEqual(copy.pausedForThisPairTooltip, "Приостановлено для этой pair")
        XCTAssertEqual(copy.openLiveMonitorButtonTitle, "Открыть Live monitor")
        XCTAssertEqual(copy.liveMonitorWindowTitle("МояПара"), "Live monitor — МояПара")
        XCTAssertEqual(copy.intervalValidationError, "Интервал должен быть от 1 до 1440 минут")
        XCTAssertEqual(copy.liveMonitorRunningFooter, "Выполняется…")
        XCTAssertEqual(copy.liveMonitorExitedSuccessFooter, "Завершено успешно")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 1), "Ошибка (код 1)")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 127), "Ошибка (код 127)")
    }
}
