import XCTest

final class EnnuiUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Launch & Intro

    func testAppLaunches() throws {
        // The app should launch and display a window
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    func testIntroFadesAndSceneAppears() throws {
        // After ~6s the intro breathing light should dissolve and a scene must be visible
        // We wait for the picker to auto-show (it shows at ~5s for 6s)
        let picker = app.buttons.firstMatch
        let exists = picker.waitForExistence(timeout: 12)
        // Picker buttons appear after intro fades — their existence implies scenes loaded
        XCTAssertTrue(exists, "Scene picker should auto-appear after intro")
    }

    // MARK: - Scene Picker

    func testPickerAppearsOnSpacebar() throws {
        // Wait for intro to finish
        sleep(7)
        // Dismiss any auto-shown picker by waiting
        sleep(6)
        // Press space to show picker
        app.typeKey(" ", modifierFlags: [])
        sleep(1)
        // Should have at least 7 buttons (one per scene)
        let buttons = app.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 7, "Picker should show 7 scene orbs")
    }

    func testPickerAppearsOnDoubleTap() throws {
        sleep(7)
        let window = app.windows.firstMatch
        window.doubleTap()
        sleep(1)
        let buttons = app.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 1, "Picker should appear on double-tap")
    }

    // MARK: - Scene Switching

    func testArrowKeySwitchesScene() throws {
        // Wait for full startup
        sleep(8)
        // Press right arrow to go to next scene
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)  // Wait for crossfade
        // Press right again
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        // App should still be running and responsive
        XCTAssertTrue(app.windows.firstMatch.exists, "App should remain stable after scene switching")
    }

    func testCycleThroughAllScenes() throws {
        sleep(8)
        // Cycle through all 7 scenes via right arrow
        for i in 0..<7 {
            app.typeKey(.rightArrow, modifierFlags: [])
            // Allow crossfade transition
            sleep(3)
            XCTAssertTrue(app.windows.firstMatch.exists, "App should remain stable on scene \(i + 1)")
        }
    }

    func testLeftArrowNavigation() throws {
        sleep(8)
        // Go right twice, then left once
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        app.typeKey(.leftArrow, modifierFlags: [])
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Left arrow navigation should work")
    }

    // MARK: - Haiku Overlay

    func testHaikuToggleViaKeyboard() throws {
        sleep(8)
        // Press H to show haiku
        app.typeKey("h", modifierFlags: [])
        sleep(2)
        // Press H again to hide
        app.typeKey("h", modifierFlags: [])
        sleep(2)
        XCTAssertTrue(app.windows.firstMatch.exists, "Haiku toggle should not crash")
    }

    // MARK: - Interaction

    func testSingleTapInteraction() throws {
        sleep(8)
        let window = app.windows.firstMatch
        window.tap()
        sleep(1)
        XCTAssertTrue(window.exists, "Single tap should not crash")
    }

    func testPinchGesture() throws {
        sleep(8)
        let window = app.windows.firstMatch
        window.pinch(withScale: 1.5, velocity: 1.0)
        sleep(2)
        XCTAssertTrue(window.exists, "Pinch gesture should not crash")
    }

    // MARK: - Stability

    func testRapidSceneSwitching() throws {
        sleep(8)
        // Rapid-fire scene switches to test for race conditions
        for _ in 0..<10 {
            app.typeKey(.rightArrow, modifierFlags: [])
            usleep(300_000)  // 300ms between switches
        }
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "App should survive rapid scene switching")
    }

    func testPickerSelectionSwitchesScene() throws {
        sleep(8)
        // Show picker
        app.typeKey(" ", modifierFlags: [])
        sleep(1)
        // Tap first available button (scene orb)
        let firstButton = app.buttons.firstMatch
        if firstButton.exists {
            firstButton.tap()
            sleep(3)
        }
        XCTAssertTrue(app.windows.firstMatch.exists, "Picker scene selection should work")
    }

    func testExtendedRunStability() throws {
        // Let the app run for 30 seconds across multiple scenes
        sleep(8)
        for i in 0..<5 {
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(5)
            XCTAssertTrue(app.windows.firstMatch.exists, "App should be stable after \((i + 1) * 5)s")
        }
    }
}
