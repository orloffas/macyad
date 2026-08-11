import XCTest
@testable import MacyadCore

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private struct StubOnboardingService: OnboardingServicing {
        let step: OnboardingState.Step

        func refresh() async throws -> OnboardingState {
            OnboardingState(
                step: step,
                rcloneLocation: step == .installRclone ? nil : "/opt/homebrew/bin/rclone",
                rcloneVersion: step == .installRclone ? nil : "rclone v1.68.2",
                brewInstallCommand: "brew install rclone",
                remoteCreateCommand: "rclone config create yd-app yandex --config /tmp/rclone.conf",
                configPath: "/tmp/rclone.conf"
            )
        }
    }

    private final class StubPasteboard: PasteboardWriting {
        private(set) var copiedStrings: [String] = []

        func copy(_ string: String) {
            copiedStrings.append(string)
        }
    }

    private func makePair(autoSyncMode: AutoSyncMode = .push) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp",
            remotePath: "yd:/docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            autoSyncMode: autoSyncMode
        )
    }

    func testRetryRefreshesState() async throws {
        let service = StubOnboardingService(step: .configureRemote)
        let pasteboard = StubPasteboard()
        let model = OnboardingViewModel(service: service, pasteboard: pasteboard)

        await model.retry()

        XCTAssertEqual(model.state.step, .configureRemote)
        XCTAssertEqual(model.state.rcloneLocation, "/opt/homebrew/bin/rclone")
        XCTAssertEqual(model.state.rcloneVersion, "rclone v1.68.2")
        XCTAssertFalse(model.isRefreshing)
        XCTAssertNotNil(model.lastCheckedAt)
    }

    func testCopyMarksCommandAsCopied() async throws {
        let pasteboard = StubPasteboard()
        let model = OnboardingViewModel(
            service: StubOnboardingService(step: .installRclone),
            pasteboard: pasteboard
        )

        model.copy("brew install rclone")

        XCTAssertEqual(model.lastCopiedCommand, "brew install rclone")
        XCTAssertEqual(pasteboard.copiedStrings, ["brew install rclone"])
    }

    func testVisibleStepIsCompleteAfterFirstPairExists() async throws {
        let model = OnboardingViewModel(
            service: StubOnboardingService(step: .createFirstPair),
            pasteboard: StubPasteboard()
        )

        await model.retry()

        XCTAssertEqual(model.visibleStep(pairCount: 0), .createFirstPair)
        XCTAssertEqual(model.visibleStep(pairCount: 1), .complete)
    }

    func testStatusRowsSurfaceConfiguredState() async throws {
        let copy = AppCopy(language: .english)
        let model = OnboardingViewModel(
            service: StubOnboardingService(step: .createFirstPair),
            pasteboard: StubPasteboard()
        )
        let checkedAt = Date(timeIntervalSince1970: 1_000_000)

        await model.retry(now: checkedAt)

        XCTAssertEqual(
            model.statusRows(
                pairs: [makePair()],
                preferences: .defaults,
                copy: copy
            ),
            [
                OnboardingStatusRow(label: "rclone", value: "rclone v1.68.2"),
                OnboardingStatusRow(label: "Remote", value: "Configured"),
                OnboardingStatusRow(label: "Pairs", value: "1"),
                OnboardingStatusRow(label: "Scheduled sync", value: "Active"),
                OnboardingStatusRow(label: "Last check", value: copy.formatTimestamp(checkedAt))
            ]
        )
    }

    func testStatusRowsSurfacePausedScheduler() async throws {
        let copy = AppCopy(language: .english)
        let model = OnboardingViewModel(
            service: StubOnboardingService(step: .createFirstPair),
            pasteboard: StubPasteboard()
        )
        let paused = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )

        await model.retry()

        XCTAssertEqual(
            model.statusRows(pairs: [makePair(autoSyncMode: .off)], preferences: paused, copy: copy)[3],
            OnboardingStatusRow(label: "Scheduled sync", value: "Paused")
        )
    }
}
