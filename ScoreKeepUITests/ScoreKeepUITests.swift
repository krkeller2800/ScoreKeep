//
//  ScoreKeepUITests.swift
//  ScoreKeepUITests
//
//  Created by Karl Keller on 3/15/25.
//

import XCTest
import UIKit

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
    func testPlayerRosterAddEditSeam() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScoreKeepUITestPlayerRosterSeam")
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft

        openRosterIfNeeded(in: app)

        let existingPlayer = app.staticTexts["Existing Player"]
        XCTAssertTrue(existingPlayer.waitForExistence(timeout: 5.0), "Existing roster player should be visible")

        let addPlayer = app.buttons["Add player"]
        XCTAssertTrue(addPlayer.waitForExistence(timeout: 5.0), "Add Player route should be visible")
        addPlayer.tap()

        let addTitle = app.navigationBars["Add Player"]
        XCTAssertTrue(addTitle.waitForExistence(timeout: 5.0), "Add Player form should open")
        assertPlayerFormControls(in: app, expectsReadOnlyTeam: true)

        let savePlayer = app.buttons["Save player"]
        XCTAssertTrue(savePlayer.exists, "Save should be present")
        XCTAssertFalse(savePlayer.isEnabled, "Save should be disabled before a player name is entered")

        enterText("Added Player", in: app.textFields["player_name_field"])
        let enabledSavePlayer = app.buttons["Save player"]
        XCTAssertTrue(enabledSavePlayer.waitForExistence(timeout: 2.0), "Save should remain present")
        enabledSavePlayer.tap()

        let addedPlayer = app.staticTexts["Added Player"]
        XCTAssertTrue(addedPlayer.waitForExistence(timeout: 5.0), "Saved player should return to and appear in the roster")

        existingPlayer.tap()

        let editTitle = app.navigationBars["Update a Player"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5.0), "Edit Player form should open")
        assertPlayerFormControls(in: app, expectsReadOnlyTeam: false)

        XCTAssertEqual(app.textFields["player_name_field"].value as? String, "Existing Player")
        XCTAssertEqual(app.textFields["player_number_field"].value as? String, "7")
        XCTAssertEqual(app.textFields["player_position_field"].value as? String, "Shortstop")
        XCTAssertEqual(app.textFields["player_batting_direction_field"].value as? String, "R")

        enterText(" Edited", in: app.textFields["player_name_field"])

        app.buttons["Back"].tap()
        let unsavedAlert = app.alerts["Unsaved Changes"]
        XCTAssertTrue(unsavedAlert.waitForExistence(timeout: 2.0), "Dirty Back should present unsaved changes protection")
        unsavedAlert.buttons["Keep Editing"].tap()

        app.buttons["Save player"].tap()
        XCTAssertEqual(app.textFields["player_name_field"].value as? String, "Existing Player Edited")
    }

    @MainActor
    func testTeamAddPresentationSeam() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScoreKeepUITestTeamPresentationSeam")
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft

        let addTeam = app.buttons["Add Team"]
        XCTAssertTrue(addTeam.waitForExistence(timeout: 5.0), "Standard Add Team route should be visible")
        addTeam.tap()

        let addTitle = app.navigationBars["Add Team"]
        XCTAssertTrue(addTitle.waitForExistence(timeout: 5.0), "Add Team form should open")
        XCTAssertTrue(app.textFields["team_name_field"].waitForExistence(timeout: 3.0), "Team Name should be an editable field")
        XCTAssertTrue(app.textFields["team_coach_field"].exists, "Coach should be an editable field")
        XCTAssertTrue(app.textFields["team_details_field"].exists, "Details should be an editable field")
        XCTAssertTrue(app.buttons["Choose team logo from Photos"].exists, "Photos control should remain available")
        XCTAssertTrue(app.buttons["Paste team logo"].exists, "Paste logo control should remain available")

        let saveTeam = app.buttons["Save team"]
        XCTAssertTrue(saveTeam.exists, "Save should be present")
        XCTAssertFalse(saveTeam.isEnabled, "Save should be disabled before a team name is entered")
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

    private func openRosterIfNeeded(in app: XCUIApplication) {
        let playersButton = app.buttons["Players"]
        if playersButton.waitForExistence(timeout: 2.0) {
            playersButton.tap()
        }

        let addPlayer = app.buttons["Add player"]
        XCTAssertTrue(addPlayer.waitForExistence(timeout: 5.0), "Roster should show Add Player")
    }

    private func assertPlayerFormControls(in app: XCUIApplication, expectsReadOnlyTeam: Bool) {
        XCTAssertTrue(app.textFields["player_name_field"].waitForExistence(timeout: 3.0), "Name should be an editable field")
        XCTAssertTrue(app.textFields["player_number_field"].exists, "Number should be an editable field")
        XCTAssertTrue(app.textFields["player_position_field"].exists, "Position should be an editable field")
        XCTAssertTrue(app.textFields["player_batting_direction_field"].exists, "Batting Direction should be an editable field")
        XCTAssertTrue(app.buttons["Choose player photo from Photos"].exists, "Photos control should remain available")
        XCTAssertTrue(app.buttons["Paste player photo"].exists, "Paste photo control should remain available")
        XCTAssertTrue(app.descendants(matching: .any)["player_batting_order_picker"].exists, "Batting Order should remain a picker/control")

        if expectsReadOnlyTeam {
            XCTAssertTrue(app.staticTexts["Team"].exists, "Team label should remain visible")
            XCTAssertTrue(app.staticTexts["Seam Team"].exists, "Team-scoped Add Player should show the current Team as read-only")
            XCTAssertFalse(app.buttons["Team"].exists, "Team-scoped Add Player should not expose Team as a picker")
        }
    }

    private func enterText(_ text: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 3.0), "Expected text field to exist before entering text")
        UIPasteboard.general.string = text
        field.tap()
        field.press(forDuration: 1.0)
        let paste = XCUIApplication().menuItems["Paste"]
        if paste.waitForExistence(timeout: 1.0) {
            paste.tap()
        } else {
            field.tap()
            field.typeText(text)
        }
    }
}
