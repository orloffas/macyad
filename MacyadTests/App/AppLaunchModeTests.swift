import XCTest
@testable import MacyadCore

final class AppLaunchModeTests: XCTestCase {
    func testNormalLaunchShowsMainWindowByDefault() {
        let mode = AppLaunchMode(arguments: ["MacYaD"])

        XCTAssertEqual(mode, .normal)
        XCTAssertTrue(mode.shouldForceForegroundWindow)
    }

    func testForceForegroundArgumentEnablesForegroundLaunch() {
        let mode = AppLaunchMode(arguments: ["MacYaD", "MACYAD_FORCE_FOREGROUND"])

        XCTAssertEqual(mode, .foreground)
        XCTAssertTrue(mode.shouldForceForegroundWindow)
    }

    func testForceForegroundEnvironmentEnablesForegroundLaunch() {
        let mode = AppLaunchMode(
            arguments: ["MacYaD"],
            environment: ["MACYAD_FORCE_FOREGROUND": "1"]
        )

        XCTAssertEqual(mode, .foreground)
        XCTAssertTrue(mode.shouldForceForegroundWindow)
    }

    func testUITestModesUseEphemeralPathsAndForegroundWindow() {
        XCTAssertTrue(AppLaunchMode(arguments: ["UITEST_READY_STATE"]).usesEphemeralPaths)
        XCTAssertTrue(AppLaunchMode(arguments: ["UITEST_ONBOARDING_MISSING_RCLONE"]).shouldForceForegroundWindow)
    }

    func testUITestModeTakesPrecedenceOverForceForegroundFlag() {
        let mode = AppLaunchMode(arguments: ["MacYaD", "UITEST_READY_STATE", "MACYAD_FORCE_FOREGROUND"])

        XCTAssertEqual(mode, .uiTestReadyState)
        XCTAssertTrue(mode.usesEphemeralPaths)
    }
}
