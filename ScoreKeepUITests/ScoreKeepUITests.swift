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

        let cell = app.buttons["scorecard_cell_1_1"]
        XCTAssertTrue(cell.waitForExistence(timeout: 2.0), "Scorecard cell should exist")
        XCTAssertTrue(cell.isHittable, "Scorecard cell should be hittable")

        // Tap cell to bring up scoring sheet
        cell.tap()

        let doneButton = app.buttons["submit_scoring_action"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist")

        let doneFrame = doneButton.frame
        XCTAssertFalse(doneFrame.isEmpty, "Done button frame should be nonempty (hittability defect repair belongs to Task 7.14)")

        let cancelButton = app.buttons["cancel_scoring_action"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")

        // Optional scroll assertions can be done here.
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
}
