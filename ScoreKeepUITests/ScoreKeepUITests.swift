//
//  ScoreKeepUITests.swift
//  ScoreKeepUITests
//
//  Created by Karl Keller on 3/15/25.
//

import XCTest

final class ScoreKeepUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testDynamicTypeSeam() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScoreKeepUITestDynamicTypeSeam")
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        let root = app.descendants(matching: .any).matching(identifier: "live_scoring_root").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5.0), "Live scoring root should exist")

        let cell = firstRenderedScorecardCell(in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 2.0), "Scorecard cell should exist")
        XCTAssertTrue(cell.isHittable, "Scorecard cell should be hittable")

        // Tap cell to bring up scoring sheet
        cell.tap()

        let doneButton = app.buttons["submit_scoring_action"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist")
        XCTAssertTrue(doneButton.isHittable, "Done button should be hittable at Accessibility XXXL")

        let doneFrame = doneButton.frame
        XCTAssertFalse(doneFrame.isEmpty, "Done button frame should be nonempty")

        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(windowFrame.contains(doneFrame), "Done button should be completely inside the app window")

        let cancelButton = app.buttons["cancel_scoring_action"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        XCTAssertTrue(cancelButton.isHittable, "Cancel button should be hittable at Accessibility XXXL")

        let cancelFrame = cancelButton.frame
        XCTAssertFalse(doneFrame.intersects(cancelFrame), "Done and Cancel buttons should not intersect")
        XCTAssertTrue(windowFrame.contains(cancelFrame), "Cancel button should be completely inside the app window")
    }

    @MainActor
    func testIPhoneLayoutSeam() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScoreKeepUITestDynamicTypeSeam")
        app.launch()

        // Ensure portrait orientation
        XCUIDevice.shared.orientation = .portrait

        let root = app.descendants(matching: .any).matching(identifier: "live_scoring_root").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5.0), "Live scoring root should exist")

        let cell = firstRenderedScorecardCell(in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 2.0), "Scorecard cell should exist")
        XCTAssertTrue(cell.isHittable, "Scorecard cell should be hittable in portrait")

        // Check for multiple cells with the same ID, should be exactly 1
        XCTAssertEqual(renderedColumnOneScorecardCells(in: app).count, 1, "Should not have duplicate scoring activations")

        // Tap cell to bring up scoring sheet
        cell.tap()

        let doneButton = app.buttons["submit_scoring_action"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist")
        XCTAssertTrue(doneButton.isHittable, "Done button should be hittable on iPhone layout")
        XCTAssertEqual(app.buttons.matching(identifier: "submit_scoring_action").count, 1, "Should not have duplicate submit controls")

        let doneFrame = doneButton.frame
        XCTAssertFalse(doneFrame.isEmpty, "Done button frame should be nonempty")

        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(windowFrame.contains(doneFrame), "Done button should be completely inside the app window")

        let cancelButton = app.buttons["cancel_scoring_action"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        XCTAssertTrue(cancelButton.isHittable, "Cancel button should be hittable on iPhone layout")
        XCTAssertEqual(app.buttons.matching(identifier: "cancel_scoring_action").count, 1, "Should not have duplicate cancel controls")

        let cancelFrame = cancelButton.frame
        XCTAssertFalse(doneFrame.intersects(cancelFrame), "Done and Cancel buttons should not overlap")
        XCTAssertTrue(windowFrame.contains(cancelFrame), "Cancel button should be completely inside the app window")
    }

    @MainActor
    func testIPadLayoutSeam() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScoreKeepUITestDynamicTypeSeam")
        app.launch()

        // Ensure portrait orientation
        XCUIDevice.shared.orientation = .portrait

        let root = app.descendants(matching: .any).matching(identifier: "live_scoring_root").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5.0), "Live scoring root should exist")

        let cell = firstRenderedScorecardCell(in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 2.0), "Scorecard cell should exist")
        XCTAssertTrue(cell.isHittable, "Scorecard cell should be hittable in portrait")

        // Check for multiple cells with the same ID, should be exactly 1
        XCTAssertEqual(renderedColumnOneScorecardCells(in: app).count, 1, "Should not have duplicate scoring activations")

        // Tap cell to bring up scoring sheet
        cell.tap()

        let doneButton = app.buttons["submit_scoring_action"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist")
        XCTAssertTrue(doneButton.isHittable, "Done button should be hittable on iPad layout")
        XCTAssertEqual(app.buttons.matching(identifier: "submit_scoring_action").count, 1, "Should not have duplicate submit controls")

        let doneFrame = doneButton.frame
        XCTAssertFalse(doneFrame.isEmpty, "Done button frame should be nonempty")

        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(windowFrame.contains(doneFrame), "Done button should be completely inside the app window")

        let cancelButton = app.buttons["cancel_scoring_action"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        XCTAssertTrue(cancelButton.isHittable, "Cancel button should be hittable on iPad layout")
        XCTAssertEqual(app.buttons.matching(identifier: "cancel_scoring_action").count, 1, "Should not have duplicate cancel controls")

        let cancelFrame = cancelButton.frame
        XCTAssertFalse(doneFrame.intersects(cancelFrame), "Done and Cancel buttons should not overlap")
        XCTAssertTrue(windowFrame.contains(cancelFrame), "Cancel button should be completely inside the app window")
    }


    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    private func firstRenderedScorecardCell(in app: XCUIApplication) -> XCUIElement {
        let deadline = Date().addingTimeInterval(2.0)
        repeat {
            if let cell = renderedColumnOneScorecardCells(in: app).first {
                return cell
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return app.buttons["scorecard_rendered_cell_unavailable_1"]
    }

    private func renderedColumnOneScorecardCells(in app: XCUIApplication) -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { element in
            element.identifier.hasPrefix("scorecard_rendered_cell_") &&
            element.identifier.hasSuffix("_1")
        }
    }
}
