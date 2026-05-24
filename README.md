# macyad

Нативное `macOS` приложение `MacYaD` на `Swift` и `SwiftUI` для orchestration поверх `rclone` и sync-pair workflow для Yandex Disk.

## Language Policy

Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, все ответы, внутренняя рабочая коммуникация и проектная документация должны вестись на русском языке.

Устоявшиеся professional terms, product names, команды, пути, code entities и другие технические идентификаторы можно оставлять без перевода, если это нужно для точности.

## Запуск

```bash
./script/build_and_run.sh
```

`build_and_run.sh` складывает build artifacts в `~/Library/Caches/MacYaD/Build`, чтобы запуск не запрашивал доступ к `Documents`, если сам репозиторий лежит внутри `~/Documents`.

## Verification

```bash
xcodegen generate
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
./script/build_and_run.sh --verify
```
