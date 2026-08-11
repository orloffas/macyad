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
        XCTAssertEqual(copy.scheduledSyncCompleted(.push), "Scheduled Push to Yandex completed")
        XCTAssertEqual(copy.scheduledSyncCompleted(.pull), "Scheduled Pull From Yandex completed")
        XCTAssertEqual(copy.scheduledSyncBlockedTitle(.push), "Scheduled Push to Yandex blocked")
        XCTAssertEqual(copy.scheduledSyncBlockedTitle(.pull), "Scheduled Pull From Yandex blocked")
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
        XCTAssertEqual(copy.scheduledSyncCompleted(.push), "Плановый Push to Yandex завершён")
        XCTAssertEqual(copy.scheduledSyncCompleted(.pull), "Плановый Pull From Yandex завершён")
        XCTAssertEqual(copy.scheduledSyncBlockedTitle(.push), "Плановый Push to Yandex заблокирован")
        XCTAssertEqual(copy.scheduledSyncBlockedTitle(.pull), "Плановый Pull From Yandex заблокирован")
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

        XCTAssertEqual(copy.pauseAllSchedulesToggleTitle, "Pause all scheduled syncs")
        XCTAssertEqual(copy.scheduledSyncSectionTitle, "Scheduled sync")
        XCTAssertEqual(copy.pausedByGlobalSettingTooltip, "Paused by global setting")
        XCTAssertEqual(copy.pausedForThisPairTooltip, "Paused for this pair")
        XCTAssertEqual(copy.pausedByGlobalSettingShort, "Paused (global)")
        XCTAssertEqual(copy.pausedForThisPairShort, "Paused (this pair)")
        XCTAssertEqual(copy.openLiveMonitorButtonTitle, "Open Live monitor")
        XCTAssertEqual(copy.showLastLogButtonTitle, "Show last log")
        XCTAssertEqual(copy.showLastLogTooltipSessionOnly,
                       "The log is kept only for this session and becomes available after the first completed sync for this pair (manual or scheduled).")
        XCTAssertEqual(copy.liveMonitorRunningWindowTitle("MyPair"), "Live · MyPair")
        XCTAssertEqual(copy.liveMonitorArchivedWindowTitle("MyPair"), "Last run · MyPair")
        XCTAssertEqual(copy.intervalValidationError, "Interval must be 1–1440 minutes")
        XCTAssertEqual(copy.liveMonitorRunningFooter, "Running…")
        XCTAssertEqual(copy.liveMonitorExitedSuccessFooter, "Exited successfully")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 1), "Failed (code 1)")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 127), "Failed (code 127)")
    }

    func testNewKeysRussian() {
        let copy = AppCopy(language: .russian)

        XCTAssertEqual(copy.pauseAllSchedulesToggleTitle, "Приостановить всю плановую синхронизацию")
        XCTAssertEqual(copy.scheduledSyncSectionTitle, "Scheduled sync")
        XCTAssertEqual(copy.pausedByGlobalSettingTooltip, "Приостановлено глобальной настройкой")
        XCTAssertEqual(copy.pausedForThisPairTooltip, "Приостановлено для этой pair")
        XCTAssertEqual(copy.pausedByGlobalSettingShort, "Пауза (глобально)")
        XCTAssertEqual(copy.pausedForThisPairShort, "Пауза (эта пара)")
        XCTAssertEqual(copy.openLiveMonitorButtonTitle, "Открыть Live monitor")
        XCTAssertEqual(copy.showLastLogButtonTitle, "Показать последний лог")
        XCTAssertEqual(copy.showLastLogTooltipSessionOnly,
                       "Лог хранится только в текущей сессии и появится после первой завершённой синхронизации этой пары (ручной или плановой).")
        XCTAssertEqual(copy.liveMonitorRunningWindowTitle("МояПара"), "Сейчас · МояПара")
        XCTAssertEqual(copy.liveMonitorArchivedWindowTitle("МояПара"), "Последний прогон · МояПара")
        XCTAssertEqual(copy.intervalValidationError, "Интервал должен быть от 1 до 1440 минут")
        XCTAssertEqual(copy.liveMonitorRunningFooter, "Выполняется…")
        XCTAssertEqual(copy.liveMonitorExitedSuccessFooter, "Завершено успешно")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 1), "Ошибка (код 1)")
        XCTAssertEqual(copy.liveMonitorExitedFailedFooter(code: 127), "Ошибка (код 127)")
    }
}
