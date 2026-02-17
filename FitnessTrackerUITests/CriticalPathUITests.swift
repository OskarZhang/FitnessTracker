import XCTest

final class CriticalPathUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlowSkipToHome() throws {
        let app = launchApp(["UI_TEST_RESET", "UI_TEST_FORCE_ONBOARDING"])

        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 8))

        let notNowButton = app.buttons["onboarding.notNowButton"]
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 8))
        notNowButton.tap()

        let addWorkoutButton = app.buttons["home.addWorkoutButton"]
        if !addWorkoutButton.waitForExistence(timeout: 10) {
            if notNowButton.exists {
                notNowButton.tap()
            }
        }
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 10))
    }

    @MainActor
    func testTimerFlowStartsWhileLogging() throws {
        let app = launchApp(["UI_TEST_RESET", "UI_TEST_COMPLETE_ONBOARDING", "UI_TEST_SKIP_FIRST_TIME_PROMPT"])

        openBenchPressLogging(app)

        let addSetControl = app.descendants(matching: .any)["setLogging.addSetButton"]
        XCTAssertTrue(addSetControl.waitForExistence(timeout: 8))
        tapWhenInteractable(addSetControl)

        let timerButton = app.buttons["setLogging.timerButton"]
        XCTAssertTrue(timerButton.waitForExistence(timeout: 8))
        timerButton.tap()

        let runningPredicate = NSPredicate(format: "value != %@", "stopped")
        let timerRunningExpectation = XCTNSPredicateExpectation(predicate: runningPredicate, object: timerButton)
        XCTAssertEqual(XCTWaiter().wait(for: [timerRunningExpectation], timeout: 8), .completed)
    }

    @MainActor
    func testHealthKitSettingsFlowReachable() throws {
        let app = launchApp(["UI_TEST_RESET", "UI_TEST_COMPLETE_ONBOARDING"])

        let addWorkoutButton = app.buttons["home.addWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 8))

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 8))
        settingsButton.tap()

        let statusLabel = app.staticTexts["settings.healthkitStatusLabel"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 8))

        let allowedStatusValues: Set<String> = ["Unavailable", "Not enabled", "Authorized", "Denied", "Unknown"]
        XCTAssertTrue(allowedStatusValues.contains(statusLabel.label))

        let enableHealthKitButton = app.buttons["settings.enableHealthKitButton"]
        if enableHealthKitButton.exists, enableHealthKitButton.isEnabled {
            enableHealthKitButton.tap()
        }

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8))
        doneButton.tap()

        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 10))
    }

    private func launchApp(_ launchArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
        return app
    }

    private func openBenchPressLogging(_ app: XCUIApplication) {
        let addWorkoutButton = app.buttons["home.addWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 5))
        addWorkoutButton.tap()

        let exerciseInput = app.textFields["addWorkout.exerciseInput"]
        XCTAssertTrue(exerciseInput.waitForExistence(timeout: 5))
        exerciseInput.tap()
        exerciseInput.typeText("Bench Press")

        let suggestionButton = app.buttons["addWorkout.suggestion.Bench Press"]
        XCTAssertTrue(suggestionButton.waitForExistence(timeout: 5))
        suggestionButton.tap()

        let addSetControl = app.descendants(matching: .any)["setLogging.addSetButton"]
        XCTAssertTrue(addSetControl.waitForExistence(timeout: 10))
        XCTAssertTrue(addSetControl.isHittable || waitForHittable(addSetControl, timeout: 6))
    }

    private func tapWhenInteractable(_ element: XCUIElement, timeout: TimeInterval = 6) {
        _ = waitForHittable(element, timeout: timeout)

        if element.isHittable {
            element.tap()
            return
        }

        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
