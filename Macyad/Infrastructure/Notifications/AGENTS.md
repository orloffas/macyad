<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Notifications

## Purpose

Адаптер над `UNUserNotificationCenter`: запрос статуса авторизации, запрос разрешения на уведомления, отправка уведомлений с опциональным `ActivityRouteToken` для навигации к связанному событию. Реализует протоколы `UserNotificationControlling` и `UserNotificationSending`, которые используются в `BackgroundSyncController` и Domain-сервисах.

## Key Files

| File | Description |
|------|-------------|
| `UserNotificationClient.swift` | Реализует `UserNotificationControlling` / `UserNotificationSending`; dependency-injectable через closure-инициализатор для тестов |

## For AI Agents

### Working In This Directory

- Prod-инициализатор `UserNotificationClient()` использует live closures; в тестах передавать кастомные closures через `init(statusProvider:authorizationRequester:sender:)`.
- `ActivityRouteToken` в уведомлении кодируется в `userInfo` для навигации при тапе — не убирать это поле при изменениях.
- `sendTestNotification()` берёт copy из `AppCopy.current` — не хардкодить строки напрямую.
- `NotificationAuthorizationStatus` — Domain-тип; маппинг из `UNAuthorizationStatus` выполняется в статическом методе `map(_:)` внутри клиента.

### Testing Requirements

Прямых тестовых файлов для `UserNotificationClient` нет в `MacyadTests/Infrastructure/` — тестируется через mock `UserNotificationSending` в тестах `BackgroundSyncController`. Запуск см. `../../AGENTS.md`.

### Common Patterns

- `Sendable`-struct с `@Sendable`-closures вместо actor — позволяет передавать клиент через границы concurrency без actor-isolation.
- Все async-методы оборачивают completion-based UNUserNotificationCenter API через `withCheckedContinuation`.

## Dependencies

### Internal

`ActivityRouteToken`, `NotificationAuthorizationStatus`, `AppCopy`

### External

`Foundation`, `UserNotifications`

<!-- MANUAL: -->
