import XCTest

@MainActor
final class TrialScopeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func search(_ query: String) {
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(query)
        app.buttons["searchButton"].tap()
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        // Content may have shrunk and left the target above the viewport.
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func setSwitch(_ identifier: String, on: Bool) {
        let control = app.switches[identifier]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        scrollTo(control)
        // SwiftUI exposes the full Form row as a switch. Tap its trailing thumb,
        // not the center label, which does not change the value on iOS 27.
        let expected = on ? "1" : "0"
        if control.value as? String != expected {
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertEqual(control.value as? String, expected)
    }

    func testSearchSaveNoteAndRemove() {
        launchApp()
        XCTAssertTrue(app.textFields["searchField"].waitForExistence(timeout: 10))
        capture("01-discover")
        search("breast")
        let trial = app.buttons["trial-DEMO-001"]
        XCTAssertTrue(trial.waitForExistence(timeout: 5))
        scrollTo(trial)
        capture("02-search-results")
        trial.tap()
        let save = app.buttons["saveStudyButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        capture("03-study-details")
        save.tap()
        XCTAssertEqual(save.label, "Remove from saved")
        app.swipeUp()
        capture("11-study-criteria")
        let edit = app.buttons["editNoteButton"]
        scrollTo(edit)
        edit.tap()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("Ask about visit frequency.")
        app.buttons["saveNoteButton"].tap()
        app.tabBars.buttons["Saved"].tap()
        let saved = app.buttons["saved-DEMO-001"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        capture("04-saved-studies")
        saved.tap()
        let note = app.staticTexts["Ask about visit frequency."]
        scrollTo(note)
        XCTAssertTrue(note.exists)
        capture("05-saved-notes")
        app.buttons["saveStudyButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Your shortlist starts here"].waitForExistence(timeout: 3))
    }

    func testNoResultsAndReset() {
        launchApp()
        search("zzzz-nonexistent")
        let empty = app.staticTexts["No studies found"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        capture("08-empty-results")
        scrollTo(app.buttons["Reset search"])
        app.buttons["Reset search"].tap()
        scrollTo(app.buttons["trial-DEMO-001"])
        XCTAssertTrue(app.buttons["trial-DEMO-001"].waitForExistence(timeout: 5))
    }

    func testFiltersValidateAge() {
        launchApp()
        app.buttons["filtersButton"].tap()
        let age = app.textFields["ageField"]
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        age.tap()
        age.typeText("999")
        XCTAssertFalse(app.buttons["applyFiltersButton"].isEnabled)
        capture("06-filter-validation")
        app.buttons["Reset filters"].tap()
        XCTAssertTrue(app.buttons["applyFiltersButton"].isEnabled)
        setSwitch("recruitingToggle", on: true)
        capture("07-recruiting-filter")
        app.buttons["applyFiltersButton"].tap()
        XCTAssertTrue(app.staticTexts["1 filter applied"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["trial-DEMO-001"].waitForExistence(timeout: 5))
        capture("12-filters-applied")
    }

    func testFailureAndRecovery() {
        launchApp()
        app.tabBars.buttons["Settings"].tap()
        setSwitch("failureToggle", on: true)
        app.tabBars.buttons["Discover"].tap()
        app.buttons["searchButton"].tap()
        XCTAssertTrue(app.staticTexts["Couldn’t load studies"].waitForExistence(timeout: 5))
        scrollTo(app.buttons["retryButton"])
        capture("09-service-error")
        app.tabBars.buttons["Settings"].tap()
        setSwitch("failureToggle", on: false)
        app.tabBars.buttons["Discover"].tap()
        let retry = app.buttons["retryButton"]
        scrollTo(retry)
        retry.tap()
        scrollTo(app.buttons["trial-DEMO-001"])
        XCTAssertTrue(app.buttons["trial-DEMO-001"].waitForExistence(timeout: 5))
        capture("10-recovered-results")
    }
}
