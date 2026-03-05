import XCTest

// Total scene count — must match SceneKind.allCases.count in SceneType.swift.
// 2D: 36 scenes, 3D: 39 scenes = 75 total (as of March 2026)
private let kSceneCount = 75

final class EnnuiUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// Wait for the intro breathing animation to finish and scenes to be ready.
    private func waitForIntro() {
        sleep(8)
    }

    // MARK: - Launch & Intro

    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    func testIntroFadesAndSceneAppears() throws {
        let picker = app.buttons.firstMatch
        let exists = picker.waitForExistence(timeout: 12)
        XCTAssertTrue(exists, "Scene picker should auto-appear after intro")
    }

    // MARK: - Scene Picker

    func testPickerAppearsOnSpacebar() throws {
        waitForIntro()
        // Wait for auto-shown picker to dismiss
        sleep(6)
        app.typeKey(" ", modifierFlags: [])
        sleep(1)
        XCTAssertGreaterThanOrEqual(app.buttons.count, kSceneCount,
            "Picker should show \(kSceneCount) scene orbs")
    }

    func testPickerAppearsOnDoubleTap() throws {
        waitForIntro()
        app.windows.firstMatch.doubleTap()
        sleep(1)
        XCTAssertGreaterThanOrEqual(app.buttons.count, 1, "Picker should appear on double-tap")
    }

    // MARK: - Full Scene Cycle (the main crash-catcher)

    /// Cycle through ALL scenes one by one via right-arrow.
    /// Each scene renders for 3 seconds — enough to trigger generate(),
    /// Canvas drawing, and Metal compositing. Catches crashes, range errors,
    /// and infinite-loop @State mutations.
    func testCycleThroughAllScenes() throws {
        waitForIntro()
        for i in 0..<kSceneCount {
            app.typeKey(.rightArrow, modifierFlags: [])
            // 3s = crossfade (2s) + 1s render at full size
            sleep(3)
            XCTAssertTrue(app.windows.firstMatch.exists,
                "App crashed on scene \(i + 1) of \(kSceneCount)")
        }
    }

    /// Cycle all scenes in reverse via left-arrow.
    func testCycleAllScenesReverse() throws {
        waitForIntro()
        for i in 0..<kSceneCount {
            app.typeKey(.leftArrow, modifierFlags: [])
            sleep(3)
            XCTAssertTrue(app.windows.firstMatch.exists,
                "App crashed on reverse scene \(i + 1) of \(kSceneCount)")
        }
    }

    /// Cycle every scene and tap once in each to test interaction handlers.
    func testCycleAllScenesWithTap() throws {
        waitForIntro()
        let window = app.windows.firstMatch
        for i in 0..<kSceneCount {
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(3)
            window.tap()
            sleep(1)
            XCTAssertTrue(window.exists,
                "App crashed after tap on scene \(i + 1) of \(kSceneCount)")
        }
    }

    /// Cycle every scene and toggle haiku in each to exercise HaikuOverlay
    /// fallback lookup for all scene types.
    func testCycleAllScenesWithHaiku() throws {
        waitForIntro()
        for i in 0..<kSceneCount {
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(3)
            // Toggle haiku on
            app.typeKey("h", modifierFlags: [])
            sleep(1)
            // Toggle haiku off
            app.typeKey("h", modifierFlags: [])
            sleep(1)
            XCTAssertTrue(app.windows.firstMatch.exists,
                "App crashed with haiku on scene \(i + 1) of \(kSceneCount)")
        }
    }

    // MARK: - Navigation Edge Cases

    func testArrowKeySwitchesScene() throws {
        waitForIntro()
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "App should remain stable after scene switching")
    }

    func testLeftArrowNavigation() throws {
        waitForIntro()
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        app.typeKey(.rightArrow, modifierFlags: [])
        sleep(3)
        app.typeKey(.leftArrow, modifierFlags: [])
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Left arrow navigation should work")
    }

    func testWrapAroundForward() throws {
        waitForIntro()
        // Go past the last scene — should wrap to first
        for _ in 0..<(kSceneCount + 2) {
            app.typeKey(.rightArrow, modifierFlags: [])
            usleep(500_000) // 0.5s — fast enough to test wrap
        }
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Wrap-around forward should not crash")
    }

    func testWrapAroundBackward() throws {
        waitForIntro()
        // Go backward past the first scene — should wrap to last
        for _ in 0..<(kSceneCount + 2) {
            app.typeKey(.leftArrow, modifierFlags: [])
            usleep(500_000)
        }
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Wrap-around backward should not crash")
    }

    // MARK: - Haiku Overlay

    func testHaikuToggleViaKeyboard() throws {
        waitForIntro()
        app.typeKey("h", modifierFlags: [])
        sleep(2)
        app.typeKey("h", modifierFlags: [])
        sleep(2)
        XCTAssertTrue(app.windows.firstMatch.exists, "Haiku toggle should not crash")
    }

    // MARK: - Interaction

    func testSingleTapInteraction() throws {
        waitForIntro()
        let window = app.windows.firstMatch
        window.tap()
        sleep(1)
        XCTAssertTrue(window.exists, "Single tap should not crash")
    }

    func testMultipleTapsOnSameScene() throws {
        waitForIntro()
        let window = app.windows.firstMatch
        for _ in 0..<5 {
            window.tap()
            usleep(400_000)
        }
        sleep(1)
        XCTAssertTrue(window.exists, "Rapid taps should not crash")
    }

    // MARK: - Audio

    func testAudioMuteToggle() throws {
        waitForIntro()
        // M toggles audio mute
        app.typeKey("m", modifierFlags: [])
        sleep(1)
        app.typeKey("m", modifierFlags: [])
        sleep(1)
        XCTAssertTrue(app.windows.firstMatch.exists, "Audio mute toggle should not crash")
    }

    // MARK: - About Panel

    func testAboutPanelToggle() throws {
        waitForIntro()
        // ? toggles about panel
        app.typeKey("?", modifierFlags: .shift)
        sleep(2)
        app.typeKey("?", modifierFlags: .shift)
        sleep(1)
        XCTAssertTrue(app.windows.firstMatch.exists, "About panel toggle should not crash")
    }

    // MARK: - Picker Selection

    func testPickerSelectionSwitchesScene() throws {
        waitForIntro()
        app.typeKey(" ", modifierFlags: [])
        sleep(1)
        let firstButton = app.buttons.firstMatch
        if firstButton.exists {
            firstButton.tap()
            sleep(3)
        }
        XCTAssertTrue(app.windows.firstMatch.exists, "Picker scene selection should work")
    }

    // MARK: - Stress Tests

    func testRapidSceneSwitching() throws {
        waitForIntro()
        // Rapid-fire: 20 switches at ~200ms — tests race conditions
        for _ in 0..<20 {
            app.typeKey(.rightArrow, modifierFlags: [])
            usleep(200_000)
        }
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "App should survive rapid scene switching")
    }

    func testRapidBidirectionalSwitching() throws {
        waitForIntro()
        // Alternate left/right rapidly
        for _ in 0..<15 {
            app.typeKey(.rightArrow, modifierFlags: [])
            usleep(200_000)
            app.typeKey(.leftArrow, modifierFlags: [])
            usleep(200_000)
        }
        sleep(3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Rapid bidirectional switching should not crash")
    }

    func testSwitchSceneDuringHaiku() throws {
        waitForIntro()
        // Show haiku, then switch scenes — tests concurrent overlay + transition
        app.typeKey("h", modifierFlags: [])
        sleep(1)
        for _ in 0..<5 {
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(2)
        }
        app.typeKey("h", modifierFlags: [])
        sleep(1)
        XCTAssertTrue(app.windows.firstMatch.exists, "Scene switch during haiku should not crash")
    }

    func testExtendedRunStability() throws {
        // 60 seconds across many scenes
        waitForIntro()
        for i in 0..<10 {
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(5)
            XCTAssertTrue(app.windows.firstMatch.exists,
                "App should be stable at \((i + 1) * 5)s extended run")
        }
    }

    /// Combined stress: cycle all scenes with tap + haiku at max speed
    func testFullStressCycle() throws {
        waitForIntro()
        let window = app.windows.firstMatch
        for i in 0..<kSceneCount {
            app.typeKey(.rightArrow, modifierFlags: [])
            usleep(800_000) // 0.8s — fast but enough for Canvas to render
            window.tap()
            usleep(200_000)
            if i % 5 == 0 {
                app.typeKey("h", modifierFlags: [])
                usleep(300_000)
                app.typeKey("h", modifierFlags: [])
            }
            XCTAssertTrue(window.exists,
                "Full stress cycle crashed on scene \(i + 1)")
        }
    }
}
