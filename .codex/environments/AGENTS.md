<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# environments

## Purpose

Environment-конфигурации для Codex CLI в формате TOML. Задают имя окружения и набор actions, доступных агентам в этом репозитории. Единственный текущий action `Run` запускает полный build+launch цикл через `./script/build_and_run.sh`.

## Key Files

| File | Description |
|------|-------------|
| `environment.toml` | Codex environment `macyad`: action `Run` вызывает `./script/build_and_run.sh` |

## For AI Agents

### Working In This Directory

- Не редактировать `environment.toml` без необходимости — это конфигурация Codex CLI, а не продуктовый код.
- При изменении entry-point скрипта в `../../script/` обновить `command` в `environment.toml`.
- `setup.script` в текущей конфигурации пуст — setup-шаги (установка зависимостей и т.п.) при необходимости добавляются сюда.

### Testing Requirements

Конфигурация не требует автоматизированного тестирования.

### Common Patterns

- Формат: TOML `version = 1`.
- Структура: `name`, `[setup]`, `[[actions]]` с полями `name`, `icon`, `command`.
- `command` задаётся как путь относительно корня репозитория.

## Dependencies

### Internal

- `../../script/build_and_run.sh` — target команды action `Run`.
- `../AGENTS.md` (`.codex/AGENTS.md`) — родительские правила.

### External

- Codex CLI — читает и интерпретирует `environment.toml`.

<!-- MANUAL: -->
