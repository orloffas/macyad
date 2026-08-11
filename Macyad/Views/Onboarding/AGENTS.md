<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Onboarding

## Purpose
SwiftUI-вьюхи раздела «Подключение». Экран живёт двумя жизнями:

1. **Пока окружение не готово** — пошаговый онбординг: установка rclone (brew install), настройка Yandex remote (`rclone config`), создание первой sync-пары. Команды отображаются в копируемых карточках с визуальным подтверждением копирования.
2. **Когда всё настроено** (`step == .complete`) — постоянная панель диагностики окружения: заголовок меняется на «Состояние окружения», показывается чеклист rclone / remote / пары / плановая синхронизация с иконками `checkmark.circle.fill` (зелёная) и `exclamationmark.triangle.fill` (оранжевая).

Второй режим — не «пустой экран после онбординга», а то, куда пользователь возвращается, когда синхронизация сломалась. Не удаляй его и не превращай обратно в одну строчку «Настройка завершена».

## Key Files
| File | Description |
|------|-------------|
| OnboardingView.swift | Основной контейнер; переключает шаги по `OnboardingState.step` из `OnboardingViewModel`; рендерит `CommandCopyRowView` для brew и rclone config команд, чеклист окружения в `.complete`, кнопку «Проверить окружение» с `ProgressView` и временем последней проверки |
| CommandCopyRowView.swift | Переиспользуемый компонент: заголовок + моноширинная команда + кнопка копирования с состоянием (checkmark при copied=true); используется также в `SettingsView` |

## For AI Agents

### Working In This Directory
- Проверка окружения запускается **один раз** — при первом показе раздела (`.task` + `lastCheckedAt == nil`), дальше только по кнопке. Она запускает процесс `rclone version`, и перезапуск при каждом заходе выглядел так, будто приложение само что-то делает, а кнопка «Проверить окружение» ничего не решает.
- Смена числа пар не перезапускает проверку: `OnboardingViewModel.displayStep(pairCount:)` пересчитывает шаг локально, потому что пары ничего не говорят о rclone и remote.
- `CommandCopyRowView` — переиспользуемый компонент; при изменении его интерфейса проверяй также `SettingsView.swift`, где он тоже применяется.
- Шаги онбординга определяются в `Domain/Models/OnboardingState`; добавление нового шага требует изменений и в модели, и во вьюхе.
- **Шаг вычисляет только `OnboardingService.refresh(pairCount:)`.** View не имеет права выводить `.complete` самостоятельно — иначе `AppModel.onboardingState` и `StatusService` разъезжаются с тем, что видит пользователь.
- `refresh()` во View прокидывает `appModel.pairs.count` в сервис и после этого зовёт `applyOnboardingState`. `.task(id: appModel.pairs.count)` перезапускает проверку при создании/удалении пары — без этого чеклист врёт до нажатия кнопки.
- Чеклист собирается в `OnboardingViewModel.statusRows(pairs:preferences:copy:)`, а не во View: там же считается `isSatisfied` для выбора иконки. Состояние планировщика берётся из `AppPreferences.isGlobalSchedulerPaused` + `pair.autoSyncMode`.
- `OnboardingViewModel` управляет `lastCopiedCommand` для визуального feedback копирования — не дублируй эту логику в View.
- `OnboardingView` получает `AppEnvironment` через `@EnvironmentObject` для доступа к сервисам онбординга.
- Все строки — только через `AppCopy` (ru + en). `NSLocalizedString` во вьюхах не использовать.

### Testing Requirements
Логика шагов покрыта `MacyadTests/Domain/OnboardingServiceTests.swift`, чеклист — `MacyadTests/ViewModels/OnboardingViewModelTests.swift`. Запуск: `MACYAD_CODESIGN_IDENTITY="MacYaD Local Development" ./script/test.sh unit`.

Внимание: схема `unit` собирает только `MacyadCore` и **не компилирует вьюхи**. После правок в `Views/` дополнительно собирай app-таргет: `xcodebuild build -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS'`.

Ручное тестирование через `./script/build_and_run.sh` (запуск со сброшенным состоянием онбординга). UI-тесты — `MacyadUITests/` (accessibilityIdentifier: `"onboarding.copyCommand"`, `"onboarding.retry"` — идентификатор кнопки сохранён при переименовании её заголовка).

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
