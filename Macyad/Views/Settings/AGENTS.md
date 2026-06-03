<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Settings

## Purpose
SwiftUI-вьюха настроек приложения, отображаемая в стандартном macOS Settings-окне. Содержит три секции: общие настройки (язык, запуск при логине, расписание по умолчанию), управление уведомлениями (статус разрешения, запрос доступа, тестовое уведомление), управление аккаунтами Yandex (просмотр конфигурации rclone-remote, удаление аккаунта с проверкой зависимых пар).

## Key Files
| File | Description |
|------|-------------|
| SettingsView.swift | Единственный файл каталога; реализует всю Settings UI через `Form` с секциями; использует `CommandCopyRowView` для отображения команды переконфигурации rclone-remote |

## For AI Agents

### Working In This Directory
- Settings-окно открывается через `@Environment(\.openSettings)` из `MainWindowView`; не открывай его через `NSApp` напрямую.
- Удаление аккаунта требует проверки `AccountRemovalState` (нет зависимых пар) — логика в `SettingsViewModel`; View только отображает состояние и подтверждение.
- `CommandCopyRowView` используется здесь для команды `rclone config` — не дублируй его логику инлайн.
- Запрос разрешения уведомлений и тестовое уведомление выполняются через `Task { await viewModel.xxx() }` — не вызывай синхронно.

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh` → меню Settings. Unit-тесты `SettingsViewModel` — `MacyadTests/`.

### Common Patterns
- `@ObservedObject var viewModel: SettingsViewModel` — источник данных и действий.
- `@EnvironmentObject private var appModel: AppModel` — для `copy` и доступа к `appModel.pairs` (проверка зависимостей аккаунта).
- Биндинги (`languageBinding`, `launchAtLoginBinding`, `scheduleBinding`) — computed properties в View, делегирующие в viewModel.
- `Form` + `Section` — стандартная структура macOS Settings.

## Dependencies

### Internal
`ViewModels/SettingsViewModel`, `ViewModels/AppModel`, `Domain/Models/YandexAccount`, `Domain/Models/AccountRemovalState`, `Domain/Models/AppPreferences`; `Views/Onboarding/CommandCopyRowView`

### External
SwiftUI, MacyadCore

<!-- MANUAL: -->
