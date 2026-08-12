import XCTest
import SwiftData
@testable import ScoreKeep

@MainActor
final class LiveScoringWorkflowCoordinatorSubstitutionTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var coordinator: LiveScoringWorkflowCoordinator!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Game.self, Player.self, Atbat.self, Pitcher.self, Team.self, configurations: config)
        modelContext = modelContainer.mainContext
        coordinator = LiveScoringWorkflowCoordinator()
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        coordinator = nil
    }

    func testBatterSubstitution_AcceptedAndRollsBackOnFailure() throws {
        // Setup using Fixture
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        let outgoing = fixture.visitingFirst.player

        let incoming = Player(name: "Incoming", number: "2", position: "2B", batDir: "L", batOrder: 99)
        incoming.team = fixture.visitingTeam
        modelContext.insert(incoming)
        game.players.append(incoming)

        // Capture previous atbat data for verification
        let previousAtbat = fixture.visitingFirst
        let prevResult = previousAtbat.result
        let prevOuts = previousAtbat.outs
        let prevInning = previousAtbat.inning
        let prevSeq = previousAtbat.seq

        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)

        try modelContext.save()

        // Act
        let result = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )

        // Assert
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        XCTAssertNotNil(result.refreshedState)

        XCTAssertTrue(game.replaced.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(game.incomings.contains { $0.identifier == incoming.identifier })
        XCTAssertEqual(game.replaced.count, game.incomings.count, "Parallel array invariant violated")
        XCTAssertEqual(game.replaced.last?.identifier, outgoing.identifier)
        XCTAssertEqual(game.incomings.last?.identifier, incoming.identifier)

        XCTAssertEqual(incoming.batOrder, 2) // Inserted after outgoing
        XCTAssertEqual(fixture.visitingSecond.player.batOrder, 3) // Shifted down

        // Check the newly created placeholder
        let placeholder = game.atbats.last { $0.result == "Pitch Hitter" }
        XCTAssertNotNil(placeholder)
        XCTAssertEqual(placeholder?.player.identifier, incoming.identifier)
        XCTAssertEqual(placeholder?.seq, 2) // Inserted after outgoing's seq

        // Verify earlier plays are preserved
        XCTAssertEqual(previousAtbat.player.identifier, outgoing.identifier)
        XCTAssertEqual(previousAtbat.result, prevResult)
        XCTAssertEqual(previousAtbat.outs, prevOuts)
        XCTAssertEqual(previousAtbat.inning, prevInning)
        XCTAssertEqual(previousAtbat.seq, prevSeq)
    }

    func testReplacementRowReceivesNextAtBatAndOutgoingRowRemainsHistoricalOnly() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        let outgoing = fixture.visitingFirst.player
        let incoming = insertBenchPlayer(name: "Jack Dreyer", number: "86", team: fixture.visitingTeam, game: game)
        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)
        completeFirstTurnForTwoBatters(fixture)
        try modelContext.save()

        let substitution = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(substitution.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)

        let replacementRow = try XCTUnwrap(game.atbats.first { $0.player.identifier == incoming.identifier && $0.col == 1 })
        let prepared = coordinator.prepareLiveGameState(
            game: game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher]
        )
        XCTAssertEqual(prepared.currentBatter?.identity, incoming.identifier)
        XCTAssertEqual(prepared.currentScorecardColumn, 2)
        XCTAssertNil(prepared.currentOrPendingLegacyAtbat)
        XCTAssertTrue(game.replaced.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(game.incomings.contains { $0.identifier == incoming.identifier })

        let rejectedOutgoing = coordinator.selectAtbat(
            column: 2,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(rejectedOutgoing.disposition, LiveScoringWorkflowCoordinator.Disposition.validationFailed)
        XCTAssertEqual(rejectedOutgoing.renderedTarget?.renderedRowIdentity, replacementRow.ident)
        XCTAssertEqual(rejectedOutgoing.renderedTarget?.column, 2)

        let historicalOutgoing = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(historicalOutgoing.disposition, LiveScoringWorkflowCoordinator.Disposition.noChange)
        XCTAssertEqual(historicalOutgoing.atbat?.ident, fixture.visitingFirst.ident)

        let selectedReplacement = coordinator.selectAtbat(
            column: 2,
            rowIndex: 1,
            sourceAtbat: replacementRow,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(selectedReplacement.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        let replacementAtbat = try XCTUnwrap(selectedReplacement.atbat)
        XCTAssertEqual(replacementAtbat.player.identifier, incoming.identifier)
        XCTAssertEqual(replacementAtbat.col, 2)

        let submission = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: replacementAtbat,
            game: game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try modelContext.save() }
        )
        XCTAssertEqual(submission.disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted)
        XCTAssertEqual(replacementAtbat.result, "Single")
        XCTAssertEqual(fixture.visitingFirst.player.identifier, outgoing.identifier)
        XCTAssertEqual(fixture.visitingFirst.result, "Ground Out")
    }

    func testStarterScorecardCellEligibilityRemainsCurrentOrCompletedOnly() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)
        try modelContext.save()

        let initialPresentation = enabledPresentation(
            fixture: fixture,
            pitcher: pitcher,
            displayedAtbats: teamAtbats(fixture)
        )
        XCTAssertTrue(initialPresentation.scorecardCellState(column: 1, sourceAtbat: fixture.visitingFirst, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(initialPresentation.scorecardCellState(column: 1, sourceAtbat: fixture.visitingSecond, displayedAtbats: teamAtbats(fixture)).isEnabled)

        let nonCurrentSelection = coordinator.selectAtbat(
            column: 1,
            rowIndex: 1,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: teamAtbats(fixture),
            game: fixture.game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(nonCurrentSelection.disposition, LiveScoringWorkflowCoordinator.Disposition.validationFailed)
        XCTAssertEqual(nonCurrentSelection.message, "That is not the current at-bat. You may edit completed at-bats or score the next open at-bat.")

        fixture.visitingFirst.result = "Ground Out"
        fixture.visitingFirst.outs = 1
        try modelContext.save()

        let afterCompletedPresentation = enabledPresentation(
            fixture: fixture,
            pitcher: pitcher,
            displayedAtbats: teamAtbats(fixture)
        )
        XCTAssertTrue(afterCompletedPresentation.scorecardCellState(column: 1, sourceAtbat: fixture.visitingFirst, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(afterCompletedPresentation.scorecardCellState(column: 1, sourceAtbat: fixture.visitingSecond, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(afterCompletedPresentation.scorecardCellState(column: 2, sourceAtbat: fixture.visitingFirst, displayedAtbats: teamAtbats(fixture)).isEnabled)
    }

    func testMissingPitcherValidationRemainsReachableFromScorecardSelection() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        try modelContext.save()

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: []
        )
        let semantic = coordinator.semanticScoreState(
            preparedState: prepared,
            displayedAtbats: teamAtbats(fixture)
        )
        let actionSet = coordinator.enabledScoringActions(
            preparedState: prepared,
            semanticScoreState: semantic,
            displayedAtbats: teamAtbats(fixture),
            supportedLegacyResults: ["Single", "Ground Out"]
        )
        let presentation = LiveScoringShellPresentation().presentEnabledActionSet(actionSet)

        XCTAssertEqual(prepared.disposition, LiveScoringWorkflowCoordinator.PreparedStateDisposition.unavailablePitcher)
        XCTAssertTrue(presentation.scorecardCellState(column: 1, sourceAtbat: fixture.visitingFirst, displayedAtbats: teamAtbats(fixture)).isEnabled)

        let selection = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: teamAtbats(fixture),
            game: fixture.game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(selection.disposition, LiveScoringWorkflowCoordinator.Disposition.validationFailed)
        XCTAssertEqual(selection.message, "Select the starting pitcher before scoring the game.")
    }

    func testReplacementEnteringFourthInningKeepsEarlierMarkersTappableButRejectedAndAllowsCurrentEntryCell() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        let outgoing = fixture.visitingFirst.player
        let incoming = insertBenchPlayer(name: "Fourth Inning Replacement", number: "86", team: fixture.visitingTeam, game: game)
        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)
        completeThreeInningsForTwoBatters(fixture)
        try modelContext.save()

        let substitution = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(substitution.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)

        let replacementRow = try XCTUnwrap(game.atbats.first { $0.player.identifier == incoming.identifier && $0.col == 1 })
        let presentation = enabledPresentation(
            fixture: fixture,
            pitcher: pitcher,
            displayedAtbats: teamAtbats(fixture)
        )

        XCTAssertTrue(presentation.scorecardCellState(column: 1, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(presentation.scorecardCellState(column: 2, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(presentation.scorecardCellState(column: 3, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(presentation.scorecardCellState(column: 4, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)

        let rejectedMarker = coordinator.selectAtbat(
            column: 1,
            rowIndex: 1,
            sourceAtbat: replacementRow,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(rejectedMarker.disposition, LiveScoringWorkflowCoordinator.Disposition.validationFailed)
        XCTAssertEqual(rejectedMarker.message, "That is not the current at-bat. You may edit completed at-bats or score the next open at-bat.")

        let selectedReplacement = coordinator.selectAtbat(
            column: 4,
            rowIndex: 1,
            sourceAtbat: replacementRow,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(selectedReplacement.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        let replacementAtbat = try XCTUnwrap(selectedReplacement.atbat)

        let submission = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: replacementAtbat,
            game: game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try modelContext.save() }
        )
        XCTAssertEqual(submission.disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted)

        let completedSelection = coordinator.selectAtbat(
            column: 4,
            rowIndex: 1,
            sourceAtbat: replacementRow,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(completedSelection.disposition, LiveScoringWorkflowCoordinator.Disposition.noChange)
        XCTAssertEqual(completedSelection.atbat?.ident, replacementAtbat.ident)

        let afterCompletedPresentation = enabledPresentation(
            fixture: fixture,
            pitcher: pitcher,
            displayedAtbats: teamAtbats(fixture)
        )
        XCTAssertTrue(afterCompletedPresentation.scorecardCellState(column: 2, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(afterCompletedPresentation.scorecardCellState(column: 5, sourceAtbat: replacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
    }

    func testReplacementRemainsActiveThroughTurnoverAndSecondReplacementMarkersStayTappable() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        let outgoing = fixture.visitingFirst.player
        let firstIncoming = insertBenchPlayer(name: "First Replacement", number: "86", team: fixture.visitingTeam, game: game)
        let secondIncoming = insertBenchPlayer(name: "Second Replacement", number: "87", team: fixture.visitingTeam, game: game)
        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)
        completeFirstTurnForTwoBatters(fixture)
        try modelContext.save()

        let firstSubstitution = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: firstIncoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(firstSubstitution.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        let firstReplacementRow = try XCTUnwrap(game.atbats.first { $0.player.identifier == firstIncoming.identifier && $0.col == 1 })
        let firstReplacementSelection = coordinator.selectAtbat(
            column: 2,
            rowIndex: 1,
            sourceAtbat: firstReplacementRow,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        let firstReplacementAtbat = try XCTUnwrap(firstReplacementSelection.atbat)
        XCTAssertEqual(firstReplacementSelection.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(coordinator.submitScoringAction(legacyResult: "Single", targetAtbat: firstReplacementAtbat, game: game, battingTeam: fixture.visitingTeam, displayedAtbats: teamAtbats(fixture), pitchers: [pitcher], supportedLegacyResults: ["Single", "Ground Out"], save: { try modelContext.save() }).disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted)

        let secondRowSelection = coordinator.selectAtbat(
            column: 2,
            rowIndex: 2,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: teamAtbats(fixture),
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        let secondAtbat = try XCTUnwrap(secondRowSelection.atbat)
        XCTAssertEqual(secondRowSelection.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(coordinator.submitScoringAction(legacyResult: "Ground Out", targetAtbat: secondAtbat, game: game, battingTeam: fixture.visitingTeam, displayedAtbats: teamAtbats(fixture), pitchers: [pitcher], supportedLegacyResults: ["Single", "Ground Out"], save: { try modelContext.save() }).disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted)

        let turnover = coordinator.prepareLiveGameState(
            game: game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher]
        )
        XCTAssertEqual(turnover.currentBatter?.identity, firstIncoming.identifier)
        XCTAssertEqual(turnover.currentScorecardColumn, 3)

        let secondSubstitution = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: firstIncoming.identifier,
            incomingParticipant: secondIncoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        XCTAssertEqual(secondSubstitution.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)

        let afterSecondSubstitution = coordinator.prepareLiveGameState(
            game: game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [pitcher]
        )
        XCTAssertEqual(afterSecondSubstitution.currentBatter?.identity, secondIncoming.identifier)
        XCTAssertNotEqual(afterSecondSubstitution.currentBatter?.identity, outgoing.identifier)
        XCTAssertNotEqual(afterSecondSubstitution.currentBatter?.identity, firstIncoming.identifier)

        let secondReplacementRow = try XCTUnwrap(game.atbats.first { $0.player.identifier == secondIncoming.identifier && $0.col == 1 })
        let presentation = enabledPresentation(
            fixture: fixture,
            pitcher: pitcher,
            displayedAtbats: teamAtbats(fixture)
        )
        XCTAssertTrue(presentation.scorecardCellState(column: 1, sourceAtbat: secondReplacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(presentation.scorecardCellState(column: 2, sourceAtbat: secondReplacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
        XCTAssertTrue(presentation.scorecardCellState(column: 3, sourceAtbat: secondReplacementRow, displayedAtbats: teamAtbats(fixture)).isEnabled)
    }

    func testPitcherChange_Accepted() throws {
        // Setup using Fixture
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game

        let incomingPitcher = Player(name: "Incoming Pitcher", number: "99", position: "P", batDir: "R", batOrder: 99)
        incomingPitcher.team = fixture.homeTeam
        modelContext.insert(incomingPitcher)
        game.players.append(incomingPitcher)

        let existingPitcher = Fixture.insertPitcher(for: fixture, into: modelContext)

        try modelContext.save()

        // Act
        let result = coordinator.submitPitcherChange(
            gameIdentity: game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: incomingPitcher.identifier,
            startInning: 3,
            startOuts: 1,
            startBatters: 0,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [existingPitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )

        // Assert
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        XCTAssertNotNil(result.refreshedState)

        let savedPitcher = game.pitchers.first { $0.player.identifier == incomingPitcher.identifier }
        XCTAssertNotNil(savedPitcher)
        XCTAssertEqual(savedPitcher?.startInn, 3)
        XCTAssertEqual(savedPitcher?.sOuts, 1)
        XCTAssertEqual(savedPitcher?.player.identifier, incomingPitcher.identifier)

        // Ensure earlier plays are not altered by verifying they still exist and are correct
        XCTAssertEqual(fixture.visitingFirst.result, "Result")
        XCTAssertEqual(fixture.visitingSecond.result, "Result")
    }

    func testStartingPitcherChangeWithZeroStartAutofillsAndRefreshesCurrentPitcher() throws {
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        try modelContext.save()

        let result = coordinator.submitPitcherChange(
            gameIdentity: game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: fixture.homePitcher.identifier,
            startInning: 0,
            startOuts: 0,
            startBatters: 0,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        let savedPitcher = try XCTUnwrap(game.pitchers.first { $0.player.identifier == fixture.homePitcher.identifier })
        XCTAssertEqual(savedPitcher.startInn, 1)
        XCTAssertEqual(savedPitcher.sOuts, 0)
        XCTAssertEqual(savedPitcher.sBats, 0)
        XCTAssertEqual(savedPitcher.endInn, 1)
        XCTAssertEqual(result.refreshedState?.currentPitcher?.player.identity, fixture.homePitcher.identifier)
        XCTAssertEqual(result.refreshedState?.pitcherAppearances.count, 1)
    }

    func testReliefPitcherChangeAfterScoringBeginsPersistsRefreshesProjectionAndClearsReview() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReliefPitcherChangeRegression-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-ReliefPitcherChange", url: url)
        var fileContainer: ModelContainer? = try ModelContainer(for: schema, configurations: [configuration])
        var fileContext: ModelContext? = ModelContext(fileContainer!)

        let fixture = Fixture.insertGame(into: fileContext!)
        let starterResult = coordinator.submitPitcherChange(
            gameIdentity: fixture.game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: fixture.homePitcher.identifier,
            startInning: 0,
            startOuts: 0,
            startBatters: 0,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: fileContext!,
            save: { try fileContext!.save() }
        )
        XCTAssertEqual(starterResult.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        let starter = try XCTUnwrap(fixture.game.pitchers.first { $0.player.identifier == fixture.homePitcher.identifier })

        let scoringResult = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: fixture.game.pitchers,
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try fileContext!.save() }
        )
        XCTAssertEqual(scoringResult.disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted)
        XCTAssertEqual(fixture.visitingFirst.result, "Single")

        let reliefPitcher = Player(name: "Relief Pitcher", number: "44", position: "RP", batDir: "R", batOrder: 99)
        reliefPitcher.team = fixture.homeTeam
        fileContext!.insert(reliefPitcher)
        fixture.homeTeam.players.append(reliefPitcher)
        fixture.game.players.append(reliefPitcher)
        try fileContext!.save()

        let presenter = LiveScoringShellPresentation()
        var reviewState: LiveScoringShellPresentation.PitcherChangeReviewState? = presenter.preparePitcherChangeReview(
            gameIdentity: fixture.game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: reliefPitcher.identifier,
            startInning: 0,
            startOuts: 0,
            startBatters: 0,
            summaryIncomingName: reliefPitcher.name
        )

        let presentation = presenter.confirmPitcherChangeReview(&reviewState) { gameId, teamId, incomingId, startInning, startOuts, startBatters in
            self.coordinator.submitPitcherChange(
                gameIdentity: gameId,
                teamIdentity: teamId,
                incomingPitcherIdentity: incomingId,
                startInning: startInning,
                startOuts: startOuts,
                startBatters: startBatters,
                displayedAtbats: fixture.displayedAtbats,
                pitchers: [starter],
                modelContext: fileContext!,
                save: { try fileContext!.save() }
            )
        }

        XCTAssertEqual(presentation.outcome, LiveScoringShellPresentation.SubstitutionReviewOutcome.accepted)
        XCTAssertTrue(presentation.shouldClearPendingReview)
        XCTAssertTrue(presentation.shouldMarkChanged)
        XCTAssertNil(reviewState)

        let relief = try XCTUnwrap(fixture.game.pitchers.first { $0.player.identifier == reliefPitcher.identifier })
        XCTAssertEqual(starter.endInn, 1)
        XCTAssertEqual(starter.eOuts, 0)
        XCTAssertEqual(starter.eBats, 1)
        XCTAssertEqual(relief.startInn, 1)
        XCTAssertEqual(relief.sOuts, 0)
        XCTAssertEqual(relief.sBats, 1)
        XCTAssertEqual(relief.endInn, 1)
        XCTAssertEqual(relief.eOuts, 0)
        XCTAssertEqual(relief.eBats, 1)
        XCTAssertEqual(fixture.game.pitchers.count, 2)
        XCTAssertEqual(presentation.refreshedState?.currentPitcher?.player.identity, reliefPitcher.identifier)
        XCTAssertEqual(presentation.refreshedState?.pitcherAppearances.map(\.player.identity), [fixture.homePitcher.identifier, reliefPitcher.identifier])

        let refreshed = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: fixture.game.pitchers
        )
        XCTAssertEqual(refreshed.disposition, LiveScoringWorkflowCoordinator.PreparedStateDisposition.ready)
        XCTAssertEqual(refreshed.currentPitcher?.player.identity, reliefPitcher.identifier)
        XCTAssertEqual(refreshed.pitcherAppearances.count, 2)

        let gameIdentity = fixture.game.ident
        let reliefIdentity = reliefPitcher.identifier
        fileContext = nil
        fileContainer = nil

        let reloadedContainer = try ModelContainer(for: schema, configurations: [configuration])
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try XCTUnwrap(try reloadedContext.fetch(FetchDescriptor<Game>()).first { $0.ident == gameIdentity })
        let reloadedPitchers = try reloadedContext.fetch(FetchDescriptor<Pitcher>())
        let reloadedRelief = try XCTUnwrap(reloadedPitchers.first { $0.player.identifier == reliefIdentity })
        XCTAssertEqual(reloadedRelief.startInn, 1)
        XCTAssertEqual(reloadedRelief.sBats, 1)

        let reloadedPrepared = coordinator.prepareLiveGameState(
            game: reloadedGame,
            battingTeam: reloadedGame.vteam,
            displayedAtbats: reloadedGame.atbats.filter { $0.team.ident == reloadedGame.vteam?.ident },
            pitchers: reloadedPitchers
        )
        XCTAssertEqual(reloadedPrepared.disposition, LiveScoringWorkflowCoordinator.PreparedStateDisposition.ready)
        XCTAssertEqual(reloadedPrepared.currentPitcher?.player.identity, reliefIdentity)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testReliefPitcherChangeMidInningUsesExactCurrentBoundaryForOutgoingAndIncomingPitchers() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReliefPitcherBoundaryRegression-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-ReliefPitcherBoundary", url: url)
        var fileContainer: ModelContainer? = try ModelContainer(for: schema, configurations: [configuration])
        var fileContext: ModelContext? = ModelContext(fileContainer!)

        let fixture = Fixture.insertGame(into: fileContext!)
        fixture.visitingFirst.result = "Ground Out"
        fixture.visitingFirst.inning = 3
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.col = 3
        fixture.visitingFirst.outs = 1
        fixture.visitingSecond.result = "Ground Out"
        fixture.visitingSecond.inning = 3
        fixture.visitingSecond.seq = 2
        fixture.visitingSecond.col = 3
        fixture.visitingSecond.outs = 2

        let starter = Pitcher(
            player: fixture.homePitcher,
            team: fixture.homeTeam,
            game: fixture.game,
            startInn: 1,
            sOuts: 0,
            sBats: 0,
            endInn: 3,
            eOuts: 0,
            eBats: 0
        )
        fileContext!.insert(starter)
        fixture.game.pitchers.append(starter)

        let reliefPitcher = Player(name: "Mid Inning Relief", number: "55", position: "RP", batDir: "R", batOrder: 99)
        reliefPitcher.team = fixture.homeTeam
        fileContext!.insert(reliefPitcher)
        fixture.homeTeam.players.append(reliefPitcher)
        fixture.game.players.append(reliefPitcher)
        try fileContext!.save()

        let result = coordinator.submitPitcherChange(
            gameIdentity: fixture.game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: reliefPitcher.identifier,
            startInning: 0,
            startOuts: 0,
            startBatters: 0,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [starter],
            modelContext: fileContext!,
            save: { try fileContext!.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        let relief = try XCTUnwrap(fixture.game.pitchers.first { $0.player.identifier == reliefPitcher.identifier })
        XCTAssertEqual(starter.endInn, 3)
        XCTAssertEqual(starter.eOuts, 2)
        XCTAssertEqual(starter.eBats, 2)
        XCTAssertEqual(relief.startInn, 3)
        XCTAssertEqual(relief.sOuts, 2)
        XCTAssertEqual(relief.sBats, 2)
        XCTAssertEqual(relief.endInn, 3)
        XCTAssertEqual(relief.eOuts, 2)
        XCTAssertEqual(relief.eBats, 2)

        let gameIdentity = fixture.game.ident
        let starterIdentity = fixture.homePitcher.identifier
        let reliefIdentity = reliefPitcher.identifier
        fileContext = nil
        fileContainer = nil

        let reloadedContainer = try ModelContainer(for: schema, configurations: [configuration])
        let reloadedContext = ModelContext(reloadedContainer)
        _ = try XCTUnwrap(try reloadedContext.fetch(FetchDescriptor<Game>()).first { $0.ident == gameIdentity })
        let reloadedPitchers = try reloadedContext.fetch(FetchDescriptor<Pitcher>())
        let reloadedStarter = try XCTUnwrap(reloadedPitchers.first { $0.player.identifier == starterIdentity })
        let reloadedRelief = try XCTUnwrap(reloadedPitchers.first { $0.player.identifier == reliefIdentity })
        XCTAssertEqual(reloadedStarter.endInn, 3)
        XCTAssertEqual(reloadedStarter.eOuts, 2)
        XCTAssertEqual(reloadedStarter.eBats, 2)
        XCTAssertEqual(reloadedRelief.startInn, 3)
        XCTAssertEqual(reloadedRelief.sOuts, 2)
        XCTAssertEqual(reloadedRelief.sBats, 2)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testBatterSubstitution_RollbackOnFailure() throws {
        // Setup using Fixture
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game
        let outgoing = fixture.visitingFirst.player

        let incoming = Player(name: "Incoming", number: "2", position: "2B", batDir: "L", batOrder: 99)
        incoming.team = fixture.visitingTeam
        modelContext.insert(incoming)
        game.players.append(incoming)

        let pitcher = Fixture.insertPitcher(for: fixture, into: modelContext)

        // Capture previous atbat data for verification
        let previousAtbat = fixture.visitingFirst
        let prevResult = previousAtbat.result
        let prevOuts = previousAtbat.outs
        let prevInning = previousAtbat.inning
        let prevSeq = previousAtbat.seq

        try modelContext.save()

        let originalReplacedCount = game.replaced.count
        let originalIncomingsCount = game.incomings.count
        let originalAtbatsCount = game.atbats.count
        let originalOutgoingBatOrder = outgoing.batOrder
        let originalIncomingBatOrder = incoming.batOrder
        let originalSecondPlayerBatOrder = fixture.visitingSecond.player.batOrder

        // Act - force failure
        let result = coordinator.submitSubstitution(
            gameIdentity: game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            modelContext: modelContext,
            save: { throw NSError(domain: "TestError", code: 1, userInfo: nil) }
        )

        // Assert
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.persistenceFailed)

        // Verify rollback
        XCTAssertEqual(game.replaced.count, originalReplacedCount)
        XCTAssertEqual(game.incomings.count, originalIncomingsCount)
        XCTAssertEqual(game.replaced.count, game.incomings.count, "Parallel arrays remain paired")
        XCTAssertFalse(game.replaced.contains(where: { $0.identifier == outgoing.identifier }))
        XCTAssertFalse(game.incomings.contains(where: { $0.identifier == incoming.identifier }))

        XCTAssertEqual(game.atbats.count, originalAtbatsCount)
        XCTAssertEqual(outgoing.batOrder, originalOutgoingBatOrder)
        XCTAssertEqual(incoming.batOrder, originalIncomingBatOrder)
        XCTAssertEqual(fixture.visitingSecond.player.batOrder, originalSecondPlayerBatOrder)

        let placeholder = game.atbats.first { $0.result == "Pitch Hitter" }
        XCTAssertNil(placeholder)

        // Verify earlier completed at-bats remain unchanged
        XCTAssertEqual(previousAtbat.player.identifier, outgoing.identifier)
        XCTAssertEqual(previousAtbat.result, prevResult)
        XCTAssertEqual(previousAtbat.outs, prevOuts)
        XCTAssertEqual(previousAtbat.inning, prevInning)
        XCTAssertEqual(previousAtbat.seq, prevSeq)
    }

    func testPitcherChange_RollbackOnFailure() throws {
        // Setup using Fixture
        let fixture = Fixture.insertGame(into: modelContext)
        let game = fixture.game

        let incomingPitcher = Player(name: "Incoming Pitcher", number: "99", position: "P", batDir: "R", batOrder: 99)
        incomingPitcher.team = fixture.homeTeam
        modelContext.insert(incomingPitcher)
        game.players.append(incomingPitcher)

        let existingPitcher = Fixture.insertPitcher(for: fixture, into: modelContext)
        let originalStartInn = existingPitcher.startInn
        let originalEndInn = existingPitcher.endInn

        try modelContext.save()

        let originalPitcherCount = game.pitchers.count

        // Act
        let result = coordinator.submitPitcherChange(
            gameIdentity: game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: incomingPitcher.identifier,
            startInning: 3,
            startOuts: 1,
            startBatters: 0,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [existingPitcher],
            modelContext: modelContext,
            save: { throw NSError(domain: "TestError", code: 1, userInfo: nil) }
        )

        // Assert
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.persistenceFailed)

        // Verify rollback
        XCTAssertEqual(game.pitchers.count, originalPitcherCount)
        XCTAssertFalse(game.pitchers.contains(where: { $0.player.identifier == incomingPitcher.identifier }))

        // Verify earlier pitcher participation and responsibility remain unchanged
        XCTAssertEqual(existingPitcher.startInn, originalStartInn)
        XCTAssertEqual(existingPitcher.endInn, originalEndInn)

        // Verify unrelated players and at-bats remain unchanged
        XCTAssertEqual(fixture.visitingFirst.result, "Result")
        XCTAssertEqual(fixture.visitingSecond.result, "Result")
    }

    private func insertBenchPlayer(name: String, number: String, team: Team, game: Game) -> Player {
        let player = Player(name: name, number: number, position: "PH", batDir: "L", batOrder: 99)
        player.team = team
        modelContext.insert(player)
        team.players.append(player)
        game.players.append(player)
        return player
    }

    private func completeFirstTurnForTwoBatters(_ fixture: Fixture) {
        fixture.visitingFirst.result = "Ground Out"
        fixture.visitingFirst.inning = 1
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.col = 1
        fixture.visitingFirst.outs = 1
        fixture.visitingSecond.result = "Ground Out"
        fixture.visitingSecond.inning = 1
        fixture.visitingSecond.seq = 2
        fixture.visitingSecond.col = 1
        fixture.visitingSecond.outs = 2
    }

    private func completeThreeInningsForTwoBatters(_ fixture: Fixture) {
        completeFirstTurnForTwoBatters(fixture)
        _ = insertScoredAtbat(fixture, source: fixture.visitingFirst, column: 2, inning: 2, sequence: 3, outs: 1)
        _ = insertScoredAtbat(fixture, source: fixture.visitingSecond, column: 2, inning: 2, sequence: 4, outs: 2)
        _ = insertScoredAtbat(fixture, source: fixture.visitingFirst, column: 3, inning: 3, sequence: 5, outs: 1)
        _ = insertScoredAtbat(fixture, source: fixture.visitingSecond, column: 3, inning: 3, sequence: 6, outs: 3, endOfInning: true)
    }

    private func insertScoredAtbat(
        _ fixture: Fixture,
        source: Atbat,
        column: Int,
        inning: CGFloat,
        sequence: Int,
        outs: Int,
        endOfInning: Bool = false
    ) -> Atbat {
        let atbat = Atbat(
            game: fixture.game,
            team: fixture.visitingTeam,
            player: source.player,
            result: "Ground Out",
            maxbase: "No Bases",
            batOrder: source.player.batOrder,
            outAt: "Safe",
            inning: inning,
            seq: sequence,
            col: column,
            rbis: 0,
            outs: outs,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0,
            endOfInning: endOfInning
        )
        modelContext.insert(atbat)
        fixture.game.atbats.append(atbat)
        return atbat
    }

    private func enabledPresentation(
        fixture: Fixture,
        pitcher: Pitcher,
        displayedAtbats: [Atbat]
    ) -> LiveScoringShellPresentation.EnabledActionSetPresentation {
        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: [pitcher]
        )
        let semantic = coordinator.semanticScoreState(
            preparedState: prepared,
            displayedAtbats: displayedAtbats
        )
        let actionSet = coordinator.enabledScoringActions(
            preparedState: prepared,
            semanticScoreState: semantic,
            displayedAtbats: displayedAtbats,
            supportedLegacyResults: ["Single", "Ground Out"]
        )
        return LiveScoringShellPresentation().presentEnabledActionSet(actionSet)
    }

    private func teamAtbats(_ fixture: Fixture) -> [Atbat] {
        fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident }
    }
}

private struct Fixture {
    let game: Game
    let visitingTeam: Team
    let homeTeam: Team
    let visitingFirst: Atbat
    let visitingSecond: Atbat
    let homePitcher: Player

    var displayedAtbats: [Atbat] {
        [visitingFirst, visitingSecond]
    }

    static func insertGame(
        into context: ModelContext,
        location: String = "Task 5.12 Field",
        everyOneHits: Bool = false,
        numInnings: Int = 9
    ) -> Fixture {
        let visitingTeam = Team(name: "Visitors", coach: "", details: "")
        let homeTeam = Team(name: "Home", coach: "", details: "")
        let visitingFirstPlayer = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let visitingSecondPlayer = Player(name: "Visitor Two", number: "2", position: "2B", batDir: "R", batOrder: 2, team: visitingTeam)
        let homePitcher = Player(name: "Home Pitcher", number: "9", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let game = Game(
            date: "2026-07-19T12:00:00Z",
            location: location,
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyOneHits,
            numInnings: numInnings,
            vteam: visitingTeam,
            hteam: homeTeam
        )
        let visitingFirst = Atbat(
            game: game,
            team: visitingTeam,
            player: visitingFirstPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 1,
            outAt: "Safe",
            inning: 1,
            seq: 1,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let visitingSecond = Atbat(
            game: game,
            team: visitingTeam,
            player: visitingSecondPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 2,
            outAt: "Safe",
            inning: 1,
            seq: 2,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(visitingFirstPlayer)
        context.insert(visitingSecondPlayer)
        context.insert(homePitcher)
        context.insert(game)
        context.insert(visitingFirst)
        context.insert(visitingSecond)

        visitingTeam.players = [visitingFirstPlayer, visitingSecondPlayer]
        homeTeam.players = [homePitcher]
        game.players = [visitingFirstPlayer, visitingSecondPlayer, homePitcher]
        game.atbats = [visitingFirst, visitingSecond]

        return Fixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingFirst: visitingFirst,
            visitingSecond: visitingSecond,
            homePitcher: homePitcher
        )
    }

    static func insertPitcher(for fixture: Fixture, into context: ModelContext) -> Pitcher {
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        return pitcher
    }
}
