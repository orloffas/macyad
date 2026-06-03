<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views

## Purpose
SwiftUI-вьюхи приложения MacYaD, принадлежащие таргету `Macyad` (app). Каталог разбит на пять фичевых подкаталогов. Views обязаны общаться с бизнес-логикой только через ViewModels или `AppModel`; прямые вызовы Infrastructure-слоя (rclone, файловая система, процессы) из Views запрещены. Вся AppKit-интеграция проходит через `PlatformAdapters/`.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| Activity | Журнал операций синхронизации и UI ревью проблемных файлов |
| Onboarding | Пошаговый онбординг: установка rclone и настройка remote |
| Pairs | Список sync-пар, детали пары и создание/редактирование |
| Settings | Настройки приложения: аккаунты Yandex, уведомления, язык, запуск при логине |
| Shell | Основная навигационная оболочка окна и компактный menu bar popover |

## For AI Agents

### Working In This Directory
- Все новые вьюхи пишутся на SwiftUI; AppKit-код инкапсулируется в `PlatformAdapters/` и передаётся в Views через замыкания или `@EnvironmentObject`.
- Не создавай файлы прямо в `Views/` — размещай в нужном фичевом подкаталоге.
- Строки UI берутся из `appModel.copy` (`AppCopy`); не хардкодь пользовательский текст.
- Действия именуются строго: "Push to Yandex", "Pull from Yandex", "Check Yandex".

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh`. Автоматизированные UI-тесты — `MacyadUITests/`. Логика ViewModels покрывается unit-тестами в `MacyadTests/`.

### Common Patterns
- `@EnvironmentObject var appModel: AppModel` — основной источник данных во всех Views.
- `@EnvironmentObject var environment: AppEnvironment` — доступ к окружению (сервисы, зависимости).
- `@ObservedObject var viewModel: XxxViewModel` — для фичевых ViewModel, где требуется.
- Листы (`sheet`) открываются через `@State private var isPresented` в родительской вьюхе.
- Inspector/detail-панели компонуются в `Shell/MainWindowView` через `NavigationSplitView`.

## Dependencies

### Internal
`ViewModels/` (AppModel, PairDetailViewModel, CreatePairViewModel, OnboardingViewModel, SettingsViewModel), `Domain/Models/` (SyncPair, ActivityEvent, ActivityIssueSet, Severity и др.)

### External
SwiftUI, AppKit (только через PlatformAdapters), MacyadCore (framework)

<!-- MANUAL: -->
