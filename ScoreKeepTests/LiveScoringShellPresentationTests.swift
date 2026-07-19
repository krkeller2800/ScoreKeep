import Foundation
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

    @Test("semantic score presentation displays coordinator-provided score and line state")
    func semanticScorePresentationDisplaysCoordinatorProvidedScoreAndLineState() {
        let presenter = LiveScoringShellPresentation()
        let state = LiveScoringWorkflowCoordinator.SemanticScoreState(
            disposition: .storedScoreMismatch,
            score: .init(home: 4, visiting: 3),
            storedScore: .init(home: 5, visiting: 3),
            battingSide: .home,
            inning: 6,
            halfInning: .home,
            outs: 2,
            bases: .init(first: nil, second: nil, third: nil),
            warnings: ["semanticScoreState.storedScoreMismatch"],
            canPresentScoringLine: true
        )

        let presentation = presenter.presentSemanticScoreState(state)

        #expect(presentation.homeScore == 4)
        #expect(presentation.visitingScore == 3)
        #expect(presentation.inning == 6)
        #expect(presentation.outs == 2)
        #expect(presentation.message == "semanticScoreState.storedScoreMismatch")
    }

    @Test("enabled action presentation exposes disabled reason for accessibility")
    func enabledActionPresentationExposesDisabledReasonForAccessibility() {
        let presenter = LiveScoringShellPresentation()
        let prepared = Fixture.preparedState(canScore: false)
        let disabled = LiveScoringWorkflowCoordinator.EnabledScoringActionState(
            identity: .legacyResult("Single"),
            isEnabled: false,
            disposition: .disabledPreparedStateUnavailable,
            validationDisposition: nil,
            unavailableReason: "A current pitcher is required before scoring.",
            warnings: []
        )
        let actionSet = LiveScoringWorkflowCoordinator.EnabledScoringActionSet(
            preparedState: prepared,
            semanticScoreState: nil,
            actions: [disabled],
            warnings: []
        )

        let presentation = presenter.presentEnabledActionSet(actionSet)
        let action = presentation.state(for: .legacyResult("Single"))

        #expect(action?.isEnabled == false)
        #expect(action?.accessibilityLabel == "Single")
        #expect(action?.accessibilityHint == "A current pitcher is required before scoring.")
    }

    @Test("submission presentation dismisses only accepted ordinary outcomes without additional choices")
    func submissionPresentationDismissesOnlyAcceptedOrdinaryOutcomesWithoutAdditionalChoices() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let accepted = presenter.presentSubmissionResult(
            .init(disposition: .accepted, atbat: atbat, actionState: nil, message: nil),
            requiresAdditionalChoice: false
        )
        let needsChoice = presenter.presentSubmissionResult(
            .init(disposition: .accepted, atbat: atbat, actionState: nil, message: nil),
            requiresAdditionalChoice: true
        )
        let failed = presenter.presentSubmissionResult(
            .init(disposition: .persistenceFailed, atbat: atbat, actionState: nil, message: "Error saving scoring action."),
            requiresAdditionalChoice: false
        )

        #expect(accepted.shouldDismissScoringSheet)
        #expect(accepted.shouldMarkChanged)
        #expect(!needsChoice.shouldDismissScoringSheet)
        #expect(needsChoice.shouldMarkChanged)
        #expect(!failed.shouldDismissScoringSheet)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Error saving scoring action.")
    }

    @Test("additional choice preparation presents pending choices without marking changed")
    func additionalChoicePreparationPresentsPendingChoicesWithoutMarkingChanged() {
        let presenter = LiveScoringShellPresentation()
        let pending = LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice(
            operationIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000000")!,
            originalScoringAction: .legacyResult("Fielder's Choice"),
            requiredChoiceCategory: "runnerMovementAndRecordedOut",
            gameIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000001")!,
            atbatIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000002")!,
            legacyResult: "Fielder's Choice",
            choices: .init(legacyResult: "Fielder's Choice", maxBase: "First", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true, playRecord: ""),
            availableMaxBases: ["No Bases", "First", "Second", "Third", "Home"],
            availableOutAtBases: ["Safe", "First", "Second", "Third", "Home"],
            availableRBIs: [0, 1, 2, 3, 4],
            availableStolenBases: [0, 1, 2, 3],
            allowsEarnedRunChoice: true,
            allowsPlayRecordChoice: true,
            validationWarnings: []
        )

        let presentation = presenter.presentAdditionalChoicePreparation(.init(disposition: .pending, pendingChoice: pending, actionState: nil, message: nil))
        let failed = presenter.presentAdditionalChoicePreparation(.init(disposition: .unsupportedAction, pendingChoice: nil, actionState: nil, message: "Unsupported"))

        #expect(presentation.shouldPresentAdditionalChoices)
        #expect(!presentation.shouldMarkChanged)
        #expect(presentation.pendingChoice == pending)
        #expect(!failed.shouldPresentAdditionalChoices)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Unsupported")
    }
}

private enum Fixture {
    static func atbat() -> Atbat {
        let team = Team(name: "Visitors", coach: "", details: "")
        let player = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team)
        let game = Game(date: "2026-07-18T12:00:00Z", location: "Task 6.9 Field", highLights: "", hscore: 0, vscore: 0, vteam: team, hteam: Team(name: "Home", coach: "", details: ""))
        return Atbat(game: game, team: team, player: player, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
    }

    static func preparedState(canScore: Bool) -> LiveScoringWorkflowCoordinator.PreparedLiveGameState {
        let homeTeamID = UUID()
        let visitingTeamID = UUID()
        return LiveScoringWorkflowCoordinator.PreparedLiveGameState(
            disposition: canScore ? .ready : .unavailablePitcher,
            gameIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000001"),
            homeTeam: .init(identity: homeTeamID, name: "Home", side: .home),
            visitingTeam: .init(identity: visitingTeamID, name: "Visitors", side: .visiting),
            battingSide: .visiting,
            battingTeam: .init(identity: visitingTeamID, name: "Visitors", side: .visiting),
            defensiveTeam: .init(identity: homeTeamID, name: "Home", side: .home),
            configuredInningCount: 9,
            everyoneHits: false,
            inning: 1,
            halfInning: .visiting,
            outs: 0,
            score: .init(home: 0, visiting: 0),
            bases: .init(first: nil, second: nil, third: nil),
            currentBatter: nil,
            battingOrderPosition: nil,
            currentPitcher: nil,
            latestScoringSequence: nil,
            currentScorecardColumn: 1,
            currentOrPendingLegacyAtbat: nil,
            lineup: [],
            pitcherAppearances: [],
            substitutions: [],
            warnings: canScore ? [] : ["preparedLiveGameState.unavailablePitcher"],
            canScore: canScore
        )
    }
}
