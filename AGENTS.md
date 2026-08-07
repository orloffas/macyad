<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# macyad

## Purpose

Нативное macOS приложение `MacYaD` на `Swift` и `SwiftUI` для orchestration поверх `rclone` и sync-pair workflow для Yandex Disk. Приложение работает как `menu bar` utility + главное окно, выполняет операции `Push to Yandex`, `Pull from Yandex`, `Check Yandex` и scheduled push, защищает remote от опасного overwrite через baseline-aware планировщик и предоставляет reviewable issue UI для конфликтов.

## Key Files

| File | Description |
|------|-------------|
| `README.md` | Обзор продукта, run / verification / reset инструкции, описание текущего продуктового поведения |
| `DESIGN_PRINCIPLES.md` | UI/UX guidelines: posture, layout, density, menu bar, anti-patterns |
| `project.yml` | `xcodegen` спецификация targets (`MacyadCore`, `Macyad`, `MacyadTests`, `MacyadUITests`) и schemes |
| `Macyad.xcodeproj/` | Сгенерированный из `project.yml` Xcode project (не редактировать вручную) |
| `.gitignore` | Игнор-листы для build artifacts, derived data, worktree-каталогов |
| `package.json`, `node_modules/` | Только для dev-only tooling (не часть приложения) |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Macyad/` | Source приложения и core framework (см. `Macyad/AGENTS.md`) |
| `MacyadTests/` | Unit-тесты `MacyadCore` (см. `MacyadTests/AGENTS.md`) |
| `MacyadUITests/` | UI-тесты приложения `Macyad` (см. `MacyadUITests/AGENTS.md`) |
| `docs/` | Документация и историческое planning (см. `docs/AGENTS.md`) |
| `script/` | Build / run / test shell-скрипты (см. `script/AGENTS.md`) |
| `.codex/` | Codex CLI environment-конфигурация для repo (см. `.codex/AGENTS.md`) |
| `src-tauri/` | Legacy Tauri leftover — содержит только `target/` build cache, в коде не используется |

## For AI Agents

### Working In This Directory

- Любой code change оформляется через `git commit` (правило из `## Git Workflow`).
- При изменении `project.yml` обязательно перегенерировать project: `xcodegen generate`.
- Не редактировать содержимое `Macyad.xcodeproj/` руками — это output `xcodegen`.
- Не вносить product copy на английском, если задача не требует именно английский wording (см. `## Language Policy`).
- Documentation, plans, comments, commit-discussion ведутся на русском; commit messages — на английском.

### Testing Requirements

- Полный прогон тестов:
  ```bash
  xcodegen generate
  xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
  ```
- Для запуска вне sandbox или с отдельным `derivedDataPath`: `./script/test.sh unit`.
- UI-фичи проверяются через `./script/build_and_run.sh` и реальное взаимодействие.

### Common Patterns

- Strict layering: `App` → `Views` / `ViewModels` → `Domain` → `Infrastructure` / `PlatformAdapters`.
- `MacyadCore` — framework target с domain-логикой и infrastructure-имплементациями (testable без UI).
- `Macyad` — app target, подтягивает `MacyadCore` и добавляет UI, `PlatformAdapters`, `Resources`.
- Состояние приложения лежит в `~/Library/Application Support/MacYaD/` (детали в `README.md`).

## Dependencies

### External

- `Swift` 6.0, `macOS` deployment target 14.0 (см. `project.yml`).
- `xcodegen` (>=2.38.0) — генерация Xcode project.
- `rclone` — внешний CLI, оркестрируется приложением (не вендорится).

<!-- MANUAL: Сохранённые ниже project rules — обязательные правила репозитория, не перетирать при regen -->

## Language Policy

Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, все ответы, внутренняя рабочая коммуникация и проектная документация должны вестись на русском языке.

Для сохранения точности разрешено не переводить устоявшиеся professional terms и code entities.

Не переводятся названия `API`, `SDK`, `library`, `framework`, `tool`, `service`, `CLI command`, а также имена файлов, переменных, классов, функций, таблиц и другие технические идентификаторы.

Если перевод ухудшает точность или искажает смысл, термин должен оставаться в оригинале.

## Git Workflow

Любые изменения в репозитории должны оформляться через `git commit`.

Нельзя оставлять выполненную работу только в виде незакоммиченных изменений, если задача дошла до состояния готового изменения.

Если задача приводит к нескольким независимым изменениям, их нужно раскладывать по отдельным осмысленным commit.

<!-- ai-memory-project-policy:start -->
## AI-Memory Disabled

- AI-Memory / ctx-memory skill, plugin, MCP, and automatic indexing are disabled system-wide by user request (2026-06-08).
- Do not auto-load, invoke, index with, or require AI-Memory/ctx-memory in Codex, Claude Code, hooks, or project workflows unless the user explicitly re-enables it.
- Do not use Superpowers (`obra/superpowers`, `superpowers@openai-curated`, `superpowers:writing-skills`) unless the user explicitly re-enables it.
<!-- ai-memory-project-policy:end -->
