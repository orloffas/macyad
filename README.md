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
- В приложении одновременно выполняется только одна операция из набора `Push to Yandex`, `Pull from Yandex`, `Check Yandex` и плановой синхронизации. Остальные операции ставятся в очередь.
- Плановая синхронизация задаётся per-pair режимом `Auto-sync`: `Выключена` / `Auto-Push` / `Auto-Pull`. Режимы взаимоисключающие — пара синхронизируется либо вверх, либо вниз.
  - `Auto-Push` — по расписанию выполняется `Push to Yandex` (локальная папка → Yandex).
  - `Auto-Pull` — по расписанию выполняется `Pull From Yandex` (Yandex → локальная папка).
  - Двустороннего режима нет намеренно: `Push` (`rclone sync`) и `Pull` (`rclone copy`) применяются ко всему дереву целиком, поэтому одновременная работа обоих направлений требовала бы per-path движка с разбором конфликтов на каждый файл. Пары `SyncPair.autoSyncMode` достаточно, чтобы это состояние было непредставимо.
- `Push to Yandex` больше не считается “безусловным sync”. Перед push приложение сравнивает текущее состояние с последним согласованным baseline и блокирует опасный overwrite.
- `Conflict policy` на уровне пары:
  - `Block Push/Pull on conflict` — default для новых и legacy pair;
  - `Keep Both Copies` — сохранён как product intent пары, но фактическое решение всё равно принимается через `Review files`.
- Manual `Push/Pull` при drift/conflict ничего не меняют автоматически:
  - создают reviewable `activity event`;
  - в `Activity Detail` появляется кнопка `Review files`;
  - пользователь выбирает `Keep local`, `Keep remote`, `Keep both` или `Later` по строкам, по выбранной группе или сразу по всем видимым строкам.
- Плановая синхронизация всегда non-destructive в обе стороны:
  - не делает auto-reconcile;
  - `Auto-Push` не перетирает remote drift, `Auto-Pull` не перетирает local drift;
  - выполняется только если preflight считает операцию безопасной, иначе пара уходит в `warning` с reviewable списком файлов.
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

## Стабильная локальная подпись (одноразовая настройка)

Без стабильной подписи Xcode подписывает сборку ad-hoc, `CDHash` меняется при каждой пересборке, и `TCC` считает приложение новым — отсюда повторные запросы доступа к папкам после каждого обновления.

Одноразово создайте self-signed codesigning-сертификат и разрешите `codesign` доступ к его ключу:

```bash
CERT_NAME="MacYaD Local Development"
WORK="$(mktemp -d)"

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions=v3_codesign
prompt=no
[req_distinguished_name]
CN=$CERT_NAME
[v3_codesign]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
subjectKeyIdentifier=hash
EOF

openssl req -new -newkey rsa:2048 -nodes -x509 -days 7300 \
  -keyout "$WORK/cert.key" -out "$WORK/cert.crt" -config "$WORK/cert.cnf"
openssl pkcs12 -export -legacy -macalg sha1 \
  -inkey "$WORK/cert.key" -in "$WORK/cert.crt" -name "$CERT_NAME" \
  -out "$WORK/cert.p12" -passout pass:macyad
security import "$WORK/cert.p12" -k ~/Library/Keychains/login.keychain-db \
  -P macyad -A -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$(read -rs -p 'login keychain password: ' p && echo "$p")" \
  ~/Library/Keychains/login.keychain-db
rm -rf "$WORK"
```

После этого `build_and_run.sh` автоматически переподписывает bundle этим сертификатом (identity переопределяется через `MACYAD_CODESIGN_IDENTITY`). Если сертификата нет, script печатает warning и оставляет ad-hoc подпись.

Проверка, что подпись стабильна:

```bash
codesign -dvvv ~/Applications/MacYaD.app 2>&1 | grep -E 'Authority|Signature'
codesign -dr - ~/Applications/MacYaD.app
```

`Authority=MacYaD Local Development` вместо `Signature=adhoc` означает, что designated requirement больше не меняется между сборками и выданные разрешения сохранятся.

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
