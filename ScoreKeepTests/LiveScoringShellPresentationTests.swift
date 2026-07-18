import Testing
@testable import ScoreKeep

@MainActor
@Suite("Live scoring shell presentation")
struct LiveScoringShellPresentationTests {
    @Test("successful scorecard selection opens the existing scoring sheet with the coordinator at-bat")
    func successfulScorecardSelectionOpensExistingScoringSheetWithCoordinatorAtbat() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentSelectionResult(.init(disposition: .success, atbat: atbat, message: nil))

        #expect(presentation.disposition == .success)
        #expect(presentation.selectedAtbat === atbat)
        #expect(presentation.shouldPresentScoringSheet)
        #expect(presentation.shouldMarkChanged)
        #expect(presentation.message == nil)
    }

    @Test("existing-cell no-change selection remains presentable without creating presentation fallback")
    func existingCellNoChangeSelectionRemainsPresentableWithoutCreatingPresentationFallback() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentSelectionResult(.init(disposition: .noChange, atbat: atbat, message: nil))

        #expect(presentation.disposition == .noChange)
        #expect(presentation.selectedAtbat === atbat)
        #expect(presentation.shouldPresentScoringSheet)
        #expect(presentation.shouldMarkChanged)
    }

    @Test("invalid and persistence-failed selection outcomes keep sheet and changed state closed")
    func invalidAndPersistenceFailedSelectionOutcomesKeepSheetAndChangedStateClosed() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let invalid = presenter.presentSelectionResult(.init(disposition: .validationFailed, atbat: nil, message: "Batter selection is unavailable."))
        let failed = presenter.presentSelectionResult(.init(disposition: .persistenceFailed, atbat: atbat, message: "Error saving new atbats."))

        #expect(invalid.selectedAtbat == nil)
        #expect(!invalid.shouldPresentScoringSheet)
        #expect(!invalid.shouldMarkChanged)
        #expect(invalid.message == "Batter selection is unavailable.")
        #expect(failed.selectedAtbat === atbat)
        #expect(!failed.shouldPresentScoringSheet)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Error saving new atbats.")
    }

    @Test("projection presentation displays only coordinator-provided projection values")
    func projectionPresentationDisplaysOnlyCoordinatorProvidedProjectionValues() {
        var columnBoxes = Array(repeating: BoxScore(), count: 2)
        var batterBoxes = Array(repeating: BoxScore(), count: 2)
        var totalBoxes = Array(repeating: BoxScore(), count: 1)
        columnBoxes[1].runs = 2
        batterBoxes[1].hits = 1
        totalBoxes[0].walks = 1
        let inningStatus = InnStatus(outs: 2, onFirst: true, onSecond: false, onThird: true)
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentProjectionResult(.init(
            disposition: .success,
            columnBoxes: columnBoxes,
            batterBoxes: batterBoxes,
            totalBoxes: totalBoxes,
            inningStatus: inningStatus,
            message: nil
        ))

        #expect(presentation.disposition == .success)
        #expect(presentation.columnBoxes[1].runs == 2)
        #expect(presentation.batterBoxes[1].hits == 1)
        #expect(presentation.totalBoxes[0].walks == 1)
        #expect(presentation.inningStatus.outs == 2)
        #expect(presentation.inningStatus.onFirst)
        #expect(!presentation.inningStatus.onSecond)
        #expect(presentation.inningStatus.onThird)
    }

    @Test("scorecard cell enablement reflects available selection input without baseball rules")
    func scorecardCellEnablementReflectsAvailableSelectionInputWithoutBaseballRules() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        #expect(presenter.scorecardCellIsEnabled(column: 1, sourceAtbat: atbat))
        #expect(!presenter.scorecardCellIsEnabled(column: 0, sourceAtbat: atbat))
        #expect(!presenter.scorecardCellIsEnabled(column: 1, sourceAtbat: nil))
    }
}

private enum Fixture {
    static func atbat() -> Atbat {
        let team = Team(name: "Visitors", coach: "", details: "")
        let player = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team)
        let game = Game(date: "2026-07-18T12:00:00Z", location: "Task 6.9 Field", highLights: "", hscore: 0, vscore: 0, vteam: team, hteam: Team(name: "Home", coach: "", details: ""))
        return Atbat(game: game, team: team, player: player, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
    }
}
