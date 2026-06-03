<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Pairs

## Purpose
SwiftUI-вьюхи управления sync-парами: список пар в сайдбаре, детальная панель пары с кнопками действий и журналом активности, модальный лист создания/редактирования пары. Детальная вьюха является основным content-area компонентом `MainWindowView` при выборе пары.

## Key Files
| File | Description |
|------|-------------|
| PairListRowView.swift | Строка сайдбара для одной `SyncPair`: имя, remote path, аккаунт, цветовой индикатор severity |
| PairDetailView.swift | Детальная панель пары: метаданные (local folder, remote path, account, schedule), кнопки действий (Push to Yandex, Pull from Yandex, Check Yandex), список активности и inspector для выбранного события |
| CreatePairSheetView.swift | Модальный лист создания и редактирования `SyncPair`: имя, выбор локальной папки через `FolderPickerBridge`, выбор аккаунта, remote subpath, расписание, политика удаления |

## For AI Agents

### Working In This Directory
- `PairDetailView` получает действия через замыкания (`onSyncNow`, `onCheckYandex`, `onPullFromYandex`, `onEditPair`, `onDeletePair`) — логика выполняется в `MainWindowView`; не переноси её в `PairDetailView`.
- `CreatePairSheetView` использует `FolderPickerBridge` (PlatformAdapters) для выбора папки — не вызывай `NSOpenPanel` напрямую из View.
- Кнопка "Push to Yandex" соответствует `onSyncNow`, "Pull from Yandex" — `onPullFromYandex`, "Check Yandex" — `onCheckYandex`. Не переименовывай эти действия.
- `PairDetailView` встраивает `ActivityListView` и открывает `ActivityDetailView` как inspector; не дублируй журнал активности.

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh`. UI-тесты создания пары — `MacyadUITests/`. Unit-тесты `CreatePairViewModel` и `PairDetailViewModel` — `MacyadTests/`.

### Common Patterns
- `@ObservedObject var viewModel: PairDetailViewModel` — состояние деталей пары.
- `@ObservedObject var viewModel: CreatePairViewModel` — состояние формы создания/редактирования.
- `ViewThatFits(in: .horizontal)` в `PairDetailView` для адаптивного header (wide vs narrow).
- `Grid` + `GridRow` для выравнивания пар label/value в метаданных пары.
- `isSaving` flag блокирует кнопку Save во время асинхронного `onSave` callback.

## Dependencies

### Internal
`ViewModels/PairDetailViewModel`, `ViewModels/CreatePairViewModel`, `Domain/Models/SyncPair`, `Domain/Models/ActivityEvent`, `Domain/Models/Severity`, `ViewModels/AppModel`, `PlatformAdapters/FolderPickerBridge`; `Views/Activity/ActivityListView`, `ActivityDetailView`

### External
SwiftUI, MacyadCore

<!-- MANUAL: -->
