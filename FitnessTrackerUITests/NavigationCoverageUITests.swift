import XCTest

final class NavigationCoverageUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigateHomeSettingsAddAndSetLoggingScreens() throws {
        let app = launchApp(["UI_TEST_RESET", "UI_TEST_SKIP_FIRST_TIME_PROMPT"])

        let addWorkoutButton = app.buttons["home.addWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 5))

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let settingsDoneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(settingsDoneButton.waitForExistence(timeout: 5))
        settingsDoneButton.tap()

        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 6))

        openBenchPressLogging(app)

        let addSetControl = app.descendants(matching: .any)["setLogging.addSetButton"]
        XCTAssertTrue(addSetControl.waitForExistence(timeout: 8))
        tapWhenInteractable(addSetControl)

        let saveControl = app.descendants(matching: .any)["setLogging.saveButton"]
        XCTAssertTrue(saveControl.waitForExistence(timeout: 8))
        tapWhenInteractable(saveControl)

        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.workoutRow.Bench Press"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testNavigateWorkoutDetailAndEditSetLoggingScreens() throws {
        let app = launchApp(["UI_TEST_RESET", "UI_TEST_SEED_ORDERING", "UI_TEST_SKIP_FIRST_TIME_PROMPT"])

        let workoutRow = app.buttons["home.workoutRow.Order Check Bench"]
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 8))
        workoutRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.1.35x10"].waitForExistence(timeout: 5))

        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["setLogging.addSetButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["setLogging.saveButton"].waitForExistence(timeout: 8))
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
