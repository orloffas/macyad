<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Activity

## Purpose
SwiftUI-вьюхи журнала операций синхронизации. Отображают историю запусков (runs) и отдельные события (`ActivityEvent`) с их severity, логами и набором проблемных файлов. `IssueReviewSheetView` предоставляет полноэкранный UI ревью файловых конфликтов с фильтрацией, поиском и применением решений (Keep local / Keep remote / Keep both / Later).

## Key Files
| File | Description |
|------|-------------|
| ActivityListView.swift | Список событий синхронизации, сгруппированных в runs с поддержкой коллапса; принимает `[ActivityEvent]` и `Binding<ActivityEvent?>` |
| ActivityDetailView.swift | Детальная панель одного события: severity, логи, кнопка открытия ревью проблем; может автоматически открыть `IssueReviewSheetView` при `initialOpenIssueReview = true` |
| IssueReviewSheetView.swift | Модальный лист ревью файловых проблем (`ActivityIssueSet`): таблица с `VSplitView`, фильтры по типу проблемы, поиск, bulk-выбор, применение решений через `onApply` callback |

## For AI Agents

### Working In This Directory
- `IssueReviewSheetView` открывается как `sheet` из `ActivityDetailView`; не встраивай его в навигационный стек.
- Callback `onApply: (ActivityIssueSet) async -> ActivityReviewApplyResult` выполняется асинхронно — UI блокируется через `isApplying` flag; не вызывай применение синхронно.
- `ActivityDetailView` использует `NSWindow` через `WindowAccessor` для получения `hostWindow` — это единственный допустимый AppKit-доступ в этом каталоге.
- Фильтры `IssueFilter` (conflicts, remoteOnly, localOnly, deleteVsModify, baselineMissing) должны соответствовать реальным типам `ActivityFileIssue`.

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh`. UI-тесты — `MacyadUITests/`. Unit-тесты логики группировки событий в runs — `MacyadTests/` (если есть тесты `ActivityEventRun`).

### Common Patterns
- `@EnvironmentObject private var appModel: AppModel` для доступа к `copy` (локализация).
- `@State private var expandedRunIDs = Set<ActivityEventRun.ID>` — управление коллапсом runs в `ActivityListView`.
- `VSplitView` в `IssueReviewSheetView` делит область на таблицу проблем и панель деталей.
- Severity визуализируется через `Image(systemName:)` + `foregroundStyle` (цвет из `color(for:)`).

## Dependencies

### Internal
`Domain/Models/ActivityEvent`, `ActivityEventRun`, `ActivityIssueSet`, `ActivityFileIssue`, `Severity`; `Domain/Services/ActivityIssueFormatter`; `ViewModels/AppModel`; `PlatformAdapters/WindowAccessor`

### External
SwiftUI, AppKit (NSWindow через WindowAccessor), MacyadCore

<!-- MANUAL: -->
