<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Onboarding

## Purpose
SwiftUI-вьюхи пошагового онбординга новых пользователей. Проводят пользователя через три шага: установка rclone (brew install), настройка Yandex remote (`rclone config`), создание первой sync-пары. Команды отображаются в копируемых карточках с визуальным подтверждением копирования.

## Key Files
| File | Description |
|------|-------------|
| OnboardingView.swift | Основной контейнер онбординга; управляет переключением шагов (`OnboardingState.step`) через `OnboardingViewModel`; рендерит `CommandCopyRowView` для brew и rclone config команд |
| CommandCopyRowView.swift | Переиспользуемый компонент: заголовок + моноширинная команда + кнопка копирования с состоянием (checkmark при copied=true); используется также в `SettingsView` |

## For AI Agents

### Working In This Directory
- `CommandCopyRowView` — переиспользуемый компонент; при изменении его интерфейса проверяй также `SettingsView.swift`, где он тоже применяется.
- Шаги онбординга определяются в `Domain/Models/OnboardingState`; добавление нового шага требует изменений и в модели, и во вьюхе.
- `OnboardingViewModel` управляет `lastCopiedCommand` для визуального feedback копирования — не дублируй эту логику в View.
- `OnboardingView` получает `AppEnvironment` через `@EnvironmentObject` для доступа к сервисам онбординга.

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh` (запуск со сброшенным состоянием онбординга). UI-тесты — `MacyadUITests/` (accessibilityIdentifier: `"onboarding.copyCommand"`).

### Common Patterns
- `@ObservedObject var viewModel: OnboardingViewModel` — источник состояния шагов.
- `@EnvironmentObject private var appModel: AppModel` — для `copy` (локализация).
- Кнопка копирования: `copied ? "checkmark" : "doc.on.doc"` — стандартный паттерн в `CommandCopyRowView`.
- `.background(.regularMaterial, in: RoundedRectangle(...))` — стиль карточки команды.

## Dependencies

### Internal
`ViewModels/OnboardingViewModel`, `Domain/Models/OnboardingState`, `ViewModels/AppModel`

### External
SwiftUI, MacyadCore

<!-- MANUAL: -->
