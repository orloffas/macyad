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

    public var notificationsSectionTitle: String {
        isRussian ? "Уведомления" : "Notifications"
    }

    public var notificationsStatusLabel: String {
        isRussian ? "Статус разрешений" : "Permission status"
    }

    public var notificationsRequestButtonTitle: String {
        isRussian ? "Запросить доступ" : "Request permission"
    }

    public var notificationsSendTestButtonTitle: String {
        isRussian ? "Отправить test notification" : "Send test notification"
    }

    public var notificationsLastAttemptLabel: String {
        isRussian ? "Последняя попытка" : "Last attempt"
    }

    public var notificationsStatusAuthorized: String {
        isRussian ? "Разрешено" : "Authorized"
    }

    public var notificationsStatusDenied: String {
        isRussian ? "Запрещено" : "Denied"
    }

    public var notificationsStatusNotDetermined: String {
        isRussian ? "Ещё не запрошено" : "Not requested yet"
    }

    public var notificationsStatusProvisional: String {
        isRussian ? "Временный доступ" : "Provisional"
    }

    public var notificationsStatusEphemeral: String {
        isRussian ? "Ephemeral" : "Ephemeral"
    }

    public var notificationsStatusUnknown: String {
        isRussian ? "Неизвестно" : "Unknown"
    }

    public var notificationsTestTitle: String {
        isRussian ? "MacYaD: test notification" : "MacYaD: test notification"
    }

    public var notificationsTestBody: String {
        isRussian ? "Если вы видите это уведомление, системные уведомления работают." : "If you can see this, macOS notifications are working."
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

    public var accountsSectionTitle: String {
        isRussian ? "Yandex accounts" : "Yandex accounts"
    }

    public var addAccountButtonTitle: String {
        isRussian ? "Добавить account" : "Add account"
    }

    public var removeAccountButtonTitle: String {
        isRussian ? "Удалить account" : "Remove account"
    }

    public var reconnectAccountButtonTitle: String {
        isRussian ? "Reconnect account" : "Reconnect account"
    }

    public var recreateAccountButtonTitle: String {
        isRussian ? "Recreate managed remote" : "Recreate managed remote"
    }

    public var accountDisplayNameLabel: String {
        isRussian ? "Имя account" : "Account name"
    }

    public var accountRemoteNameLabel: String {
        isRussian ? "Имя remote" : "Remote name"
    }

    public var accountConfigPathLabel: String {
        isRussian ? "Файл config rclone" : "rclone config file"
    }

    public var accountManagedLabel: String {
        isRussian ? "Managed remote" : "Managed remote"
    }

    public var accountInUseHint: String {
        isRussian ? "Нельзя удалить account, пока на него ссылаются пары." : "An account can't be removed while pairs still reference it."
    }

    public var accountRemoteNameHint: String {
        isRussian ? "Это имя секции remote внутри rclone.conf." : "This is the remote section name inside rclone.conf."
    }

    public var accountValidationEmptyDisplayName: String {
        isRussian ? "Введите имя account." : "Enter an account name."
    }

    public var accountValidationEmptyRemoteName: String {
        isRussian ? "Введите имя remote." : "Enter a remote name."
    }

    public var accountValidationDuplicateRemoteName: String {
        isRussian ? "Такой remote уже добавлен." : "That remote is already added."
    }

    public var accountValidationInUse: String {
        isRussian ? "Сначала удалите или переназначьте пары, использующие этот account." : "Reassign or delete the pairs using this account first."
    }

    public func accountRemovalBlockedMessage(pairNames: [String]) -> String {
        let joinedPairNames = pairNames.joined(separator: ", ")

        if isRussian {
            if pairNames.count == 1 {
                return "Account нельзя удалить, пока pair \(joinedPairNames) привязана к нему."
            }

            return "Account нельзя удалить, пока к нему привязаны pair: \(joinedPairNames)."
        }

        if pairNames.count == 1 {
            return "This account can't be removed while pair \(joinedPairNames) still references it."
        }

        return "This account can't be removed while these pairs still reference it: \(joinedPairNames)."
    }

    public var noAccountsHint: String {
        isRussian ? "Сначала добавьте хотя бы один Yandex account. Пары без account не создаются." : "Add at least one Yandex account first. Pairs can't be created without an account."
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

    public var openInFinderTitle: String {
        isRussian ? "Открыть в Finder" : "Open in Finder"
    }

    public var configurationSectionTitle: String {
        isRussian ? "Конфигурация" : "Configuration"
    }

    public var exportConfigurationButtonTitle: String {
        isRussian ? "Экспортировать…" : "Export…"
    }

    public var importConfigurationButtonTitle: String {
        isRussian ? "Импортировать…" : "Import…"
    }

    public var configurationExportHint: String {
        if isRussian {
            return """
            В файл попадают пары, аккаунты и настройки приложения. \
            Паролей и токенов Yandex в нём нет — они хранятся в rclone.conf. \
            Выданные macOS разрешения на доступ к папкам файл тоже не переносит: \
            на другом Mac папки нужно будет выбрать заново.
            """
        }

        return """
        The file holds pairs, accounts and app preferences. It contains no \
        Yandex passwords or tokens — those live in rclone.conf. It also cannot \
        carry macOS folder permissions: on another Mac the folders have to be \
        picked again.
        """
    }

    public var configurationExportPanelTitle: String {
        isRussian ? "Экспорт конфигурации MacYaD" : "Export MacYaD configuration"
    }

    public var configurationImportPanelTitle: String {
        isRussian ? "Импорт конфигурации MacYaD" : "Import MacYaD configuration"
    }

    public var configurationExportFileName: String {
        "macyad-configuration.json"
    }

    public var configurationImportConfirmTitle: String {
        isRussian ? "Заменить текущую конфигурацию?" : "Replace the current configuration?"
    }

    public func configurationImportConfirmMessage(pairs: Int, accounts: Int) -> String {
        if isRussian {
            return """
            В файле: пар — \(pairs), аккаунтов — \(accounts). \
            Текущие пары, аккаунты и настройки будут заменены. \
            Файлы в локальных папках и на Yandex не затрагиваются.
            """
        }

        return """
        The file holds \(pairs) pair(s) and \(accounts) account(s). Your current \
        pairs, accounts and preferences will be replaced. Files in the local \
        folders and on Yandex are left alone.
        """
    }

    public var configurationImportConfirmButtonTitle: String {
        isRussian ? "Заменить" : "Replace"
    }

    public func configurationImportSummary(pairs: Int, accounts: Int) -> String {
        if isRussian {
            return """
            Импортировано пар: \(pairs), аккаунтов: \(accounts). \
            Плановая синхронизация выключена у всех пар: сначала выполните \
            «\(checkButtonTitle)» и убедитесь, что папки совпадают, и только \
            потом включайте Auto-sync.
            """
        }

        return """
        Imported \(pairs) pair(s) and \(accounts) account(s). Scheduled sync is \
        off for every pair: run "\(checkButtonTitle)" first to confirm the two \
        sides agree, then turn Auto-sync back on.
        """
    }

    public var configurationImportDoneTitle: String {
        isRussian ? "Конфигурация импортирована" : "Configuration imported"
    }

    public var configurationImportIssuesTitle: String {
        isRussian ? "Требуют внимания:" : "Needs attention:"
    }

    public func configurationImportMissingFolderIssue(pair: String, path: String) -> String {
        if isRussian {
            return "\(pair): папка \(path) не найдена на этом Mac — выберите её в настройках пары."
        }

        return "\(pair): the folder \(path) is not on this Mac — pick it in the pair settings."
    }

    public func configurationImportMissingRemoteIssue(pair: String, remote: String) -> String {
        if isRussian {
            return "\(pair): remote «\(remote)» не настроен в rclone на этом Mac."
        }

        return "\(pair): the remote \"\(remote)\" is not configured in rclone on this Mac."
    }

    public func configurationImportUnsupportedSchema(found: Int, supported: Int) -> String {
        if isRussian {
            return "Файл создан более новой версией MacYaD (формат \(found), поддерживается \(supported))."
        }

        return "The file comes from a newer MacYaD (format \(found), supported \(supported))."
    }

    public func configurationExportFailed(_ reason: String) -> String {
        isRussian ? "Не удалось экспортировать конфигурацию: \(reason)" : "Could not export the configuration: \(reason)"
    }

    public func configurationImportFailed(_ reason: String) -> String {
        isRussian ? "Не удалось импортировать конфигурацию: \(reason)" : "Could not import the configuration: \(reason)"
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

    public var manualPullBlockedTitle: String {
        isRussian ? "Pull from Yandex заблокирован" : "Pull from Yandex blocked"
    }

    public var manualPullAlreadyRunningTitle: String {
        isRussian ? "Pull from Yandex уже выполняется" : "Pull from Yandex is already running"
    }

    public func manualPullAlreadyRunningDetails(pairName: String, pid: Int32, commandLine: String) -> String {
        if isRussian {
            return "Для pair \(pairName) уже выполняется rclone copy (PID \(pid)). Повторный Pull from Yandex пропущен, чтобы не запускать второй recursive scan параллельно.\n\nCommand: \(commandLine)"
        }

        return "An rclone copy is already running for pair \(pairName) (PID \(pid)). Skipped this Pull from Yandex to avoid starting a second recursive scan in parallel.\n\nCommand: \(commandLine)"
    }

    public var manualConflictReconciledTitle: String {
        isRussian ? "Конфликт обработан, обе копии сохранены" : "Conflict reconciled, both copies preserved"
    }

    public func issueResolutionCompleted(count: Int) -> String {
        if isRussian {
            return "Решения по файлам применены: \(count)"
        }

        return "Applied file resolutions: \(count)"
    }

    public func issueResolutionRemaining(count: Int) -> String {
        if isRussian {
            return "Остались нерешённые файлы: \(count)"
        }

        return "Unresolved files remain: \(count)"
    }

    public func issueResolutionDetails(appliedCount: Int, remainingCount: Int) -> String {
        if isRussian {
            return "Применено решений: \(appliedCount). Осталось без решения: \(remainingCount)."
        }

        return "Applied decisions: \(appliedCount). Remaining unresolved: \(remainingCount)."
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

    public var onboardingAccountsHint: String {
        isRussian ? "После установки rclone откройте Settings и добавьте Yandex account. Там же видно путь к rclone.conf." : "After installing rclone, open Settings and add a Yandex account. The same screen shows the rclone.conf path."
    }

    public var createFirstPairHint: String {
        isRussian
            ? "Создайте первую пару после настройки remote."
            : "Create your first pair after the remote is ready."
    }

    public var onboardingRcloneStatusLabel: String {
        "rclone"
    }

    public var onboardingRemoteStatusLabel: String {
        "Remote"
    }

    public var onboardingPairsStatusLabel: String {
        isRussian ? "Пары" : "Pairs"
    }

    public var onboardingSchedulerStatusLabel: String {
        isRussian ? "Плановая синхронизация" : "Scheduled sync"
    }

    public var onboardingLastCheckStatusLabel: String {
        isRussian ? "Последняя проверка" : "Last check"
    }

    public var onboardingRcloneMissing: String {
        isRussian ? "Не найден" : "Missing"
    }

    public var onboardingRemoteMissing: String {
        isRussian ? "Не настроен" : "Not configured"
    }

    public var onboardingSchedulerActive: String {
        isRussian ? "Активна" : "Active"
    }

    public var onboardingSchedulerPaused: String {
        isRussian ? "Приостановлена" : "Paused"
    }

    public var onboardingSchedulerIdle: String {
        isRussian ? "Нет активных пар" : "No active pairs"
    }

    public var onboardingNeverChecked: String {
        isRussian ? "Ещё не выполнялась" : "Not checked yet"
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
        "Pull from Yandex"
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

    public func activityCollapsedRunSummary(count: Int) -> String {
        if isRussian {
            return "\(count) одинаковых события"
        }

        return "\(count) identical events"
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

    public var reviewFilesButtonTitle: String {
        isRussian ? "Проверить файлы" : "Review files"
    }

    public var issueReviewTitle: String {
        isRussian ? "Разбор проблемных файлов" : "Review problem files"
    }

    public var issueReviewSearchPlaceholder: String {
        isRussian ? "Поиск по пути или имени файла" : "Search path or file name"
    }

    public var issueReviewFilterLabel: String {
        isRussian ? "Фильтр" : "Filter"
    }

    public var issueReviewFilterAll: String {
        isRussian ? "Все" : "All"
    }

    public var issueReviewFilterConflicts: String {
        isRussian ? "Конфликты" : "Conflicts"
    }

    public var issueReviewFilterRemoteOnly: String {
        isRussian ? "Только remote" : "Remote only"
    }

    public var issueReviewFilterLocalOnly: String {
        isRussian ? "Только local" : "Local only"
    }

    public var issueReviewFilterDeleteVsModify: String {
        isRussian ? "Удаление vs изменение" : "Delete vs modify"
    }

    public var issueReviewFilterBaselineMissing: String {
        isRussian ? "Нет baseline" : "Baseline missing"
    }

    public var issueReviewSelectAllVisible: String {
        isRussian ? "Выбрать всё видимое" : "Select all visible"
    }

    public var issueReviewClearSelection: String {
        isRussian ? "Снять выделение" : "Clear selection"
    }

    public var issueReviewSetSelectedTo: String {
        isRussian ? "Для выбранных…" : "Set selected to..."
    }

    public var issueReviewSetAllVisibleTo: String {
        isRussian ? "Для всех видимых…" : "Set all visible to..."
    }

    public var issueReviewApplyButtonTitle: String {
        isRussian ? "Применить решения" : "Apply decisions"
    }

    public var issueReviewPathColumnTitle: String {
        isRussian ? "Путь" : "Path"
    }

    public var issueReviewFileColumnTitle: String {
        isRussian ? "Файл" : "File"
    }

    public var issueReviewProblemColumnTitle: String {
        isRussian ? "Проблема" : "Problem"
    }

    public var issueReviewLocalColumnTitle: String {
        isRussian ? "Local" : "Local"
    }

    public var issueReviewRemoteColumnTitle: String {
        isRussian ? "Remote" : "Remote"
    }

    public var issueReviewDecisionColumnTitle: String {
        isRussian ? "Решение" : "Decision"
    }

    public var issueReviewMeaningSectionTitle: String {
        isRussian ? "Что это значит" : "What it means"
    }

    public var issueReviewRawSectionTitle: String {
        "Raw comparison"
    }

    public var issueReviewSnapshotsSectionTitle: String {
        isRussian ? "Снимки" : "Snapshots"
    }

    public var issueReviewBaselineSectionTitle: String {
        isRussian ? "Baseline" : "Baseline"
    }

    public var issueReviewDecisionSectionTitle: String {
        isRussian ? "Решение" : "Decision"
    }

    public var issueReviewNoSelectionTitle: String {
        isRussian ? "Выберите один файл" : "Select one file"
    }

    public var issueReviewNoSelectionMessage: String {
        isRussian
            ? "Выделите одну строку в таблице, чтобы увидеть человеческое объяснение, raw comparison и metadata snapshots."
            : "Select a single row in the table to inspect the human explanation, raw comparison, and snapshot metadata."
    }

    public func issueReviewMultipleSelectionTitle(count: Int) -> String {
        if isRussian {
            return "Выбрано файлов: \(count)"
        }

        return "Selected files: \(count)"
    }

    public func issueReviewMultipleSelectionMessage(unresolvedCount: Int) -> String {
        if isRussian {
            return "Для пакетного решения используйте верхнее меню. Без решения пока осталось: \(unresolvedCount)."
        }

        return "Use the toolbar bulk actions to apply one decision to this selection. Still unresolved: \(unresolvedCount)."
    }

    public var issueDecisionKeepLocalTitle: String {
        isRussian ? "Оставить local" : "Keep local"
    }

    public var issueDecisionKeepRemoteTitle: String {
        isRussian ? "Оставить remote" : "Keep remote"
    }

    public var issueDecisionKeepBothTitle: String {
        isRussian ? "Сохранить обе" : "Keep both"
    }

    public var issueDecisionLaterTitle: String {
        isRussian ? "Позже" : "Later"
    }

    public func issueReviewSummary(visibleCount: Int, selectedCount: Int, unresolvedCount: Int) -> String {
        if isRussian {
            return "Видимо: \(visibleCount) · Выбрано: \(selectedCount) · Без решения: \(unresolvedCount)"
        }

        return "Visible: \(visibleCount) · Selected: \(selectedCount) · Unresolved: \(unresolvedCount)"
    }

    public var issueReviewNoIssues: String {
        isRussian ? "Для этого события нет файлов, требующих ручного решения." : "This event has no files that require manual review."
    }

    public var lastPairDeleteDisabledMessage: String {
        isRussian ? "Последнюю pair удалить нельзя." : "The last pair can't be removed."
    }

    public var createPairTitle: String {
        isRussian ? "Новая пара" : "New Pair"
    }

    public var editPairTitle: String {
        isRussian ? "Изменить пару" : "Edit Pair"
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

    public var accountPickerLabel: String {
        isRussian ? "Yandex account" : "Yandex account"
    }

    public var remoteSubpathLabel: String {
        isRussian ? "Путь внутри account" : "Path inside account"
    }

    public var remoteSubpathDescription: String {
        isRussian ? "Пара сохранит полный путь как remoteName:/path и будет явно привязана к выбранному account." : "The pair stores the full remoteName:/path and is explicitly bound to the selected account."
    }

    public var conflictPolicyLabel: String {
        isRussian ? "Conflict policy" : "Conflict policy"
    }

    public var conflictPolicyBlockTitle: String {
        isRussian ? "Блокировать Push/Pull при конфликте" : "Block Push/Pull on conflict"
    }

    public var conflictPolicyKeepBothTitle: String {
        isRussian ? "Сохранять обе копии" : "Keep both copies"
    }

    public var conflictPolicyDescription: String {
        if isRussian {
            return "При drift/conflict MacYaD всегда создаёт Review files и ждёт явного решения по строкам или пакетно. Это поле сохраняет product intent пары, но не запускает авто-перезапись файлов."
        }

        return "When drift or conflicts are detected, MacYaD always opens Review files and waits for explicit row-level or bulk decisions. This field keeps the pair's product intent, but it never triggers automatic overwrites."
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

    public var savePairChangesButtonTitle: String {
        isRussian ? "Сохранить изменения" : "Save changes"
    }

    public var deletePairTitle: String {
        isRussian ? "Удалить пару" : "Delete pair"
    }

    public var deletePairConfirmationTitle: String {
        isRussian ? "Удалить пару?" : "Delete pair?"
    }

    public func deletePairConfirmationMessage(_ pairName: String) -> String {
        if isRussian {
            return "Пара \(pairName) и её activity будут удалены."
        }

        return "The pair \(pairName) and its activity will be deleted."
    }

    public var deletePairConfirmButtonTitle: String {
        isRussian ? "Удалить" : "Delete"
    }

    public var syncExcludesTitle: String {
        isRussian ? "Sync excludes" : "Sync excludes"
    }

    public var checkAdditionalExcludesTitle: String {
        isRussian ? "Additional check excludes" : "Additional check excludes"
    }

    public var syncExcludesDescription: String {
        if isRussian {
            return "Применяется к Push to Yandex, Pull from Yandex и Check Yandex. По одному pattern на строку."
        }

        return "Applied to Push to Yandex, Pull from Yandex, and Check Yandex. Use one pattern per line."
    }

    public var checkAdditionalExcludesDescription: String {
        if isRussian {
            return "Check Yandex всегда использует Sync excludes и дополнительно добавляет patterns из этого списка."
        }

        return "Check Yandex always includes Sync excludes first and then adds the patterns from this list."
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

    public var accountTitle: String {
        isRussian ? "Yandex account" : "Yandex account"
    }

    public var conflictPolicyFieldTitle: String {
        isRussian ? "Conflict policy" : "Conflict policy"
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
        isRussian ? "Последняя синхронизация" : "Last sync"
    }

    public var nextSyncTitle: String {
        isRussian ? "Следующая синхронизация" : "Next sync"
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
        "Pull from Yandex"
    }

    public var pushActionDescription: String {
        if isRussian {
            return "Отправляет локальные изменения в Yandex и при mirror policy может удалять лишнее на стороне remote."
        }

        return "Pushes local changes to Yandex and may delete extra remote items when mirror policy is enabled."
    }

    public var checkActionDescription: String {
        if isRussian {
            return "Сравнивает локальную папку и Yandex без изменения данных."
        }

        return "Compares the local folder with Yandex without modifying data."
    }

    public var pullActionDescription: String {
        if isRussian {
            return "Копирует изменения из Yandex в локальную папку без удаления локальных файлов."
        }

        return "Copies changes from Yandex into the local folder without deleting local files."
    }

    public var lastErrorTitle: String {
        isRussian ? "Последняя ошибка" : "Latest error"
    }

    public var actionsHelpTitle: String {
        isRussian ? "Что делает каждая команда" : "What each action does"
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
        isRussian ? "После первой успешной синхронизации" : "After the first successful sync"
    }

    public var operationQueued: String {
        isRussian ? "В очереди" : "Queued"
    }

    public var operationRunning: String {
        isRussian ? "Выполняется" : "Running"
    }

    public func operationStartedMessage(_ operation: String) -> String {
        isRussian ? "\(operation): выполняется…" : "\(operation): running…"
    }

    public func operationInterruptedMessage(_ operation: String) -> String {
        if isRussian {
            return "\(operation): прервано — приложение было закрыто во время выполнения"
        }

        return "\(operation): interrupted — the app was quit while it was running"
    }

    public var operationInterruptedDetails: String {
        if isRussian {
            return """
            Результат неизвестен: MacYaD завершился до того, как операция отчиталась. \
            Часть файлов могла быть перенесена. Нажмите «Проверить Яндекс», чтобы \
            сравнить папки, и при необходимости повторите операцию.
            """
        }

        return """
        The result is unknown: MacYaD exited before the operation reported back. \
        Some files may have been transferred. Run "Check Yandex" to compare the \
        folders and repeat the operation if needed.
        """
    }

    public var pairValidationEmptyName: String {
        isRussian ? "Введите имя пары." : "Enter a pair name."
    }

    public var pairValidationMissingLocalFolder: String {
        isRussian ? "Выберите локальную папку." : "Choose a local folder."
    }

    public var pairValidationMissingAccount: String {
        isRussian ? "Сначала выберите Yandex account." : "Choose a Yandex account first."
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

    public func rcloneCommandSummary(exitCode: Int32, stderr: String) -> String {
        let trimmedStderr = stderr
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .map(stripRcloneLogPrefix)

        if let trimmedStderr, !trimmedStderr.isEmpty {
            let summary = trimmedStderr.count > 180
                ? String(trimmedStderr.prefix(177)) + "..."
                : trimmedStderr

            if isRussian {
                return "rclone завершился с кодом \(exitCode): \(summary)"
            }

            return "rclone exited with code \(exitCode): \(summary)"
        }

        if isRussian {
            return "rclone завершился с кодом \(exitCode)"
        }

        return "rclone exited with code \(exitCode)"
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
            Код завершения: \(exitCode)

            stderr
            \(stderrBlock)

            stdout
            \(stdoutBlock)

            Команда rclone
            \(command.joined(separator: " "))
            """
        }

        return """
        Exit code: \(exitCode)

        stderr
        \(stderrBlock)

        stdout
        \(stdoutBlock)

        rclone command
        \(command.joined(separator: " "))
        """
    }

    public var pauseAllSchedulesToggleTitle: String {
        isRussian ? "Приостановить всю плановую синхронизацию" : "Pause all scheduled syncs"
    }

    public var scheduledSyncSectionTitle: String {
        isRussian ? "Плановая синхронизация" : "Scheduled sync"
    }

    public var pausedByGlobalSettingTooltip: String {
        isRussian ? "Приостановлено глобальной настройкой" : "Paused by global setting"
    }

    public var pausedForThisPairTooltip: String {
        isRussian ? "Приостановлено для этой pair" : "Paused for this pair"
    }

    public var pausedByGlobalSettingShort: String {
        isRussian ? "Пауза (глобально)" : "Paused (global)"
    }

    public var pausedForThisPairShort: String {
        isRussian ? "Пауза (эта пара)" : "Paused (this pair)"
    }

    public var autoSyncModeLabel: String {
        isRussian ? "Автосинхронизация" : "Auto-sync"
    }

    public func autoSyncModeTitle(_ mode: AutoSyncMode) -> String {
        switch mode {
        case .off:
            isRussian ? "Выключена" : "Off"
        case .push:
            isRussian ? "Auto-Push" : "Auto-Push"
        case .pull:
            isRussian ? "Auto-Pull" : "Auto-Pull"
        }
    }

    public func autoSyncModeTooltip(_ mode: AutoSyncMode) -> String {
        switch mode {
        case .off:
            isRussian
                ? "Плановая синхронизация выключена — только ручные операции."
                : "Scheduled sync is off — manual operations only."
        case .push:
            isRussian
                ? "По расписанию выполняется Push to Yandex: локальная папка → Yandex."
                : "Runs Push to Yandex on schedule: local folder → Yandex."
        case .pull:
            isRussian
                ? "По расписанию выполняется Pull From Yandex: Yandex → локальная папка."
                : "Runs Pull From Yandex on schedule: Yandex → local folder."
        }
    }

    public var autoSyncModeExclusiveHint: String {
        isRussian
            ? "Пара синхронизируется строго в одну сторону: локально → Yandex или Yandex → локально. Ручные операции доступны всегда."
            : "A pair syncs in one direction only: local → Yandex or Yandex → local. Manual operations remain available."
    }

    public var openLiveMonitorButtonTitle: String {
        isRussian ? "Открыть Live monitor" : "Open Live monitor"
    }

    public var showLastLogButtonTitle: String {
        isRussian ? "Показать последний лог" : "Show last log"
    }

    public var showLastLogTooltipSessionOnly: String {
        isRussian
            ? "Лог хранится только в текущей сессии и появится после первой завершённой синхронизации этой пары (ручной или плановой)."
            : "The log is kept only for this session and becomes available after the first completed sync for this pair (manual or scheduled)."
    }

    public func liveMonitorRunningWindowTitle(_ pairName: String) -> String {
        isRussian ? "Сейчас · \(pairName)" : "Live · \(pairName)"
    }

    public func liveMonitorArchivedWindowTitle(_ pairName: String) -> String {
        isRussian ? "Последний прогон · \(pairName)" : "Last run · \(pairName)"
    }

    public var intervalValidationError: String {
        isRussian ? "Интервал должен быть от 1 до 1440 минут" : "Interval must be 1–1440 minutes"
    }

    public var liveMonitorRunningFooter: String {
        isRussian ? "Выполняется…" : "Running…"
    }

    public var liveMonitorExitedSuccessFooter: String {
        isRussian ? "Завершено успешно" : "Exited successfully"
    }

    public func liveMonitorExitedFailedFooter(code: Int32) -> String {
        isRussian ? "Ошибка (код \(code))" : "Failed (code \(code))"
    }

    /// Name of the rclone-facing operation a scheduled run performs, used to
    /// build the scheduled-sync copy below for both directions.
    public func scheduledSyncOperationName(_ direction: AutoSyncMode) -> String {
        direction == .pull ? "Pull From Yandex" : "Push to Yandex"
    }

    public func scheduledSyncBootstrapFailure(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian
            ? "Не удалось инициализировать плановый \(operation)."
            : "Failed to initialize scheduled \(operation)."
    }

    public func scheduledSyncNotificationTitle(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "MacYaD: плановый \(operation) не выполнен" : "MacYaD: scheduled \(operation) failed"
    }

    public func scheduledSyncCompleted(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "Плановый \(operation) завершён" : "Scheduled \(operation) completed"
    }

    public func scheduledSyncFailed(_ message: String, direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        if isRussian {
            return "Плановый \(operation) не выполнен: \(message)"
        }

        return "Scheduled \(operation) failed: \(message)"
    }

    public func scheduledSyncFailedPrefix(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "Плановый \(operation) не выполнен" : "Scheduled \(operation) failed"
    }

    public func scheduledSyncSkipped(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "Плановый \(operation) пропущен" : "Scheduled \(operation) skipped"
    }

    public func scheduledSyncBlockedTitle(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "Плановый \(operation) заблокирован" : "Scheduled \(operation) blocked"
    }

    public func syncBlockedNotificationTitle(_ direction: AutoSyncMode) -> String {
        let operation = scheduledSyncOperationName(direction)
        return isRussian ? "MacYaD: \(operation) заблокирован" : "MacYaD: \(operation) blocked"
    }

    public var localFolderEmptyPushBlocked: String {
        isRussian
            ? "Локальная папка пуста. Сначала выполните Pull From Yandex; Push to Yandex заблокирован, чтобы не очистить Yandex."
            : "Local folder is empty. Run Pull From Yandex first; Push to Yandex was blocked to avoid clearing Yandex."
    }

    public var baselineMissingBlockedSummary: String {
        isRussian ? "Базовое согласованное состояние ещё не создано. Push/Pull заблокирован, пока не будет понятно, какая сторона изменилась." : "The agreed baseline is missing. Push/Pull is blocked until the current state is reconciled."
    }

    public func remoteDriftBlockedSummary(count: Int, samplePath: String?) -> String {
        if isRussian {
            if let samplePath {
                return "На стороне remote есть \(count) измен. Example: \(samplePath). Push to Yandex заблокирован."
            }
            return "На стороне remote есть \(count) измен. Push to Yandex заблокирован."
        }

        if let samplePath {
            return "The remote side has \(count) change(s). Example: \(samplePath). Push to Yandex was blocked."
        }

        return "The remote side has \(count) change(s). Push to Yandex was blocked."
    }

    public func localDriftBlockedSummary(count: Int, samplePath: String?) -> String {
        if isRussian {
            if let samplePath {
                return "Локальная сторона содержит \(count) измен. Example: \(samplePath). Pull from Yandex заблокирован."
            }
            return "Локальная сторона содержит \(count) измен. Pull from Yandex заблокирован."
        }

        if let samplePath {
            return "The local side has \(count) change(s). Example: \(samplePath). Pull from Yandex was blocked."
        }

        return "The local side has \(count) change(s). Pull from Yandex was blocked."
    }

    public func keepBothSummary(conflictCount: Int, samplePath: String?) -> String {
        if isRussian {
            if let samplePath {
                return "Для \(conflictCount) conflict path(s) сохранены обе версии через явные conflict-copy. Example: \(samplePath)."
            }
            return "Для \(conflictCount) conflict path(s) сохранены обе версии через явные conflict-copy."
        }

        if let samplePath {
            return "Preserved both versions for \(conflictCount) conflict path(s) by creating explicit conflict copies. Example: \(samplePath)."
        }

        return "Preserved both versions for \(conflictCount) conflict path(s) by creating explicit conflict copies."
    }

    public func baselineAwareCheckSummary(_ classification: String) -> String {
        if isRussian {
            return "Check Yandex: \(classification)"
        }

        return "Check Yandex: \(classification)"
    }

    public var checkClassificationClean: String {
        isRussian ? "состояние чистое" : "clean"
    }

    public var checkClassificationBaselineMissing: String {
        isRussian ? "baseline ещё не создан" : "baseline missing"
    }

    public func checkClassificationRemoteOnly(count: Int) -> String {
        isRussian ? "изменения только на стороне remote: \(count)" : "remote-only drift: \(count)"
    }

    public func checkClassificationLocalOnly(count: Int) -> String {
        isRussian ? "изменения только локально: \(count)" : "local-only drift: \(count)"
    }

    public func checkClassificationConflicts(count: Int) -> String {
        isRussian ? "конфликты: \(count)" : "conflicts: \(count)"
    }

    public func checkWarningDetails(differenceCount: Int?, logDescription: String) -> String {
        let summary: String
        if isRussian {
            if let differenceCount {
                summary = "Проверка Yandex обнаружила различия: \(differenceCount). Посмотрите подробный log ниже; если изменения на стороне remote нужны локально, выполните Pull From Yandex перед следующим Push to Yandex."
            } else {
                summary = "Проверка Yandex обнаружила изменения или drift на стороне remote. Перед следующим Push to Yandex проверьте состояние и при необходимости выполните Pull From Yandex."
            }
        } else if let differenceCount {
            summary = "Check Yandex found \(differenceCount) difference(s). Review the detailed rclone log below; if the remote changes should be brought local, run Pull From Yandex before the next Push to Yandex."
        } else {
            summary = "Check Yandex detected remote changes or drift. Review the state and run Pull From Yandex before the next Push to Yandex if needed."
        }

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

    public var onboardingEnvironmentTitle: String {
        isRussian ? "Состояние окружения" : "Environment status"
    }

    public var onboardingEnvironmentHint: String {
        isRussian
            ? "Здесь видно всё, от чего зависит синхронизация: rclone, remote, пары и плановая синхронизация. Заглядывайте сюда, когда что-то перестало работать."
            : "This is everything syncing depends on: rclone, the remote, your pairs and scheduled sync. Come back here when something stops working."
    }

    public var recheckEnvironmentButtonTitle: String {
        isRussian ? "Проверить окружение" : "Re-check environment"
    }

    public func onboardingLastCheckedAt(_ value: String) -> String {
        "\(onboardingLastCheckStatusLabel): \(value)"
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

    private func stripRcloneLogPrefix(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}\s+[A-Z]+:\s+"#,
            with: "",
            options: .regularExpression
        )
    }
}
