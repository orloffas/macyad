<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# script

## Purpose

Shell-скрипты для сборки, запуска и тестирования MacYaD. Главный entry-point — `build_and_run.sh`, покрывающий полный цикл от clean до launch и DMG-пакетировки. `test.sh` запускает unit- или UI-тесты в изолированном окружении.

## Key Files

| File | Description |
|------|-------------|
| `build_and_run.sh` | Главный entry-point: `xcodegen generate` → `xcodebuild` → stage → launch / package DMG. Modes: `run` (default), `debug` (lldb attach), `logs` (log stream), `telemetry`, `verify`, `package`. Флаги: `--clean`, `--clean-all`, `--no-launch`, `--package-dmg`, `--package-after-build`, `--foreground`, `--background`, `--no-prompt`. Интерактивный prompt по умолчанию при запуске из TTY. |
| `test.sh` | Юнит- и UI-тесты через `xcodebuild test`. Modes: `unit`/`core` → scheme `MacyadCore`; `ui`/`all` → scheme `Macyad`. Изолированный `derivedDataPath` чтобы не конфликтовать с build artifacts. Экспортирует `MACYAD_CODESIGN_IDENTITY`, если сертификат `MacYaD Local Development` есть в keychain: иначе Xcode подписывает ad-hoc, `CDHash` меняется на каждой пересборке и `TCC` заново спрашивает доступ к папкам прямо во время прогона. |

## For AI Agents

### Working In This Directory

- Все скрипты используют `set -euo pipefail`; новые скрипты должны следовать той же практике.
- Build artifacts уходят в `~/Library/Caches/MacYaD/Build` (переменная `MACYAD_BUILD_DIR`) — это намеренно, чтобы избежать запроса доступа к `~/Documents` при расположении репозитория внутри него.
- Test artifacts — в `~/Library/Caches/MacYaD/TestBuild` (переменная `MACYAD_TEST_BUILD_DIR`).
- Staged app bundle размещается в `~/Applications/MacYaD.app` (переменная `MACYAD_STAGED_APP_DIR`).
- Флаги оформлять как явные long options (`--clean`, не `-c`); short aliases допустимы только как backward-compat алиасы.
- Перед вызовом `build_and_run.sh` из CI или неинтерактивного контекста добавлять `--no-prompt`.
- Не редактировать `Macyad.xcodeproj/` напрямую — `xcodegen generate` вызывается внутри скриптов.

### Testing Requirements

Ручное тестирование типичных комбинаций флагов:

```bash
# Базовая сборка без запуска
./script/build_and_run.sh --no-launch --no-prompt

# Сборка с clean и запуском в фоне
./script/build_and_run.sh --clean --background --no-prompt

# Только unit-тесты
./script/test.sh unit

# UI-тесты (запускает и останавливает MacYaD)
./script/test.sh ui
```

### Common Patterns

- `build_and_run.sh` завершает запущенный экземпляр `MacYaD` перед сборкой через `pkill -x MacYaD`.
- `--clean` удаляет только build и test кэши; `--clean-all` дополнительно удаляет staged bundle, `Application Support`, `Saved Application State` и `defaults`.
- `package` mode создаёт DMG в `~/Library/Caches/MacYaD/Build/Package/MacYaD.dmg` через `hdiutil`.
- `verify` mode запускает приложение и проверяет его присутствие в `lsappinfo` (до 10 попыток по 1 секунде).
- `debug` mode запускает приложение и аттачит `lldb` по PID из `lsappinfo`.

## Dependencies

### Internal

- `../project.yml` — `xcodegen` спецификация, из которой генерируется `Macyad.xcodeproj`.
- `../AGENTS.md` — project-wide правила (git workflow, language policy).

### External

- `xcodebuild` — сборка и тестирование (Xcode Command Line Tools).
- `xcodegen` (>=2.38.0) — генерация `Macyad.xcodeproj` из `project.yml`.
- `codesign` — используется косвенно через `xcodebuild`.
- `hdiutil` — создание DMG в режиме `package`.
- `lldb` — отладчик в режиме `debug`.
- `rclone` — внешний CLI, оркестрируемый приложением (не вызывается скриптами напрямую).

<!-- MANUAL: -->
