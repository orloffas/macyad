import Foundation

public struct AppCopy: Sendable {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    public static var current: AppCopy {
        AppCopy(language: AppLanguageState.current)
    }

    public var onboardingTitle: String {
        isRussian ? "Подключение" : "Onboarding"
    }

    public var overviewTitle: String {
        isRussian ? "Обзор" : "Overview"
    }

    public var settingsTitle: String {
        isRussian ? "Настройки" : "Settings"
    }

    public var statusSetupRequired: String {
        isRussian ? "Требуется настройка" : "Setup required"
    }

    public var statusAttentionRequired: String {
        isRussian ? "Требуется внимание" : "Attention required"
    }

    public var statusWarningsPresent: String {
        isRussian ? "Есть предупреждения" : "Warnings present"
    }

    public var statusReady: String {
        isRussian ? "Готово" : "Ready"
    }

    public var settingsWindowTitle: String {
        isRussian ? "Настройки MacYaD" : "MacYaD Settings"
    }

    public var languageLabel: String {
        isRussian ? "Язык" : "Language"
    }

    public var russianLanguageName: String {
        isRussian ? "Русский" : "Russian"
    }

    public var englishLanguageName: String {
        isRussian ? "Английский" : "English"
    }

    public var launchAtLoginLabel: String {
        isRussian ? "Запускать при входе" : "Launch at login"
    }

    public func defaultScheduleTitle(minutes: Int) -> String {
        isRussian ? "Интервал по умолчанию: \(minutes) мин" : "Default interval: \(minutes) min"
    }

    public var restartPromptTitle: String {
        isRussian ? "Перезапустить MacYaD?" : "Restart MacYaD?"
    }

    public var restartPromptMessage: String {
        isRussian
            ? "Смена языка полностью применится после перезапуска приложения."
            : "The language change will fully apply after restarting the app."
    }

    public var restartNowButtonTitle: String {
        isRussian ? "Перезапустить сейчас" : "Restart Now"
    }

    public var laterButtonTitle: String {
        isRussian ? "Позже" : "Later"
    }

    public var applicationSectionTitle: String {
        isRussian ? "Приложение" : "Application"
    }

    public var pairsSectionTitle: String {
        isRussian ? "Пары" : "Pairs"
    }

    public var newPairButtonTitle: String {
        isRussian ? "Новая пара" : "New Pair"
    }

    public var overviewStatusLabel: String {
        isRussian ? "Статус" : "Status"
    }

    public var overviewWorkspaceLabel: String {
        isRussian ? "Рабочая папка" : "Workspace"
    }

    public var overviewPairsLabel: String {
        isRussian ? "Пары" : "Pairs"
    }

    public var inspectorTitle: String {
        isRussian ? "Инспектор" : "Inspector"
    }

    public var warningsLabel: String {
        isRussian ? "Предупреждения" : "Warnings"
    }

    public var alarmsLabel: String {
        isRussian ? "Аварии" : "Alarms"
    }

    public var manualSyncCompleted: String {
        isRussian ? "Push to Yandex завершён" : "Push to Yandex completed"
    }

    public var manualCheckCompleted: String {
        isRussian ? "Проверка Yandex завершена" : "Yandex check completed"
    }

    public var manualCheckWarningDetected: String {
        isRussian ? "Проверка Yandex обнаружила изменения" : "Yandex check detected remote changes"
    }

    public var manualPullCompleted: String {
        isRussian ? "Загрузка из Yandex завершена" : "Pull from Yandex completed"
    }

    public var manualSyncFailedPrefix: String {
        isRussian ? "Push to Yandex не выполнен" : "Push to Yandex failed"
    }

    public var manualPushBlockedTitle: String {
        isRussian ? "Push to Yandex заблокирован" : "Push to Yandex blocked"
    }

    public var manualCheckFailedPrefix: String {
        isRussian ? "Не удалось проверить Yandex" : "Failed to check Yandex"
    }

    public var manualPullFailedPrefix: String {
        isRussian ? "Не удалось загрузить из Yandex" : "Failed to pull from Yandex"
    }

    public var missingRcloneForManualAction: String {
        isRussian
            ? "Сначала установите `rclone`, затем повторите действие."
            : "Install `rclone` first, then try again."
    }

    public var installRcloneTitle: String {
        isRussian ? "Установить rclone" : "Install rclone"
    }

    public var createRemoteTitle: String {
        isRussian ? "Создать remote yd в config MacYaD" : "Create the yd remote in MacYaD config"
    }

    public var createFirstPairHint: String {
        isRussian
            ? "Создайте первую пару после настройки remote."
            : "Create your first pair after the remote is ready."
    }

    public var setupComplete: String {
        isRussian ? "Настройка завершена." : "Setup complete."
    }

    public var retryButtonTitle: String {
        isRussian ? "Проверить снова" : "Check again"
    }

    public var copyButtonTitle: String {
        isRussian ? "Скопировать" : "Copy"
    }

    public var copiedButtonTitle: String {
        isRussian ? "Скопировано" : "Copied"
    }

    public func warningsAndAlarmsSummary(warnings: Int, alarms: Int) -> String {
        if isRussian {
            return "Предупреждения \(warnings) · Аварии \(alarms)"
        }

        return "Warnings \(warnings) · Alarms \(alarms)"
    }

    public var syncShortButtonTitle: String {
        "Push to Yandex"
    }

    public var checkShortButtonTitle: String {
        isRussian ? "Проверить" : "Check"
    }

    public var pullShortButtonTitle: String {
        isRussian ? "Загрузить из Yandex" : "Pull from Yandex"
    }

    public var recentEventsTitle: String {
        isRussian ? "Последние события" : "Recent events"
    }

    public var emptyEventsTitle: String {
        isRussian ? "Пока пусто" : "Nothing yet"
    }

    public var openMainWindowTitle: String {
        isRussian ? "Открыть главное окно" : "Open main window"
    }

    public var quitApplicationTitle: String {
        isRussian ? "Завершить MacYaD" : "Quit MacYaD"
    }

    public var journalTitle: String {
        isRussian ? "Журнал" : "Activity"
    }

    public var journalEmptyHint: String {
        isRussian
            ? "События появятся после Push to Yandex, проверки или загрузки."
            : "Events will appear after Push to Yandex, check, or pull operations."
    }

    public var activityDetailsTitle: String {
        isRussian ? "Подробности события" : "Activity details"
    }

    public var activitySummaryTitle: String {
        isRussian ? "Кратко" : "Summary"
    }

    public var activityFullDetailsTitle: String {
        isRussian ? "Подробности" : "Details"
    }

    public var activityPairTitle: String {
        isRussian ? "Пара" : "Pair"
    }

    public var activityLocalPathTitle: String {
        isRussian ? "Локальный путь" : "Local path"
    }

    public var activityRemotePathTitle: String {
        isRussian ? "Yandex path" : "Yandex path"
    }

    public var activityNoDetails: String {
        isRussian ? "Для этого события нет дополнительных подробностей." : "This event has no additional details."
    }

    public var closeButtonTitle: String {
        isRussian ? "Закрыть" : "Close"
    }

    public var createPairTitle: String {
        isRussian ? "Новая пара" : "New Pair"
    }

    public var pairNamePlaceholder: String {
        isRussian ? "Имя пары" : "Pair name"
    }

    public var localFolderNotSelected: String {
        isRussian ? "Локальная папка не выбрана" : "No local folder selected"
    }

    public var localFolderNotSelectedCompact: String {
        isRussian ? "не выбрана" : "not selected"
    }

    public var chooseFolderButtonTitle: String {
        isRussian ? "Выбрать папку" : "Choose folder"
    }

    public var remotePathPlaceholder: String {
        isRussian ? "Путь на Yandex" : "Yandex path"
    }

    public func intervalTitle(minutes: Int) -> String {
        isRussian ? "Интервал: \(minutes) мин" : "Interval: \(minutes) min"
    }

    public var deletePolicyLabel: String {
        isRussian ? "Политика удаления" : "Delete policy"
    }

    public var deletePolicyMirrorTitle: String {
        isRussian ? "Зеркалить в Yandex" : "Mirror to Yandex"
    }

    public var deletePolicyManualTitle: String {
        isRussian ? "Удаления на Yandex вручную" : "Handle Yandex deletions manually"
    }

    public var cancelButtonTitle: String {
        isRussian ? "Отмена" : "Cancel"
    }

    public var savePairButtonTitle: String {
        isRussian ? "Сохранить пару" : "Save pair"
    }

    public func createPairSummary(folder: String, remotePath: String, scheduleMinutes: Int) -> String {
        if isRussian {
            return "Будет Push to Yandex \(folder) -> \(remotePath) каждые \(scheduleMinutes) мин."
        }

        return "Will Push to Yandex \(folder) -> \(remotePath) every \(scheduleMinutes) min."
    }

    public var localFolderTitle: String {
        isRussian ? "Локальная папка" : "Local folder"
    }

    public var remotePathTitle: String {
        isRussian ? "Путь на Yandex" : "Yandex path"
    }

    public var scheduleFieldTitle: String {
        isRussian ? "Интервал" : "Interval"
    }

    public func minutesValue(_ minutes: Int) -> String {
        isRussian ? "\(minutes) мин" : "\(minutes) min"
    }

    public var deletePolicyFieldTitle: String {
        isRussian ? "Политика удаления" : "Delete policy"
    }

    public var lastSyncTitle: String {
        isRussian ? "Последний Push to Yandex" : "Last Push to Yandex"
    }

    public var nextSyncTitle: String {
        isRussian ? "Следующий Push to Yandex" : "Next Push to Yandex"
    }

    public var noPairTitle: String {
        isRussian ? "Пара не выбрана" : "No pair selected"
    }

    public var noPairDescription: String {
        isRussian
            ? "Выберите существующую пару в боковой панели или создайте новую."
            : "Select an existing pair in the sidebar or create a new one."
    }

    public func lastStatusTitle(_ status: String) -> String {
        isRussian ? "Последний статус: \(status)" : "Latest status: \(status)"
    }

    public var syncButtonTitle: String {
        "Push to Yandex"
    }

    public var checkButtonTitle: String {
        isRussian ? "Проверить Yandex" : "Check Yandex"
    }

    public var pullButtonTitle: String {
        isRussian ? "Загрузить из Yandex" : "Pull from Yandex"
    }

    public var lastErrorTitle: String {
        isRussian ? "Последняя ошибка" : "Latest error"
    }

    public var severityHealthy: String {
        isRussian ? "Норма" : "Healthy"
    }

    public var severityInfo: String {
        isRussian ? "Информация" : "Info"
    }

    public var severityWarning: String {
        isRussian ? "Предупреждение" : "Warning"
    }

    public var severityAlarm: String {
        isRussian ? "Авария" : "Alarm"
    }

    public var neverSynced: String {
        isRussian ? "Ещё не выполнялась" : "Not run yet"
    }

    public var afterFirstSuccessfulSync: String {
        isRussian ? "После первого успешного Push to Yandex" : "After the first successful Push to Yandex"
    }

    public var pairValidationEmptyName: String {
        isRussian ? "Введите имя пары." : "Enter a pair name."
    }

    public var pairValidationMissingLocalFolder: String {
        isRussian ? "Выберите локальную папку." : "Choose a local folder."
    }

    public var pairValidationEmptyRemotePath: String {
        isRussian ? "Укажите remote path." : "Enter a remote path."
    }

    public var pairValidationInvalidSchedule: String {
        isRussian
            ? "Интервал должен быть больше нуля."
            : "The interval must be greater than zero."
    }

    public func rcloneCommandFailed(command: [String], exitCode: Int32, stderr: String) -> String {
        let stderrSuffix = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : ": \(stderr)"

        if isRussian {
            return "rclone \(command.joined(separator: " ")) завершился с кодом \(exitCode)\(stderrSuffix)"
        }

        return "rclone \(command.joined(separator: " ")) exited with code \(exitCode)\(stderrSuffix)"
    }

    public func rcloneCommandLog(command: [String], exitCode: Int32, stdout: String, stderr: String) -> String {
        let normalizedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdoutBlock = normalizedStdout.isEmpty
            ? (isRussian ? "<пусто>" : "<empty>")
            : normalizedStdout
        let stderrBlock = normalizedStderr.isEmpty
            ? (isRussian ? "<пусто>" : "<empty>")
            : normalizedStderr

        if isRussian {
            return """
            Команда rclone
            \(command.joined(separator: " "))

            Код завершения: \(exitCode)

            stdout
            \(stdoutBlock)

            stderr
            \(stderrBlock)
            """
        }

        return """
        rclone command
        \(command.joined(separator: " "))

        Exit code: \(exitCode)

        stdout
        \(stdoutBlock)

        stderr
        \(stderrBlock)
        """
    }

    public var scheduledSyncBootstrapFailure: String {
        isRussian
            ? "Не удалось инициализировать scheduled Push to Yandex."
            : "Failed to initialize scheduled Push to Yandex."
    }

    public var scheduledSyncNotificationTitle: String {
        isRussian ? "MacYaD: плановый Push to Yandex не выполнен" : "MacYaD: scheduled Push to Yandex failed"
    }

    public var scheduledSyncCompleted: String {
        isRussian ? "Плановый Push to Yandex завершён" : "Scheduled Push to Yandex completed"
    }

    public func scheduledSyncFailed(_ message: String) -> String {
        if isRussian {
            return "Плановый Push to Yandex не выполнен: \(message)"
        }

        return "Scheduled Push to Yandex failed: \(message)"
    }

    public var scheduledSyncFailedPrefix: String {
        isRussian ? "Плановый Push to Yandex не выполнен" : "Scheduled Push to Yandex failed"
    }

    public var scheduledSyncSkipped: String {
        isRussian ? "Плановый Push to Yandex пропущен" : "Scheduled Push to Yandex skipped"
    }

    public var scheduledPushBlockedTitle: String {
        isRussian ? "Плановый Push to Yandex заблокирован" : "Scheduled Push to Yandex blocked"
    }

    public var pushBlockedNotificationTitle: String {
        isRussian ? "MacYaD: Push to Yandex заблокирован" : "MacYaD: Push to Yandex blocked"
    }

    public var localFolderEmptyPushBlocked: String {
        isRussian
            ? "Локальная папка пуста. Сначала выполните Pull From Yandex; Push to Yandex заблокирован, чтобы не очистить Yandex."
            : "Local folder is empty. Run Pull From Yandex first; Push to Yandex was blocked to avoid clearing Yandex."
    }

    public func checkWarningDetails(logDescription: String) -> String {
        let summary = isRussian
            ? "Проверка Yandex обнаружила изменения или drift на стороне remote. Перед следующим Push to Yandex проверьте состояние и при необходимости выполните Pull From Yandex."
            : "Check Yandex detected remote changes or drift. Review the state and run Pull From Yandex before the next Push to Yandex if needed."
        return "\(summary)\n\n\(logDescription)"
    }

    public var backgroundSyncRcloneUnavailable: String {
        isRussian
            ? "rclone не найден для scheduled Push to Yandex."
            : "rclone not found for scheduled Push to Yandex."
    }

    public var folderPickerTitle: String {
        isRussian ? "Выберите локальную папку" : "Choose a local folder"
    }

    public var folderPickerPrompt: String {
        isRussian ? "Выбрать" : "Choose"
    }

    public func formatTimestamp(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: language.rawValue))
        )
    }

    private var isRussian: Bool {
        language == .russian
    }
}
