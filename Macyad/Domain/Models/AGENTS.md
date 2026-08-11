<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Models

## Purpose

Чистые value types слоя Domain: данные без бизнес-логики, без I/O, без побочных эффектов. Каждый тип описывает один концепт предметной области — аккаунт, пару, событие активности, состояние онбординга и т.д. Типы используются во всех вышестоящих слоях (Services, ViewModels, Views) через `MacyadCore` framework.

## Key Files

| File | Description |
|------|-------------|
| `AccountRemovalState.swift` | Результат проверки допустимости удаления аккаунта: флаг `canRemove`, список блокирующих пар и inline-сообщение |
| `ActivityEvent.swift` | Событие журнала активности: severity, pairID, message, опциональный `issueSet` и `routeToken` для навигации из уведомления; `Codable` |
| `ActivityEventRun.swift` | Группировка идентичных `ActivityEvent` в коллапсируемый «run» для отображения в журнале; содержит фабрику `makeRuns(from:)` |
| `ActivityIssueSet.swift` | Набор проблемных файлов одного события: `ActivityFileIssue` (путь, kind, differences, snapshots, решение), перечисления `ActivityFileProblemKind`, `ActivityFileDifference`, `FileResolutionDecision`, `ActivityRouteToken`; `Codable` |
| `AppCopy.swift` | Локализованные строки UI на ru/en; `AppLanguageState` — thread-safe глобальное хранилище текущего языка |
| `AppLanguage.swift` | Enum языка приложения (`english`/`russian`) и `AppLanguageState` — thread-safe синглтон текущего значения |
| `AppPreferences.swift` | Пользовательские настройки: язык, launchAtLogin, интервал по умолчанию; `Codable` |
| `ConflictPolicy.swift` | Enum стратегии конфликта пары: `.block` или `.keepBoth`; `Codable` |
| `NotificationAuthorizationStatus.swift` | Enum статуса разрешения уведомлений: `notDetermined`, `denied`, `authorized`, `provisional`, `ephemeral`, `unknown`; `Codable` |
| `OnboardingState.swift` | Состояние онбординга: текущий шаг (`installRclone` / `configureRemote` / `createFirstPair` / `complete`), путь к rclone, команды CLI |
| `PairConflictBaselineState.swift` | Baseline-снимок пары (local + remote `PairSnapshot`) для baseline-aware сравнения; включает вспомогательные `PairSnapshot` и `PairSnapshotEntry`; `Codable` |
| `Severity.swift` | Comparable enum уровня серьёзности: `healthy` < `info` < `warning` < `alarm`; `Codable` |
| `SyncPair.swift` | Центральная сущность: пара local-folder ↔ Yandex-remote с политиками, расписанием, exclusion-списками и последними датами операций; `Codable` с ручным `init(from:)`/`encode(to:)` ради миграции legacy-ключей (`isAutoPushEnabled` → `autoSyncMode`, `lastScheduledPushAttemptAt` → `lastScheduledSyncAttemptAt`); содержит `DeletePolicy` и хелперы разбора `remotePath` |
| `AutoSyncMode.swift` | `off` / `push` / `pull` — направление плановой синхронизации пары. Один enum вместо двух `Bool`, чтобы состояние «включены оба направления» было непредставимо: двусторонний режим потребовал бы per-path движка |
| `YandexAccount.swift` | Yandex-аккаунт: displayName, remoteName, configPath, флаг managed-remote; `Codable` |

## For AI Agents

### Working In This Directory

- Только pure value types (`struct`, `enum`). Никаких классов с identity semantics, никакого `actor`.
- Без I/O: нельзя импортировать `Foundation` для файловых операций — только для `UUID`, `Date`, `Data`, `URL` как типов.
- `Codable` реализуется вручную (с `CodingKeys`), если нужна обратная совместимость с сохранёнными данными — см. `ActivityEvent` и `SyncPair`.
- `Equatable` и `Sendable` — обязательны для всех публичных типов.
- `Identifiable` — для типов, отображаемых в SwiftUI List (пара, аккаунт, событие, issue).
- Добавление нового поля в `Codable`-тип — через `decodeIfPresent` с дефолтом для совместимости.
- `AppCopy` — единственный тип с нетривиальным computed API; не добавлять в него бизнес-логику.

### Testing Requirements

Тесты в `MacyadTests/Domain/Models/`. Запуск: `./script/test.sh unit`. Каждый `Codable`-тип должен иметь round-trip тест на encode/decode.

### Common Patterns

- Все типы — `public struct` или `public enum`, все члены `public`.
- `Sendable` — через value semantics (нет reference-типов внутри).
- `AppLanguageState` использует `NSLock` вместо `actor` для совместимости с синхронным контекстом.
- `SyncPair.defaultSyncExcludes` — статический список rclone-паттернов для игнора macOS/Windows/VCS artifacts.

## Dependencies

### Internal

`Models/` не зависит от других директорий Domain. `AppCopy` использует `AppLanguageState` (тот же файл).

### External

`Foundation` (UUID, Date, Data, URL, Locale, DateFormatter); `AppKit` — не используется.

<!-- MANUAL: -->
