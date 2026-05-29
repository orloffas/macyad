# macyad

Нативное `macOS` приложение `MacYaD` на `Swift` и `SwiftUI` для orchestration поверх `rclone` и sync-pair workflow для Yandex Disk.

## Language Policy

Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, все ответы, внутренняя рабочая коммуникация и проектная документация должны вестись на русском языке.

Устоявшиеся professional terms, product names, команды, пути, code entities и другие технические идентификаторы можно оставлять без перевода, если это нужно для точности.

## Git Workflow

- Любые изменения в репозитории должны оформляться через `git commit`.
- Готовую работу нельзя оставлять только в виде незакоммиченных изменений.
- Если задача состоит из нескольких независимых частей, их нужно оформлять отдельными осмысленными commit.

## Текущее продуктовое поведение

- Каждая `pair` привязана к конкретному `Yandex account` и конкретному `rclone remote`.
- В приложении одновременно выполняется только одна операция из набора `Push to Yandex`, `Pull from Yandex`, `Check Yandex` и `scheduled Push to Yandex`. Остальные операции ставятся в очередь.
- `Push to Yandex` больше не считается “безусловным sync”. Перед push приложение сравнивает текущее состояние с последним согласованным baseline и блокирует опасный overwrite.
- `Conflict policy` на уровне пары:
  - `Block Push/Pull on conflict` — default для новых и legacy pair;
  - `Keep Both Copies` — сохранён как product intent пары, но фактическое решение всё равно принимается через `Review files`.
- Manual `Push/Pull` при drift/conflict ничего не меняют автоматически:
  - создают reviewable `activity event`;
  - в `Activity Detail` появляется кнопка `Review files`;
  - пользователь выбирает `Keep local`, `Keep remote`, `Keep both` или `Later` по строкам, по выбранной группе или сразу по всем видимым строкам.
- `scheduled Push to Yandex` всегда non-destructive:
  - не делает auto-reconcile;
  - не перетирает remote drift;
  - выполняется только если preflight считает push безопасным.
- `Check Yandex` опирается на baseline-aware сравнение и различает `clean`, `baseline missing`, `remote-only drift`, `local-only drift` и `true conflicts`.
- `Activity` хранится 48 часов. Для `warning` и `alarm` в `Details` сохраняются полные `rclone` logs, а для reviewable конфликтов — структурированный список проблемных файлов с путями, observed differences и выбранными решениями.

## Где лежит app state

Основное состояние приложения находится в `~/Library/Application Support/MacYaD/`:

- `rclone/rclone.conf` — app-managed `rclone` config
- `rclone/filters/` — временные и актуальные `exclude-from` files
- `conflicts/` — baseline snapshot state для pair conflict planner
- `pairs.json` — список sync pair
- `accounts.json` — список подключённых Yandex account
- `preferences.json` — пользовательские настройки
- `activity.json` — журнал событий
- `Workspace/` — локальный workspace приложения, если он используется в текущем сценарии

## Yandex accounts

- Управление account'ами вынесено в `Settings`.
- `Add account` создаёт логическую запись аккаунта внутри MacYaD и резервирует отдельный `remoteName`.
- Одна `pair` всегда относится ровно к одному account.
- Если account уже используется в существующих pair, удалить его нельзя, пока pair не будут перепривязаны или удалены.
- В `Settings` для каждого account показываются:
  - `displayName`
  - `remoteName`
  - `configPath`
  - copyable команды `Reconnect`, `Recreate managed remote` и `Remove remote`

## Notifications

- Системные `macOS notifications` используются только для `warning` и `alarm`.
- Разрешение не запрашивается агрессивно на старте; оно запрашивается явным действием пользователя в `Settings`.
- В `Settings` есть:
  - текущий notification authorization status
  - `Request Permission`
  - `Send Test Notification`
- Click по проблемному notification открывает главное окно, выбирает нужную `pair` и соответствующую `activity`; если у события есть reviewable issue list, из него можно сразу открыть `Review files`.

## Запуск

```bash
./script/build_and_run.sh
```

Без аргументов script работает в interactive-режиме: можно выбрать clean build, clean everywhere, запуск приложения после build и сборку `DMG`. Для неинтерактивного использования доступны `--clean`, `--clean-all`, `--no-launch`, `--package-dmg`, `--package-after-build`, `--foreground` и `--background`.

`build_and_run.sh` складывает build artifacts в `~/Library/Caches/MacYaD/Build`, чтобы запуск не запрашивал доступ к `Documents`, если сам репозиторий лежит внутри `~/Documents`.

## Сброс состояния приложения

Если приложение запускается со старыми параметрами, остановите `MacYaD` и удалите пользовательское состояние:

```bash
pkill -x MacYaD || true
rm -rf "$HOME/Library/Application Support/MacYaD"
defaults delete me.orloff.macyad 2>/dev/null || true
defaults delete com.orloff.macyad 2>/dev/null || true
rm -rf "$HOME/Library/Saved Application State/me.orloff.macyad.savedState"
rm -rf "$HOME/Library/Saved Application State/com.orloff.macyad.savedState"
```

Команда удаляет `pairs.json`, `preferences.json`, `activity.json` и локальный `Workspace` приложения. `com.orloff.macyad` оставлен в списке как legacy bundle identifier для очистки старых запусков.

## Verification

```bash
xcodegen generate
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
./script/build_and_run.sh --verify
```

Если `xcodebuild test` запускается из sandboxed среды и не может подключиться к `testmanagerd`, используйте обычный локальный shell-сеанс вне sandbox либо задайте отдельный `derivedDataPath`, как в `./script/test.sh unit`.
