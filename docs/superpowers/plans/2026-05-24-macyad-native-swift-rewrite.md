# Macyad Native Swift Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Полностью заменить текущую `Tauri`/`React`/`Rust` реализацию `Macyad` на нативное `macOS` приложение на `Swift`, `SwiftUI` и узких `AppKit` adapters, сохранив core flows onboarding, pair management, `Sync Now` / `Check Yandex` / `Pull From Yandex`, scheduler, `menu bar` helper и обязательные branding/doc-polish исправления.

**Architecture:** Новый runtime строится как `SwiftUI-first` приложение с явным разделением на `Views`, `ViewModels`, `Domain`, `Infrastructure` и `PlatformAdapters`. Состояние и продуктовая логика остаются в `SwiftUI`/`Swift`; `AppKit` живёт только в маленьких bridge-файлах для `NSStatusItem`, `NSWindow`, pasteboard, folder picker и других native capability gaps. Во время перехода новый native app собирается параллельно legacy-дереву; только после прохождения smoke checks legacy `Tauri`/`React` код удаляется.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, Foundation, UserNotifications, ServiceManagement, XCTest, XCUITest, `xcodegen`, `xcodebuild`

---

## Planned File Structure

### Root Tooling

- `project.yml`
  Назначение: декларативный `xcodegen` source of truth для app target, test targets, bundle identifiers и resources
- `script/build_and_run.sh`
  Назначение: единая kill + build + run точка входа через `xcodebuild`
- `.codex/environments/environment.toml`
  Назначение: Run action в Codex app
- `.gitignore`
  Назначение: игнорировать `.build/`, DerivedData-подобные output, `.superpowers/`, Xcode user data

### App Target

- `Macyad/App/MacyadApp.swift`
  Назначение: `@main` entry point, scene composition, environment injection
- `Macyad/App/AppEnvironment.swift`
  Назначение: создание и инъекция repositories, services, adapters и shared model
- `Macyad/App/AppPaths.swift`
  Назначение: canonical `Application Support` layout и file URLs
- `Macyad/App/AppRouter.swift`
  Назначение: route selection между onboarding, overview, pair detail, settings
- `Macyad/App/AppMetadata.swift`
  Назначение: `bundle identifier`, app name, logging subsystem constants

### Views

- `Macyad/Views/Shell/MainWindowView.swift`
- `Macyad/Views/Shell/MenuBarPopoverView.swift`
- `Macyad/Views/Shell/SidebarView.swift`
- `Macyad/Views/Shell/InspectorView.swift`
- `Macyad/Views/Onboarding/OnboardingView.swift`
- `Macyad/Views/Onboarding/CommandCopyRowView.swift`
- `Macyad/Views/Pairs/CreatePairSheetView.swift`
- `Macyad/Views/Pairs/PairDetailView.swift`
- `Macyad/Views/Pairs/PairListRowView.swift`
- `Macyad/Views/Activity/ActivityListView.swift`
- `Macyad/Views/Settings/SettingsView.swift`

### ViewModels / State

- `Macyad/ViewModels/AppModel.swift`
- `Macyad/ViewModels/OnboardingViewModel.swift`
- `Macyad/ViewModels/CreatePairViewModel.swift`
- `Macyad/ViewModels/PairDetailViewModel.swift`
- `Macyad/ViewModels/SettingsViewModel.swift`

### Domain

- `Macyad/Domain/Models/SyncPair.swift`
- `Macyad/Domain/Models/ActivityEvent.swift`
- `Macyad/Domain/Models/AppPreferences.swift`
- `Macyad/Domain/Models/Severity.swift`
- `Macyad/Domain/Models/OnboardingState.swift`
- `Macyad/Domain/Services/OnboardingService.swift`
- `Macyad/Domain/Services/PairService.swift`
- `Macyad/Domain/Services/SyncService.swift`
- `Macyad/Domain/Services/DriftService.swift`
- `Macyad/Domain/Services/SchedulerService.swift`
- `Macyad/Domain/Services/StatusService.swift`
- `Macyad/Domain/Policies/PushEligibilityPolicy.swift`

### Infrastructure

- `Macyad/Infrastructure/Persistence/JSONFileStore.swift`
- `Macyad/Infrastructure/Persistence/PairRepository.swift`
- `Macyad/Infrastructure/Persistence/ActivityRepository.swift`
- `Macyad/Infrastructure/Persistence/AppPreferencesStore.swift`
- `Macyad/Infrastructure/Filesystem/WorkspaceLayoutManager.swift`
- `Macyad/Infrastructure/Process/RcloneLocator.swift`
- `Macyad/Infrastructure/Process/RcloneProcessClient.swift`
- `Macyad/Infrastructure/Process/RcloneCommandBuilder.swift`
- `Macyad/Infrastructure/Process/RcloneOutputParser.swift`
- `Macyad/Infrastructure/Notifications/UserNotificationClient.swift`
- `Macyad/Infrastructure/System/LoginItemService.swift`

### Platform Adapters

- `Macyad/PlatformAdapters/AppDelegateBridge.swift`
- `Macyad/PlatformAdapters/StatusBarBridge.swift`
- `Macyad/PlatformAdapters/WindowAccessor.swift`
- `Macyad/PlatformAdapters/PasteboardBridge.swift`
- `Macyad/PlatformAdapters/FolderPickerBridge.swift`

### Resources

- `Macyad/Resources/Assets.xcassets/AppIcon.appiconset/*`
- `Macyad/Resources/Assets.xcassets/MenuBarTemplate.imageset/*`
- `Macyad/Resources/ru.lproj/Localizable.strings`
- `Macyad/Resources/en.lproj/Localizable.strings`

### Tests

- `MacyadTests/App/AppPathsTests.swift`
- `MacyadTests/Infrastructure/PairRepositoryTests.swift`
- `MacyadTests/Infrastructure/RcloneLocatorTests.swift`
- `MacyadTests/Domain/OnboardingServiceTests.swift`
- `MacyadTests/Domain/PairServiceTests.swift`
- `MacyadTests/Domain/SchedulerServiceTests.swift`
- `MacyadTests/Domain/StatusServiceTests.swift`
- `MacyadTests/ViewModels/OnboardingViewModelTests.swift`
- `MacyadTests/ViewModels/CreatePairViewModelTests.swift`
- `MacyadUITests/OnboardingUITests.swift`
- `MacyadUITests/PairFlowUITests.swift`

---

### Task 1: Подготовить native Xcode workspace, build/run loop и минимальный app shell

**Files:**
- Create: `project.yml`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`
- Modify: `.gitignore`
- Create: `Macyad/App/AppPaths.swift`
- Create: `Macyad/App/AppEnvironment.swift`
- Create: `Macyad/App/MacyadApp.swift`
- Create: `Macyad/App/AppRouter.swift`
- Create: `Macyad/Views/Shell/MainWindowView.swift`
- Create: `MacyadTests/App/AppPathsTests.swift`

- [ ] **Step 1: Проверить prerequisites и включить full Xcode toolchain**

Run:

```bash
xcode-select -p
xcodebuild -version
brew install xcodegen
xcodegen --version
```

Expected:
- `xcode-select -p` указывает на `/Applications/Xcode.app/Contents/Developer`
- `xcodebuild -version` печатает полную версию Xcode
- `xcodegen --version` завершается успешно

Если `xcodebuild -version` падает с сообщением про `CommandLineTools`, сначала переключить developer dir:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

- [ ] **Step 2: Описать проект через `project.yml`, Run script и Codex environment**

```yaml
# project.yml
name: Macyad
options:
  minimumXcodeGenVersion: 2.38.0
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: me.orloff.macyad
    MACOSX_DEPLOYMENT_TARGET: "14.0"
targets:
  Macyad:
    type: application
    platform: macOS
    sources:
      - path: Macyad
    resources:
      - path: Macyad/Resources
    settings:
      base:
        PRODUCT_NAME: Macyad
        INFOPLIST_KEY_CFBundleDisplayName: Macyad
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity
  MacyadTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: MacyadTests
    dependencies:
      - target: Macyad
  MacyadUITests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: MacyadUITests
    dependencies:
      - target: Macyad
```

```bash
#!/usr/bin/env bash
# script/build_and_run.sh
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Macyad"
SCHEME="Macyad"
PROJECT="Macyad.xcodeproj"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/macos"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"me.orloff.macyad\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

```toml
# .codex/environments/environment.toml
version = 1
name = "macyad"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 3: Добавить failing unit test для canonical app paths**

```swift
// MacyadTests/App/AppPathsTests.swift
import XCTest
@testable import Macyad

final class AppPathsTests: XCTestCase {
    func testAppSupportRootEndsWithMacyad() {
        let paths = AppPaths.makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests"))
        XCTAssertEqual(paths.appSupportRoot.lastPathComponent, "MacyadTests")
        XCTAssertEqual(paths.workspaceRoot.lastPathComponent, "Workspace")
        XCTAssertEqual(paths.pairsFile.lastPathComponent, "pairs.json")
    }
}
```

- [ ] **Step 4: Реализовать минимальный app shell и path bootstrap**

```swift
// Macyad/App/AppPaths.swift
import Foundation

struct AppPaths: Sendable {
    let appSupportRoot: URL
    let workspaceRoot: URL
    let pairsFile: URL
    let preferencesFile: URL
    let activityFile: URL

    static func live() throws -> AppPaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Macyad", isDirectory: true)
        return makeForTesting(rootURL: base)
    }

    static func makeForTesting(rootURL: URL) -> AppPaths {
        AppPaths(
            appSupportRoot: rootURL,
            workspaceRoot: rootURL.appendingPathComponent("Workspace", isDirectory: true),
            pairsFile: rootURL.appendingPathComponent("pairs.json"),
            preferencesFile: rootURL.appendingPathComponent("preferences.json"),
            activityFile: rootURL.appendingPathComponent("activity.json")
        )
    }
}
```

```swift
// Macyad/App/AppEnvironment.swift
import Foundation

@MainActor
final class AppEnvironment {
    let paths: AppPaths

    init(paths: AppPaths) {
        self.paths = paths
    }

    static func bootstrap() throws -> AppEnvironment {
        try .init(paths: .live())
    }
}
```

```swift
// Macyad/App/AppRouter.swift
enum AppRoute: Hashable {
    case onboarding
    case overview
}
```

```swift
// Macyad/Views/Shell/MainWindowView.swift
import SwiftUI

struct MainWindowView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "square.grid.2x2")
            }
            .listStyle(.sidebar)
        } detail: {
            ContentUnavailableView("Macyad", systemImage: "externaldrive.badge.icloud")
        }
    }
}
```

```swift
// Macyad/App/MacyadApp.swift
import SwiftUI

@main
struct MacyadApp: App {
    @State private var environment = try! AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup("Macyad") {
            MainWindowView()
        }

        Settings {
            Text("Settings will land in Task 8.")
                .padding()
        }
    }
}
```

- [ ] **Step 5: Сгенерировать проект и убедиться, что test target действительно падает до фикса или проходит после него**

Run:

```bash
xcodegen generate
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/AppPathsTests/testAppSupportRootEndsWithMacyad \
  test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Проверить native build/run loop**

Run:

```bash
chmod +x script/build_and_run.sh
./script/build_and_run.sh --verify
```

Expected:
- `** BUILD SUCCEEDED **`
- `pgrep -x Macyad` завершается успешно

- [ ] **Step 7: Commit**

```bash
git add project.yml script/build_and_run.sh .codex/environments/environment.toml .gitignore Macyad MacyadTests MacyadUITests
git commit -m "feat: scaffold native macOS app shell"
```

### Task 2: Добавить domain models, JSON persistence и workspace layout manager

**Files:**
- Create: `Macyad/Domain/Models/SyncPair.swift`
- Create: `Macyad/Domain/Models/ActivityEvent.swift`
- Create: `Macyad/Domain/Models/AppPreferences.swift`
- Create: `Macyad/Domain/Models/Severity.swift`
- Create: `Macyad/Infrastructure/Persistence/JSONFileStore.swift`
- Create: `Macyad/Infrastructure/Persistence/PairRepository.swift`
- Create: `Macyad/Infrastructure/Persistence/ActivityRepository.swift`
- Create: `Macyad/Infrastructure/Persistence/AppPreferencesStore.swift`
- Create: `Macyad/Infrastructure/Filesystem/WorkspaceLayoutManager.swift`
- Create: `MacyadTests/Infrastructure/PairRepositoryTests.swift`

- [ ] **Step 1: Написать failing tests для pair persistence и workspace layout**

```swift
// MacyadTests/Infrastructure/PairRepositoryTests.swift
import XCTest
@testable import Macyad

final class PairRepositoryTests: XCTestCase {
    func testSaveAndReloadPairsRoundTrips() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let paths = AppPaths.makeForTesting(rootURL: root)
        let repository = PairRepository(store: JSONFileStore(url: paths.pairsFile))

        let pair = SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        try await repository.save([pair])
        let reloaded = try await repository.load()

        XCTAssertEqual(reloaded, [pair])
    }
}
```

- [ ] **Step 2: Запустить тест и подтвердить, что target ещё не знает про models/repository**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/PairRepositoryTests/testSaveAndReloadPairsRoundTrips \
  test
```

Expected: FAIL с ошибками вида `cannot find 'PairRepository' in scope`

- [ ] **Step 3: Реализовать модели и JSON stores минимально, без лишней базы данных**

```swift
// Macyad/Domain/Models/Severity.swift
enum Severity: String, Codable, Sendable {
    case healthy
    case info
    case warning
    case alarm
}
```

```swift
// Macyad/Domain/Models/SyncPair.swift
import Foundation

struct SyncPair: Codable, Equatable, Identifiable, Sendable {
    enum DeletePolicy: String, Codable, Sendable {
        case mirrorToYandex
        case keepRemoteDeletesManual
    }

    let id: UUID
    var name: String
    var localFolderBookmark: Data
    var localFolderDisplayPath: String
    var remotePath: String
    var scheduleMinutes: Int
    var deletePolicy: DeletePolicy
    var lastKnownSeverity: Severity
}
```

```swift
// Macyad/Infrastructure/Persistence/JSONFileStore.swift
import Foundation

actor JSONFileStore<Value: Codable & Sendable> {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) {
        self.url = url
    }

    func load(default defaultValue: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return defaultValue }
        return try decoder.decode(Value.self, from: Data(contentsOf: url))
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
```

```swift
// Macyad/Infrastructure/Persistence/PairRepository.swift
actor PairRepository {
    private let store: JSONFileStore<[SyncPair]>

    init(store: JSONFileStore<[SyncPair]>) {
        self.store = store
    }

    func load() throws -> [SyncPair] {
        try store.load(default: [])
    }

    func save(_ pairs: [SyncPair]) throws {
        try store.save(pairs)
    }
}
```

```swift
// Macyad/Infrastructure/Persistence/ActivityRepository.swift
actor ActivityRepository {
    private let store: JSONFileStore<[ActivityEvent]>

    init(store: JSONFileStore<[ActivityEvent]>) {
        self.store = store
    }

    func load() throws -> [ActivityEvent] {
        try store.load(default: [])
    }

    func save(_ events: [ActivityEvent]) throws {
        try store.save(events)
    }
}
```

```swift
// Macyad/Infrastructure/Persistence/AppPreferencesStore.swift
actor AppPreferencesStore {
    private let store: JSONFileStore<AppPreferences>

    init(store: JSONFileStore<AppPreferences>) {
        self.store = store
    }

    func load() throws -> AppPreferences {
        try store.load(default: .defaults)
    }

    func save(_ preferences: AppPreferences) throws {
        try store.save(preferences)
    }
}
```

```swift
// Macyad/Infrastructure/Filesystem/WorkspaceLayoutManager.swift
import Foundation

struct WorkspaceLayoutManager {
    let paths: AppPaths

    func ensureLayout() throws {
        try FileManager.default.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.workspaceRoot, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 4: Прогнать tests и убедиться, что JSON persistence работает**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/PairRepositoryTests \
  test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Macyad/Domain Macyad/Infrastructure MacyadTests/Infrastructure
git commit -m "feat: add native persistence and workspace layout"
```

### Task 3: Реализовать `rclone` discovery, command builder и onboarding domain

**Files:**
- Create: `Macyad/Domain/Models/OnboardingState.swift`
- Create: `Macyad/Infrastructure/Process/RcloneLocator.swift`
- Create: `Macyad/Infrastructure/Process/RcloneCommandBuilder.swift`
- Create: `Macyad/Infrastructure/Process/RcloneProcessClient.swift`
- Create: `Macyad/Infrastructure/Process/RcloneOutputParser.swift`
- Create: `Macyad/Domain/Services/OnboardingService.swift`
- Create: `MacyadTests/Infrastructure/RcloneLocatorTests.swift`
- Create: `MacyadTests/Domain/OnboardingServiceTests.swift`

- [ ] **Step 1: Написать failing tests для missing `rclone` и detected `rclone`**

```swift
// MacyadTests/Domain/OnboardingServiceTests.swift
import XCTest
@testable import Macyad

final class OnboardingServiceTests: XCTestCase {
    private struct StubRcloneLocator: RcloneLocating {
        let location: String?
        func locate() async throws -> String? { location }
    }

    func testMissingRcloneProducesInstallStep() async throws {
        let locator = StubRcloneLocator(location: nil)
        let service = OnboardingService(locator: locator, paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests")))

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .installRclone)
        XCTAssertEqual(state.brewInstallCommand, "brew install rclone")
    }

    func testDetectedRcloneProducesRemoteSetupStep() async throws {
        let locator = StubRcloneLocator(location: "/opt/homebrew/bin/rclone")
        let service = OnboardingService(locator: locator, paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests")))

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .configureRemote)
        XCTAssertTrue(state.remoteCreateCommand.contains("rclone config create"))
    }
}
```

- [ ] **Step 2: Запустить test target и зафиксировать ожидаемый red state**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/OnboardingServiceTests \
  test
```

Expected: FAIL с `cannot find 'OnboardingService' in scope`

- [ ] **Step 3: Реализовать discovery и onboarding state как typed domain, а не как raw shell strings в UI**

```swift
// Macyad/Domain/Models/OnboardingState.swift
struct OnboardingState: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case installRclone
        case configureRemote
        case createFirstPair
        case complete
    }

    var step: Step
    var rcloneLocation: String?
    var brewInstallCommand: String
    var remoteCreateCommand: String
}
```

```swift
// Macyad/Infrastructure/Process/RcloneLocator.swift
import Foundation

protocol RcloneLocating: Sendable {
    func locate() async throws -> String?
}

struct RcloneLocator: RcloneLocating {
    func locate() async throws -> String? {
        let candidates = ["/opt/homebrew/bin/rclone", "/usr/local/bin/rclone", "/usr/bin/rclone"]
        if let hit = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            return hit
        }
        return nil
    }
}
```

```swift
// Macyad/Infrastructure/Process/RcloneCommandBuilder.swift
struct RcloneCommandBuilder {
    static func remoteCreateCommand(configPath: String, remoteName: String) -> String {
        "rclone config create \(remoteName) yandex --config \(configPath)"
    }
}
```

```swift
// Macyad/Infrastructure/Process/RcloneProcessClient.swift
import Foundation

protocol RcloneProcessRunning: Sendable {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32)
}

struct RcloneProcessClient: RcloneProcessRunning {
    let executablePath: String

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (stdout, stderr, process.terminationStatus)
    }
}
```

```swift
// Macyad/Infrastructure/Process/RcloneOutputParser.swift
struct RcloneOutputParser {
    static func containsRemoteChanges(_ stdout: String) -> Bool {
        stdout.contains("NOTICE") || stdout.contains("Transferred:")
    }
}
```

```swift
// Macyad/Domain/Services/OnboardingService.swift
protocol OnboardingServicing: Sendable {
    func refresh() async throws -> OnboardingState
}

struct OnboardingService: OnboardingServicing {
    let locator: RcloneLocating
    let paths: AppPaths

    func refresh() async throws -> OnboardingState {
        let location = try await locator.locate()
        return OnboardingState(
            step: location == nil ? .installRclone : .configureRemote,
            rcloneLocation: location,
            brewInstallCommand: "brew install rclone",
            remoteCreateCommand: RcloneCommandBuilder.remoteCreateCommand(
                configPath: paths.appSupportRoot.appendingPathComponent("rclone.conf").path,
                remoteName: "yd-app"
            )
        )
    }
}
```

- [ ] **Step 4: Перезапустить tests**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/OnboardingServiceTests \
  test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Macyad/Domain/Models/OnboardingState.swift Macyad/Infrastructure/Process Macyad/Domain/Services/OnboardingService.swift MacyadTests/Domain MacyadTests/Infrastructure
git commit -m "feat: add native rclone onboarding domain"
```

### Task 4: Собрать `SwiftUI-first` app shell и узкий `AppKit` bridge для окна и status bar

**Files:**
- Create: `Macyad/ViewModels/AppModel.swift`
- Create: `Macyad/Domain/Services/StatusService.swift`
- Create: `Macyad/PlatformAdapters/AppDelegateBridge.swift`
- Create: `Macyad/PlatformAdapters/StatusBarBridge.swift`
- Create: `Macyad/PlatformAdapters/WindowAccessor.swift`
- Modify: `Macyad/App/MacyadApp.swift`
- Modify: `Macyad/App/AppEnvironment.swift`
- Modify: `Macyad/App/AppRouter.swift`
- Modify: `Macyad/Views/Shell/MainWindowView.swift`
- Create: `Macyad/Views/Shell/MenuBarPopoverView.swift`
- Create: `MacyadTests/Domain/StatusServiceTests.swift`

- [ ] **Step 1: Написать failing test для menu bar summary и `setup required`**

```swift
// MacyadTests/Domain/StatusServiceTests.swift
import XCTest
@testable import Macyad

final class StatusServiceTests: XCTestCase {
    func testSetupRequiredWhenOnboardingNotComplete() {
        let service = StatusService()
        let summary = service.makeSummary(onboardingStep: .installRclone, pairs: [])

        XCTAssertEqual(summary.title, "Setup required")
        XCTAssertEqual(summary.alarmCount, 0)
    }
}
```

- [ ] **Step 2: Реализовать app model и status summary как Swift-side source of truth**

```swift
// Macyad/ViewModels/AppModel.swift
import Observation

@Observable
final class AppModel {
    var route: AppRoute = .onboarding
    var isCreatePairSheetPresented = false
    var isInspectorVisible = true
    var selectedPairID: UUID?
    var onboardingState = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: ""
    )
    var pairs: [SyncPair] = []
    var statusSummary = MenuBarSummary(title: "Setup required", alarmCount: 0, warningCount: 0)
    var openMainWindow: () -> Void = {}
    var runSyncNowForSelectedPair: () -> Void = {}
    var runCheckForSelectedPair: () -> Void = {}
    var runPullForSelectedPair: () -> Void = {}

    var selectedPair: SyncPair? {
        pairs.first { $0.id == selectedPairID }
    }
}

struct MenuBarSummary: Equatable {
    var title: String
    var alarmCount: Int
    var warningCount: Int
}
```

```swift
// Macyad/Domain/Services/StatusService.swift
struct StatusService {
    func makeSummary(onboardingStep: OnboardingState.Step, pairs: [SyncPair]) -> MenuBarSummary {
        guard onboardingStep == .complete else {
            return MenuBarSummary(title: "Setup required", alarmCount: 0, warningCount: 0)
        }
        let alarms = pairs.filter { $0.lastKnownSeverity == .alarm }.count
        let warnings = pairs.filter { $0.lastKnownSeverity == .warning }.count
        return MenuBarSummary(title: alarms > 0 ? "Attention required" : "Ready", alarmCount: alarms, warningCount: warnings)
    }
}
```

- [ ] **Step 3: Добавить narrow AppKit bridge для status item и close-window-without-quit**

```swift
// Macyad/PlatformAdapters/AppDelegateBridge.swift
import AppKit

final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
```

```swift
// Macyad/PlatformAdapters/StatusBarBridge.swift
import AppKit
import SwiftUI

@MainActor
final class StatusBarBridge {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init<Content: View>(@ViewBuilder content: () -> Content) {
        item.button?.image = NSImage(systemSymbolName: "externaldrive.badge.icloud", accessibilityDescription: "Macyad")
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        popover.contentViewController = NSHostingController(rootView: content())
        popover.behavior = .transient
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

```swift
// Macyad/PlatformAdapters/WindowAccessor.swift
import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window { onResolve(window) }
        }
    }
}
```

- [ ] **Step 4: Подключить bridge в app entry point, не давая `AppKit` расползтись в UI**

```swift
// Macyad/App/MacyadApp.swift
import AppKit
import SwiftUI

@main
struct MacyadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate
    @State private var environment = try! AppEnvironment.bootstrap()
    @State private var appModel = AppModel()
    @State private var statusBarBridge: StatusBarBridge?

    var body: some Scene {
        WindowGroup("Macyad") {
            MainWindowView()
                .environment(appModel)
                .background(WindowAccessor { window in
                    window.delegate = appDelegate
                })
                .onAppear {
                    appModel.openMainWindow = {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }

                    if statusBarBridge == nil {
                        statusBarBridge = StatusBarBridge {
                            MenuBarPopoverView()
                                .environment(appModel)
                        }
                    }
                }
        }

        Settings {
            Text("Settings will be implemented in Task 8.")
        }
    }
}
```

```swift
// Macyad/Views/Shell/MenuBarPopoverView.swift
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.statusSummary.title)
                .font(.headline)
            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
```

- [ ] **Step 5: Прогнать tests и smoke verification окна**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/StatusServiceTests \
  test
./script/build_and_run.sh --verify
```

Expected:
- `** TEST SUCCEEDED **`
- app process остаётся живым после ручного закрытия окна в UI

- [ ] **Step 6: Commit**

```bash
git add Macyad/App Macyad/ViewModels/AppModel.swift Macyad/PlatformAdapters Macyad/Views/Shell Macyad/Domain/Services/StatusService.swift MacyadTests/Domain/StatusServiceTests.swift
git commit -m "feat: add native shell and appkit bridges"
```

### Task 5: Реализовать onboarding UI, copy affordance и `Проверить снова`

**Files:**
- Create: `Macyad/ViewModels/OnboardingViewModel.swift`
- Create: `Macyad/Views/Onboarding/OnboardingView.swift`
- Create: `Macyad/Views/Onboarding/CommandCopyRowView.swift`
- Create: `Macyad/PlatformAdapters/PasteboardBridge.swift`
- Create: `Macyad/Resources/ru.lproj/Localizable.strings`
- Create: `Macyad/Resources/en.lproj/Localizable.strings`
- Create: `MacyadTests/ViewModels/OnboardingViewModelTests.swift`

- [ ] **Step 1: Написать failing tests для retry и copy feedback**

```swift
// MacyadTests/ViewModels/OnboardingViewModelTests.swift
import XCTest
@testable import Macyad

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private struct StubOnboardingService: OnboardingServicing {
        let step: OnboardingState.Step

        func refresh() async throws -> OnboardingState {
            OnboardingState(
                step: step,
                rcloneLocation: step == .installRclone ? nil : "/opt/homebrew/bin/rclone",
                brewInstallCommand: "brew install rclone",
                remoteCreateCommand: "rclone config create yd-app yandex --config /tmp/rclone.conf"
            )
        }
    }

    func testRetryRefreshesState() async throws {
        let service = StubOnboardingService(step: .configureRemote)
        let model = OnboardingViewModel(service: service)

        await model.retry()

        XCTAssertEqual(model.state.step, .configureRemote)
    }

    func testCopyMarksCommandAsCopied() async throws {
        let model = OnboardingViewModel(service: StubOnboardingService(step: .installRclone))

        model.copy("brew install rclone")

        XCTAssertEqual(model.lastCopiedCommand, "brew install rclone")
    }
}
```

- [ ] **Step 2: Реализовать view model и pasteboard bridge**

```swift
// Macyad/PlatformAdapters/PasteboardBridge.swift
import AppKit

protocol PasteboardWriting {
    func copy(_ string: String)
}

struct PasteboardBridge: PasteboardWriting {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
```

```swift
// Macyad/ViewModels/OnboardingViewModel.swift
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    private let service: OnboardingServicing
    private let pasteboard: PasteboardWriting

    var state = OnboardingState(step: .installRclone, rcloneLocation: nil, brewInstallCommand: "brew install rclone", remoteCreateCommand: "")
    var isRefreshing = false
    var lastCopiedCommand: String?

    init(service: OnboardingServicing, pasteboard: PasteboardWriting = PasteboardBridge()) {
        self.service = service
        self.pasteboard = pasteboard
    }

    func retry() async {
        isRefreshing = true
        defer { isRefreshing = false }
        state = (try? await service.refresh()) ?? state
    }

    func copy(_ command: String) {
        pasteboard.copy(command)
        lastCopiedCommand = command
    }
}
```

- [ ] **Step 3: Реализовать compact onboarding UI и подключить его в main window**

```swift
// Macyad/Views/Onboarding/CommandCopyRowView.swift
import SwiftUI

struct CommandCopyRowView: View {
    let title: String
    let command: String
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            Spacer()
            Button(copied ? "Copied" : "Copy", action: onCopy)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
```

```swift
// Macyad/Views/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Onboarding")
                .font(.largeTitle)

            if viewModel.state.step == .installRclone {
                CommandCopyRowView(
                    title: "Install rclone",
                    command: viewModel.state.brewInstallCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.brewInstallCommand
                ) {
                    viewModel.copy(viewModel.state.brewInstallCommand)
                }
            }

            Button("Проверить снова") {
                Task { await viewModel.retry() }
            }
        }
        .padding()
    }
}
```

- [ ] **Step 4: Прогнать tests и вручную проверить `Copy` + `Проверить снова`**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/OnboardingViewModelTests \
  test
./script/build_and_run.sh
```

Expected:
- `** TEST SUCCEEDED **`
- в UI есть copy-кнопка и кнопка `Проверить снова`
- после copy button label меняется на `Copied`

- [ ] **Step 5: Commit**

```bash
git add Macyad/ViewModels/OnboardingViewModel.swift Macyad/Views/Onboarding Macyad/PlatformAdapters/PasteboardBridge.swift Macyad/Resources MacyadTests/ViewModels/OnboardingViewModelTests.swift
git commit -m "feat: add native onboarding flow"
```

### Task 6: Реализовать создание `pair`, sidebar navigation и detail view

**Files:**
- Create: `Macyad/Domain/Services/PairService.swift`
- Create: `Macyad/ViewModels/CreatePairViewModel.swift`
- Create: `Macyad/Views/Pairs/CreatePairSheetView.swift`
- Create: `Macyad/Views/Pairs/PairListRowView.swift`
- Create: `Macyad/Views/Pairs/PairDetailView.swift`
- Create: `Macyad/PlatformAdapters/FolderPickerBridge.swift`
- Create: `MacyadTests/Domain/PairServiceTests.swift`
- Create: `MacyadTests/ViewModels/CreatePairViewModelTests.swift`
- Modify: `Macyad/Views/Shell/MainWindowView.swift`

- [ ] **Step 1: Написать failing validation tests для pair creation**

```swift
// MacyadTests/Domain/PairServiceTests.swift
import XCTest
@testable import Macyad

final class PairServiceTests: XCTestCase {
    func testCreateRejectsEmptyRemotePath() throws {
        let service = PairService()

        XCTAssertThrowsError(
            try service.makePair(
                name: "Work Docs",
                localFolderBookmark: Data(),
                localFolderDisplayPath: "/Users/test/Work Docs",
                remotePath: "",
                scheduleMinutes: 30,
                deletePolicy: .mirrorToYandex
            )
        )
    }
}
```

- [ ] **Step 2: Реализовать service, folder picker bridge и create view model**

```swift
// Macyad/Domain/Services/PairService.swift
import Foundation

struct PairService {
    enum ValidationError: Error {
        case emptyName
        case emptyRemotePath
        case invalidSchedule
    }

    func makePair(
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int,
        deletePolicy: SyncPair.DeletePolicy
    ) throws -> SyncPair {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError.emptyName }
        guard !remotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError.emptyRemotePath }
        guard scheduleMinutes > 0 else { throw ValidationError.invalidSchedule }

        return SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath,
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy,
            lastKnownSeverity: .healthy
        )
    }
}
```

```swift
// MacyadTests/ViewModels/CreatePairViewModelTests.swift
import XCTest
@testable import Macyad

@MainActor
final class CreatePairViewModelTests: XCTestCase {
    private struct StubFolderPicker: FolderPicking {
        func pickFolder() -> (bookmark: Data, displayPath: String)? {
            (Data("bookmark".utf8), "/Users/test/Work Docs")
        }
    }

    func testChooseFolderFillsDisplayPath() {
        let model = CreatePairViewModel(folderPicker: StubFolderPicker(), pairService: PairService())
        model.chooseFolder()
        XCTAssertEqual(model.localFolderDisplayPath, "/Users/test/Work Docs")
    }
}
```

```swift
// Macyad/PlatformAdapters/FolderPickerBridge.swift
import AppKit

protocol FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)?
}

struct FolderPickerBridge: FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let bookmark = try? url.bookmarkData()
        return bookmark.map { ($0, url.path) }
    }
}
```

```swift
// Macyad/ViewModels/CreatePairViewModel.swift
import Observation

@Observable
@MainActor
final class CreatePairViewModel {
    var name = ""
    var localFolderBookmark = Data()
    var localFolderDisplayPath: String?
    var remotePath = "yd:/"
    var scheduleMinutes = 30
    var deletePolicy: SyncPair.DeletePolicy = .mirrorToYandex

    private let folderPicker: FolderPicking
    private let pairService: PairService

    init(folderPicker: FolderPicking = FolderPickerBridge(), pairService: PairService) {
        self.folderPicker = folderPicker
        self.pairService = pairService
    }

    func chooseFolder() {
        guard let result = folderPicker.pickFolder() else { return }
        localFolderBookmark = result.bookmark
        localFolderDisplayPath = result.displayPath
    }

    func buildPair() throws -> SyncPair {
        try pairService.makePair(
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath ?? "",
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy
        )
    }
}
```

- [ ] **Step 3: Собрать desktop-first pair creation flow и detail layout**

```swift
// Macyad/Views/Pairs/CreatePairSheetView.swift
import SwiftUI

struct CreatePairSheetView: View {
    @Bindable var viewModel: CreatePairViewModel

    var body: some View {
        Form {
            TextField("Pair name", text: $viewModel.name)
            HStack {
                Text(viewModel.localFolderDisplayPath ?? "No folder selected")
                Spacer()
                Button("Choose Folder") { viewModel.chooseFolder() }
            }
            TextField("Remote path", text: $viewModel.remotePath)
            Stepper("Schedule: \(viewModel.scheduleMinutes) min", value: $viewModel.scheduleMinutes, in: 5...240, step: 5)
            Picker("Delete policy", selection: $viewModel.deletePolicy) {
                Text("Mirror to Yandex").tag(SyncPair.DeletePolicy.mirrorToYandex)
                Text("Keep remote deletes manual").tag(SyncPair.DeletePolicy.keepRemoteDeletesManual)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding()
    }
}
```

```swift
// Macyad/Views/Shell/MainWindowView.swift
import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationSplitView {
            List(selection: $appModel.selectedPairID) {
                Section("Pairs") {
                    ForEach(appModel.pairs) { pair in
                        PairListRowView(pair: pair)
                            .tag(pair.id)
                    }
                }
            }
            .toolbar {
                Button("New Pair") { appModel.isCreatePairSheetPresented = true }
            }
        } detail: {
            PairDetailView(pair: appModel.selectedPair)
        }
    }
}
```

- [ ] **Step 4: Прогнать tests и сделать ручной smoke check pair creation**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/PairServiceTests \
  test
./script/build_and_run.sh
```

Expected:
- `** TEST SUCCEEDED **`
- в окне есть `New Pair`
- sheet позволяет выбрать папку и сохранить pair

- [ ] **Step 5: Commit**

```bash
git add Macyad/Domain/Services/PairService.swift Macyad/ViewModels/CreatePairViewModel.swift Macyad/Views/Pairs Macyad/PlatformAdapters/FolderPickerBridge.swift Macyad/Views/Shell/MainWindowView.swift MacyadTests/Domain/PairServiceTests.swift MacyadTests/ViewModels/CreatePairViewModelTests.swift
git commit -m "feat: add pair creation and detail flow"
```

### Task 7: Реализовать `Sync Now`, `Check Yandex`, `Pull From Yandex`, scheduler и activity feed

**Files:**
- Create: `Macyad/Domain/Policies/PushEligibilityPolicy.swift`
- Create: `Macyad/Domain/Services/SyncService.swift`
- Create: `Macyad/Domain/Services/DriftService.swift`
- Create: `Macyad/Domain/Services/SchedulerService.swift`
- Create: `Macyad/Infrastructure/Notifications/UserNotificationClient.swift`
- Create: `Macyad/ViewModels/PairDetailViewModel.swift`
- Create: `Macyad/Views/Activity/ActivityListView.swift`
- Modify: `Macyad/Views/Pairs/PairDetailView.swift`
- Modify: `Macyad/Views/Shell/MenuBarPopoverView.swift`
- Create: `MacyadTests/Domain/SchedulerServiceTests.swift`

- [ ] **Step 1: Написать failing tests для `stop-on-alarm` policy**

```swift
// MacyadTests/Domain/SchedulerServiceTests.swift
import XCTest
@testable import Macyad

final class SchedulerServiceTests: XCTestCase {
    func testAlarmBlocksScheduledPush() {
        let policy = PushEligibilityPolicy()
        let pair = SyncPair(
            id: UUID(),
            name: "Blocked Pair",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/Blocked",
            remotePath: "yd:/Blocked",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .alarm
        )

        XCTAssertFalse(policy.canRunScheduledPush(for: pair))
    }
}
```

- [ ] **Step 2: Реализовать policy, process-based sync service и scheduler actor**

```swift
// Macyad/Domain/Policies/PushEligibilityPolicy.swift
struct PushEligibilityPolicy {
    func canRunScheduledPush(for pair: SyncPair) -> Bool {
        pair.lastKnownSeverity != .alarm
    }
}
```

```swift
// Macyad/Domain/Services/SyncService.swift
struct SyncService {
    let processClient: RcloneProcessRunning

    func push(_ pair: SyncPair) async throws {
        _ = try await processClient.run(["sync", pair.localFolderDisplayPath, pair.remotePath])
    }

    func check(_ pair: SyncPair) async throws -> Severity {
        let result = try await processClient.run(["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"])
        return RcloneOutputParser.containsRemoteChanges(result.stdout) ? .warning : .healthy
    }

    func pull(_ pair: SyncPair) async throws {
        _ = try await processClient.run(["copy", pair.remotePath, pair.localFolderDisplayPath])
    }
}
```

```swift
// Macyad/Infrastructure/Notifications/UserNotificationClient.swift
import UserNotifications

struct UserNotificationClient {
    func send(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }
}
```

```swift
// Macyad/ViewModels/PairDetailViewModel.swift
import Observation

@Observable
@MainActor
final class PairDetailViewModel {
    var latestSeverity: Severity = .healthy
    var events: [ActivityEvent] = []
    private let syncService: SyncService

    init(syncService: SyncService) {
        self.syncService = syncService
    }
}
```

```swift
// Macyad/Domain/Services/SchedulerService.swift
import Foundation

actor SchedulerService {
    private var task: Task<Void, Never>?
    private let policy: PushEligibilityPolicy
    private let syncService: SyncService

    init(policy: PushEligibilityPolicy, syncService: SyncService) {
        self.policy = policy
        self.syncService = syncService
    }

    func start(with pairsProvider: @escaping @Sendable () async -> [SyncPair]) {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                for pair in await pairsProvider() where policy.canRunScheduledPush(for: pair) {
                    try? await syncService.push(pair)
                }
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}
```

```swift
// Macyad/Views/Pairs/PairDetailView.swift
import SwiftUI

struct PairDetailView: View {
    let pair: SyncPair?
    var onSyncNow: (() -> Void)? = nil
    var onCheckYandex: (() -> Void)? = nil
    var onPullFromYandex: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pair?.name ?? "No Pair Selected")
                .font(.title2)
            HStack {
                Button("Sync Now") { onSyncNow?() }
                Button("Check Yandex") { onCheckYandex?() }
                Button("Pull From Yandex") { onPullFromYandex?() }
            }
            ActivityListView()
        }
        .padding()
    }
}
```

- [ ] **Step 3: Подключить quick actions и menu bar summary к real operations**

```swift
// Macyad/Views/Shell/MenuBarPopoverView.swift
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.statusSummary.title)
                .font(.headline)
            Button("Open Main Window") { appModel.openMainWindow() }
            Divider()
            Button("Sync Now") { appModel.runSyncNowForSelectedPair() }
            Button("Check Yandex") { appModel.runCheckForSelectedPair() }
            Button("Pull From Yandex") { appModel.runPullForSelectedPair() }
        }
        .padding()
        .frame(width: 320)
    }
}
```

- [ ] **Step 4: Прогнать tests и smoke-верификацию scheduler/activity**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  -only-testing:MacyadTests/SchedulerServiceTests \
  test
./script/build_and_run.sh --telemetry
```

Expected:
- `** TEST SUCCEEDED **`
- при запуске действий в UI в unified log появляются события с subsystem `me.orloff.macyad`

- [ ] **Step 5: Commit**

```bash
git add Macyad/Domain/Policies Macyad/Domain/Services/SyncService.swift Macyad/Domain/Services/DriftService.swift Macyad/Domain/Services/SchedulerService.swift Macyad/Infrastructure/Notifications Macyad/ViewModels/PairDetailViewModel.swift Macyad/Views/Activity Macyad/Views/Pairs/PairDetailView.swift Macyad/Views/Shell/MenuBarPopoverView.swift MacyadTests/Domain/SchedulerServiceTests.swift
git commit -m "feat: add sync actions and scheduler"
```

### Task 8: Добавить settings, launch-at-login, локализацию и UI automation для high-value flows

**Files:**
- Create: `Macyad/ViewModels/SettingsViewModel.swift`
- Create: `Macyad/Views/Settings/SettingsView.swift`
- Create: `Macyad/Infrastructure/System/LoginItemService.swift`
- Modify: `Macyad/Resources/ru.lproj/Localizable.strings`
- Modify: `Macyad/Resources/en.lproj/Localizable.strings`
- Create: `MacyadUITests/OnboardingUITests.swift`
- Create: `MacyadUITests/PairFlowUITests.swift`

- [ ] **Step 1: Написать failing UI automation tests для onboarding и pair flow**

```swift
// MacyadUITests/OnboardingUITests.swift
import XCTest

final class OnboardingUITests: XCTestCase {
    func testMissingRcloneShowsRetryAndCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_ONBOARDING_MISSING_RCLONE"]
        app.launch()

        XCTAssertTrue(app.buttons["Проверить снова"].exists)
        XCTAssertTrue(app.buttons["Copy"].exists)
    }
}
```

```swift
// MacyadUITests/PairFlowUITests.swift
import XCTest

final class PairFlowUITests: XCTestCase {
    func testCreatePairButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_READY_STATE"]
        app.launch()

        XCTAssertTrue(app.buttons["New Pair"].exists)
    }
}
```

- [ ] **Step 2: Реализовать settings model и login item service**

```swift
// Macyad/Infrastructure/System/LoginItemService.swift
import ServiceManagement

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
}

struct LoginItemService: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

```swift
// Macyad/ViewModels/SettingsViewModel.swift
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedLanguage = "ru"
    var launchAtLogin = false
    var defaultScheduleMinutes = 30

    private let loginItemService: LoginItemControlling

    init(loginItemService: LoginItemControlling = LoginItemService()) {
        self.loginItemService = loginItemService
    }

    func updateLaunchAtLogin() throws {
        try loginItemService.setEnabled(launchAtLogin)
    }
}
```

- [ ] **Step 3: Реализовать native Settings view и локализованные строки**

```swift
// Macyad/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("Language", selection: $viewModel.selectedLanguage) {
                Text("Русский").tag("ru")
                Text("English").tag("en")
            }
            Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
            Stepper("Default schedule: \(viewModel.defaultScheduleMinutes) min", value: $viewModel.defaultScheduleMinutes, in: 5...240, step: 5)
        }
        .padding(20)
        .frame(width: 420)
    }
}
```

```text
/* Macyad/Resources/ru.lproj/Localizable.strings */
"onboarding.retry" = "Проверить снова";
"pair.new" = "New Pair";
"settings.launchAtLogin" = "Запускать при входе";
```

```text
/* Macyad/Resources/en.lproj/Localizable.strings */
"onboarding.retry" = "Retry";
"pair.new" = "New Pair";
"settings.launchAtLogin" = "Launch at login";
```

- [ ] **Step 4: Прогнать unit + UI tests**

Run:

```bash
xcodebuild \
  -project Macyad.xcodeproj \
  -scheme Macyad \
  -destination 'platform=macOS' \
  test
```

Expected:
- `** TEST SUCCEEDED **`
- `OnboardingUITests` и `PairFlowUITests` проходят

- [ ] **Step 5: Commit**

```bash
git add Macyad/ViewModels/SettingsViewModel.swift Macyad/Views/Settings/SettingsView.swift Macyad/Infrastructure/System/LoginItemService.swift Macyad/Resources MacyadUITests
git commit -m "feat: add settings localization and ui automation"
```

### Task 9: Добавить branding/assets, переименовать `Macyad` в `MacYaD`, перевести QA docs и удалить legacy `Tauri`/`React` код

**Files:**
- Create: `Macyad/App/AppMetadata.swift`
- Create: `Macyad/Resources/Assets.xcassets/AppIcon.appiconset/*`
- Create: `Macyad/Resources/Assets.xcassets/MenuBarTemplate.imageset/*`
- Modify: `project.yml`
- Modify: `script/build_and_run.sh`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/qa-macyad-mvp-checklist.md`
- Delete: `package.json`
- Delete: `package-lock.json`
- Delete: `index.html`
- Delete: `vite.config.ts`
- Delete: `tsconfig.json`
- Delete: `tsconfig.node.json`
- Delete: `src/**`
- Delete: `src-tauri/**`

- [ ] **Step 1: Добавить explicit app metadata, bundle identifier constants и новый product-facing app name**

```swift
// Macyad/App/AppMetadata.swift
enum AppMetadata {
    static let bundleIdentifier = "me.orloff.macyad"
    static let displayName = "MacYaD"
    static let loggingSubsystem = "me.orloff.macyad"
}
```

```yaml
# project.yml (relevant settings)
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: me.orloff.macyad
targets:
  Macyad:
    settings:
      base:
        INFOPLIST_KEY_CFBundleDisplayName: MacYaD
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

- [ ] **Step 2: Перевести QA checklist и README на новую native reality и зафиксировать rename `Macyad` -> `MacYaD` во всех user-facing местах**

```md
# README.md

# macyad

Нативное `macOS` приложение на `SwiftUI` для orchestration поверх `rclone` и Yandex Disk sync-пар.

## Запуск

`./script/build_and_run.sh`
```

```md
# docs/superpowers/plans/qa-macyad-mvp-checklist.md

# Macyad Native QA Checklist

- [ ] При запуске приложение показывает `menu bar` icon и `Dock` icon.
- [ ] Если `rclone` не найден, onboarding показывает `brew install rclone`, кнопку copy и `Проверить снова`.
- [ ] Создание `pair` доступно через `New Pair` и использует folder picker.
- [ ] Закрытие главного окна не завершает процесс приложения.
- [ ] `Sync Now`, `Check Yandex` и `Pull From Yandex` доступны из detail view и `menu bar`.
- [ ] В `Settings` доступны язык, `launch at login` и default schedule.
```

- [ ] **Step 3: Удалить legacy runtime после успешного native smoke pass**

Run:

```bash
rm -rf src src-tauri
rm -f package.json package-lock.json index.html vite.config.ts tsconfig.json tsconfig.node.json
```

Expected: legacy `Tauri`/`React` runtime files удалены, в репозитории остаются native `Macyad` target и docs

- [ ] **Step 4: Прогнать финальную verification matrix**

Run:

```bash
xcodegen generate
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS' test
./script/build_and_run.sh --verify
rg -n "com\\.orloff\\.macyad" Macyad project.yml script README.md docs
git status --short
```

Expected:
- `** TEST SUCCEEDED **`
- `./script/build_and_run.sh --verify` завершается успешно
- `rg` не находит старый `bundle identifier` в живом коде
- `git status --short` показывает только ожидаемые native rewrite changes перед commit, либо чистое дерево после commit

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: complete native swift rewrite"
```

## Self-Review

### Spec coverage

- `SwiftUI-first + narrow AppKit bridge`: покрыто Task 4 через `AppDelegateBridge`, `StatusBarBridge`, `WindowAccessor`, `PasteboardBridge`, `FolderPickerBridge`
- `clean start`, без миграции: покрыто Task 2 через новые JSON stores и `AppPaths`
- `Dock app + menu bar helper`: покрыто Task 4 и Task 9
- onboarding с `brew install rclone`, copy и `Проверить снова`: покрыто Task 3 + Task 5
- создание `pair` как desktop-first flow: покрыто Task 6
- `Sync Now` / `Check Yandex` / `Pull From Yandex`: покрыто Task 7
- scheduler и stop-on-alarm: покрыто Task 7
- settings, language, launch at login: покрыто Task 8
- `bundle identifier` `me.orloff.macyad`, icons, docs cleanup: покрыто Task 9
- удаление legacy `Tauri`/`React` runtime: покрыто Task 9

### Placeholder scan

- red-flag placeholders без конкретного действия, файла или команды в плане отсутствуют
- для code-changing steps в каждом task есть конкретные file paths, code snippets и commands

### Type consistency

- `AppPaths`, `AppEnvironment`, `AppModel`, `OnboardingState`, `SyncPair`, `MenuBarSummary`, `PairService`, `SchedulerService` и `StatusService` используются консистентно между задачами
- `bundle identifier` везде зафиксирован как `me.orloff.macyad`
