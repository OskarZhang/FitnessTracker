import XCTest

final class FitnessTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddWorkoutFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TEST_RESET", "UI_TEST_SKIP_FIRST_TIME_PROMPT"]
        app.launch()

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
        XCTAssertTrue(addSetControl.waitForExistence(timeout: 8))
        tapWhenInteractable(addSetControl)

        let saveControl = app.descendants(matching: .any)["setLogging.saveButton"]
        XCTAssertTrue(saveControl.waitForExistence(timeout: 8))
        tapWhenInteractable(saveControl)

        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["home.emptyStateText"].exists)

        app.terminate()
        app.launchArguments = ["UI_TEST_RESET", "UI_TEST_SEED_ORDERING", "UI_TEST_SKIP_FIRST_TIME_PROMPT"]
        app.launch()
        assertSetOrderingAndDeletionReindexBehavior(app)
    }

    @MainActor
    func testRestoresPendingSessionAfterBackgroundKill() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_RESET", "UI_TEST_SKIP_FIRST_TIME_PROMPT"]
        app.launch()

        openBenchPressLogging(app)

        let addSetControl = app.descendants(matching: .any)["setLogging.addSetButton"]
        XCTAssertTrue(addSetControl.waitForExistence(timeout: 8))
        tapWhenInteractable(addSetControl)

        XCUIDevice.shared.press(.home)
        app.terminate()

        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["setLogging.addSetButton"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func assertSetOrderingAndDeletionReindexBehavior(_ app: XCUIApplication) {
        let seededRow = app.buttons["home.workoutRow.Order Check Bench"]
        XCTAssertTrue(seededRow.waitForExistence(timeout: 8))
        seededRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.1.35x10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.2.40x10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.3.50x10"].waitForExistence(timeout: 5))

        app.buttons["Edit"].tap()
        let secondSetRow = app.cells.containing(.any, identifier: "setLogging.row.1").firstMatch
        XCTAssertTrue(secondSetRow.waitForExistence(timeout: 5))
        secondSetRow.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let saveControl = app.descendants(matching: .any)["setLogging.saveButton"]
        XCTAssertTrue(saveControl.waitForExistence(timeout: 8))
        tapWhenInteractable(saveControl)

        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.1.35x10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["workoutDetail.setRow.2.50x10"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["workoutDetail.setRow.3.50x10"].exists)
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
