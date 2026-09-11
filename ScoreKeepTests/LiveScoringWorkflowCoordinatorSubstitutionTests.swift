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

        XCTAssertEqual(incoming.batOrder, 99)
        XCTAssertEqual(fixture.visitingSecond.player.batOrder, 2)

        // Check the newly created placeholder
        let placeholder = game.atbats.last { $0.result == "Pitch Hitter" }
        XCTAssertNotNil(placeholder)
        XCTAssertEqual(placeholder?.player.identifier, incoming.identifier)
        XCTAssertEqual(placeholder?.batOrder, fixture.visitingFirst.batOrder)
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

    func testSlotFourSubstitutionUsesGameSlotAndKeepsTeamRosterOrder() throws {
        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 9)
        let outgoing = fixture.visitingPlayers[3]
        let incoming = fixture.visitingPlayers[9]
        let originalOrders = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        completeSlotsThroughFour(fixture)
        try modelContext.save()

        let result = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            modelContext: modelContext,
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }), originalOrders)
        XCTAssertTrue(fixture.game.replaced.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(fixture.game.incomings.contains { $0.identifier == incoming.identifier })

        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == incoming.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == outgoing.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == incoming.identifier })

        let incomingRow = try XCTUnwrap(fixture.game.atbats.first { $0.player.identifier == incoming.identifier && $0.col == 1 })
        XCTAssertEqual(incomingRow.batOrder, 4)
        XCTAssertEqual(
            GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
                .filter { $0.batOrder == 4 }
                .map { $0.player.identifier },
            [outgoing.identifier, incoming.identifier]
        )
        XCTAssertEqual(result.refreshedState?.currentBatter?.identity, fixture.visitingPlayers[4].identifier)
        XCTAssertEqual(result.refreshedState?.battingOrderPosition, 5)
    }

    func testReplacingReplacementPreservesSlotHistoryAndAvailability() throws {
        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 9)
        let starter = fixture.visitingPlayers[3]
        let firstIncoming = fixture.visitingPlayers[9]
        let secondIncoming = fixture.visitingPlayers[10]
        let originalOrders = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        completeSlotsThroughFour(fixture)
        try modelContext.save()

        XCTAssertEqual(coordinator.submitSubstitution(gameIdentity: fixture.game.ident, outgoingParticipant: starter.identifier, incomingParticipant: firstIncoming.identifier, displayedAtbats: fixture.displayedAtbats, pitchers: [fixture.currentPitcher], modelContext: modelContext, save: { try modelContext.save() }).disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        XCTAssertEqual(coordinator.submitSubstitution(gameIdentity: fixture.game.ident, outgoingParticipant: firstIncoming.identifier, incomingParticipant: secondIncoming.identifier, displayedAtbats: fixture.displayedAtbats, pitchers: [fixture.currentPitcher], modelContext: modelContext, save: { try modelContext.save() }).disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)

        XCTAssertEqual(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }), originalOrders)
        XCTAssertTrue(fixture.game.replaced.contains { $0.identifier == starter.identifier })
        XCTAssertTrue(fixture.game.replaced.contains { $0.identifier == firstIncoming.identifier })
        XCTAssertTrue(fixture.game.incomings.contains { $0.identifier == firstIncoming.identifier })
        XCTAssertTrue(fixture.game.incomings.contains { $0.identifier == secondIncoming.identifier })

        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == starter.identifier })
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == firstIncoming.identifier })
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == secondIncoming.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == starter.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == firstIncoming.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == secondIncoming.identifier })

        XCTAssertEqual(
            GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
                .filter { $0.batOrder == 4 }
                .map { $0.player.identifier },
            [starter.identifier, firstIncoming.identifier, secondIncoming.identifier]
        )
        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: [fixture.currentPitcher]
        )
        XCTAssertEqual(prepared.currentBatter?.identity, fixture.visitingPlayers[4].identifier)
        XCTAssertEqual(prepared.battingOrderPosition, 5)
    }

    func testEveryoneHitsBeyondNineClassifiesEveryMaterializedPlayerAsActive() throws {
        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 12, everyOneHits: true)

        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )

        XCTAssertEqual(participation.activePlayers.map(\.identifier), fixture.visitingPlayers.map(\.identifier))
        XCTAssertTrue(participation.availableReplacementPlayers.isEmpty)
    }

    func testPersistedReloadPreservesReplacementSlotAndEligibility() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReplacementSlotPersistence-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        var fileContainer: ModelContainer? = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-ReplacementSlotPersistence", url: url)]
        )
        var fileContext: ModelContext? = ModelContext(fileContainer!)

        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 9, into: fileContext!)
        let outgoing = fixture.visitingPlayers[3]
        let incoming = fixture.visitingPlayers[9]
        completeSlotsThroughFour(fixture)
        try fileContext!.save()

        let result = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            modelContext: fileContext!,
            save: { try fileContext!.save() }
        )
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted)
        try fileContext!.save()

        let gameID = fixture.game.ident
        let teamID = fixture.visitingTeam.ident
        let outgoingID = outgoing.identifier
        let incomingID = incoming.identifier
        fileContext = nil
        fileContainer = nil

        let reopenedContainer = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-ReplacementSlotPersistence-Reopen", url: url)]
        )
        let reopenedContext = ModelContext(reopenedContainer)
        let reopenedGame = try XCTUnwrap(try reopenedContext.fetch(FetchDescriptor<Game>()).first { $0.ident == gameID })
        let reopenedTeam = try XCTUnwrap([reopenedGame.vteam, reopenedGame.hteam].compactMap { $0 }.first { $0.ident == teamID })
        let reopenedPlayers = try reopenedContext.fetch(FetchDescriptor<Player>()).filter { $0.team?.ident == teamID }
        let reopenedPitchers = reopenedGame.pitchers.filter { $0.game.ident == reopenedGame.ident }
        let participation = GameLineupParticipation.snapshot(
            game: reopenedGame,
            team: reopenedTeam,
            rosterPlayers: reopenedPlayers
        )

        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == outgoingID })
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == incomingID })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == outgoingID })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == incomingID })
        XCTAssertEqual(
            GameLineupParticipation.firstColumnLineupRows(game: reopenedGame, team: reopenedTeam)
                .filter { $0.batOrder == 4 }
                .map { $0.player.identifier },
            [outgoingID, incomingID]
        )

        let prepared = coordinator.prepareLiveGameState(
            game: reopenedGame,
            battingTeam: reopenedTeam,
            displayedAtbats: reopenedGame.atbats.filter { $0.team.ident == teamID },
            pitchers: reopenedPitchers
        )
        XCTAssertEqual(prepared.currentBatter?.identity, reopenedPlayers.first { $0.batOrder == 5 }?.identifier)
        XCTAssertEqual(prepared.battingOrderPosition, 5)
    }

    func testConventionalFullGameSubstitutionScenarioSurvivesMultipleReloads() throws {
        let harness = try FileBackedSubstitutionHarness()
        defer { harness.cleanup() }

        var fixture = try harness.insertMaterializedRosterGame(playerCount: 12, activeRosterOrder: 1...12, everyoneHits: false)
        let originalOrders = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        let starterSlotFour = fixture.visitingPlayers[3]
        let firstSlotFourReplacement = fixture.visitingPlayers[9]
        let secondSlotFourReplacement = fixture.visitingPlayers[11]
        let slotSevenStarter = fixture.visitingPlayers[6]
        let slotSevenReplacement = fixture.visitingPlayers[10]
        let reliefPitcher = try harness.insertHomePitcherPlayer(name: "Relief Pitcher", number: "55", fixture: fixture)

        try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        try scoreCurrentAtBat(in: fixture, result: "Single")
        try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        try scoreCurrentAtBat(in: fixture, result: "Double")
        try submitBatterSubstitution(
            fixture: fixture,
            outgoing: starterSlotFour,
            incoming: firstSlotFourReplacement
        )
        try assertParticipation(
            fixture: fixture,
            slot: 4,
            expectedHistory: [starterSlotFour, firstSlotFourReplacement],
            expectedCurrent: firstSlotFourReplacement,
            unavailable: [starterSlotFour, firstSlotFourReplacement],
            available: [slotSevenReplacement, secondSlotFourReplacement]
        )

        fixture = try harness.reloadFixture(gameID: fixture.game.ident, teamID: fixture.visitingTeam.ident)
        try assertParticipation(
            fixture: fixture,
            slot: 4,
            expectedHistoryIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier],
            expectedCurrentID: firstSlotFourReplacement.identifier,
            unavailableIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier],
            availableIDs: [slotSevenReplacement.identifier, secondSlotFourReplacement.identifier]
        )

        try scoreCurrentAtBat(in: fixture, result: "Fly Out")
        try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        try scoreCurrentAtBat(in: fixture, result: "Single")
        try scoreCurrentAtBat(in: fixture, result: "Strikeout")
        try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        try scoreCurrentAtBat(in: fixture, result: "Single")
        try submitBatterSubstitution(
            fixture: fixture,
            outgoing: slotSevenStarter,
            incoming: slotSevenReplacement
        )
        try submitPitcherChange(fixture: fixture, incomingPitcher: reliefPitcher)

        fixture = try harness.reloadFixture(gameID: fixture.game.ident, teamID: fixture.visitingTeam.ident)
        try assertParticipation(
            fixture: fixture,
            slot: 4,
            expectedHistoryIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier],
            expectedCurrentID: firstSlotFourReplacement.identifier,
            unavailableIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier, slotSevenStarter.identifier, slotSevenReplacement.identifier],
            availableIDs: [secondSlotFourReplacement.identifier]
        )
        try assertParticipation(
            fixture: fixture,
            slot: 7,
            expectedHistoryIDs: [slotSevenStarter.identifier, slotSevenReplacement.identifier],
            expectedCurrentID: slotSevenReplacement.identifier,
            unavailableIDs: [slotSevenStarter.identifier, slotSevenReplacement.identifier],
            availableIDs: [secondSlotFourReplacement.identifier]
        )

        let reloadedFirstReplacement = try XCTUnwrap(fixture.visitingPlayers.first { $0.identifier == firstSlotFourReplacement.identifier })
        let reloadedSecondReplacement = try XCTUnwrap(fixture.visitingPlayers.first { $0.identifier == secondSlotFourReplacement.identifier })
        try submitBatterSubstitution(
            fixture: fixture,
            outgoing: reloadedFirstReplacement,
            incoming: reloadedSecondReplacement
        )
        try assertParticipation(
            fixture: fixture,
            slot: 4,
            expectedHistoryIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier, secondSlotFourReplacement.identifier],
            expectedCurrentID: secondSlotFourReplacement.identifier,
            unavailableIDs: [starterSlotFour.identifier, firstSlotFourReplacement.identifier, secondSlotFourReplacement.identifier],
            availableIDs: []
        )
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }), originalOrders)

        for _ in 0..<10 {
            try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        }

        fixture = try harness.reloadFixture(gameID: fixture.game.ident, teamID: fixture.visitingTeam.ident)
        let prepared = preparedState(for: fixture)
        XCTAssertEqual(prepared.disposition, LiveScoringWorkflowCoordinator.PreparedStateDisposition.ready)
        XCTAssertEqual(prepared.currentPitcher?.player.identity, reliefPitcher.identifier)
        XCTAssertNotEqual(prepared.currentBatter?.identity, starterSlotFour.identifier)
        XCTAssertNotEqual(prepared.currentBatter?.identity, firstSlotFourReplacement.identifier)
        XCTAssertFalse(GameLineupParticipation.snapshot(game: fixture.game, team: fixture.visitingTeam, rosterPlayers: fixture.visitingPlayers).availableReplacementPlayers.contains { $0.identifier == starterSlotFour.identifier })
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }), originalOrders)
    }

    func testEveryoneHitsFullGameSubstitutionScenarioKeepsSlotsBeyondNineActiveAfterReload() throws {
        let harness = try FileBackedSubstitutionHarness()
        defer { harness.cleanup() }

        var fixture = try harness.insertMaterializedRosterGame(playerCount: 13, activeRosterOrder: 1...12, everyoneHits: true)
        let slotElevenStarter = fixture.visitingPlayers[10]
        let slotElevenReplacement = fixture.visitingPlayers[12]

        for _ in 0..<11 {
            try scoreCurrentAtBat(in: fixture, result: "Single")
        }

        try submitBatterSubstitution(
            fixture: fixture,
            outgoing: slotElevenStarter,
            incoming: slotElevenReplacement
        )
        try assertParticipation(
            fixture: fixture,
            slot: 11,
            expectedHistory: [slotElevenStarter, slotElevenReplacement],
            expectedCurrent: slotElevenReplacement,
            unavailable: [slotElevenStarter, slotElevenReplacement],
            available: []
        )

        fixture = try harness.reloadFixture(gameID: fixture.game.ident, teamID: fixture.visitingTeam.ident)
        let participation = GameLineupParticipation.snapshot(game: fixture.game, team: fixture.visitingTeam, rosterPlayers: fixture.visitingPlayers)
        XCTAssertEqual(participation.activePlayers.count, 12)
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == slotElevenReplacement.identifier })
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == slotElevenStarter.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == slotElevenStarter.identifier })
        XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == slotElevenReplacement.identifier })
        XCTAssertEqual(preparedState(for: fixture).battingOrderPosition, 12)
    }

    func testSlotOneCorrectionBeforeFirstPlateAppearanceCreatesNoReplacementHistory() throws {
        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 9)
        let outgoing = fixture.visitingPlayers[0]
        let incoming = fixture.visitingPlayers[9]

        _ = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 1,
            to: incoming,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: modelContext
        )

        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)
        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == incoming.identifier })
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(participation.availableReplacementPlayers.contains { $0.identifier == outgoing.identifier })
    }

    func testSlotNineCorrectionBeforeFirstPlateAppearanceCreatesNoReplacementHistory() throws {
        let fixture = insertFullRosterGame(playerCount: 12, materializedSlots: 9)
        let outgoing = fixture.visitingPlayers[8]
        let incoming = fixture.visitingPlayers[9]

        _ = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 9,
            to: incoming,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: modelContext
        )

        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)
        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == incoming.identifier })
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(participation.availableReplacementPlayers.contains { $0.identifier == outgoing.identifier })
    }

    func testEveryoneHitsSlotBeyondNineCorrectionBeforeFirstPlateAppearanceCreatesNoReplacementHistory() throws {
        let fixture = insertFullRosterGame(playerCount: 13, materializedSlots: 12, everyOneHits: true)
        let outgoing = fixture.visitingPlayers[10]
        let incoming = fixture.visitingPlayers[12]

        _ = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 11,
            to: incoming,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: modelContext
        )

        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)
        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        XCTAssertEqual(participation.activePlayers.count, 12)
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == incoming.identifier })
        XCTAssertFalse(participation.activePlayers.contains { $0.identifier == outgoing.identifier })
        XCTAssertTrue(participation.availableReplacementPlayers.contains { $0.identifier == outgoing.identifier })
    }

    func testSlotsBecomeSubstitutionEligibleAfterCompletingFirstPlateAppearance() throws {
        try assertSlotBecomesSubstitutionEligibleAfterFirstPlateAppearance(slot: 1, activeSlots: 9, playerCount: 12, everyoneHits: false)
        try assertSlotBecomesSubstitutionEligibleAfterFirstPlateAppearance(slot: 9, activeSlots: 9, playerCount: 12, everyoneHits: false)
        try assertSlotBecomesSubstitutionEligibleAfterFirstPlateAppearance(slot: 11, activeSlots: 12, playerCount: 13, everyoneHits: true)
    }

    func testCorrectionBeforeFirstTripAndLaterSubstitutionSurviveReload() throws {
        let harness = try FileBackedSubstitutionHarness()
        defer { harness.cleanup() }
        var fixture = try harness.insertMaterializedRosterGame(
            playerCount: 12,
            activeRosterOrder: 1...9,
            everyoneHits: false
        )
        let correctedOut = fixture.visitingPlayers[8]
        let correctedIn = fixture.visitingPlayers[9]
        let laterIncoming = fixture.visitingPlayers[10]

        _ = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 9,
            to: correctedIn,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: fixture.context
        )
        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)

        fixture = try reloadStressFixture(harness: harness, fixture: fixture)
        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)
        XCTAssertTrue(GameLineupParticipation.snapshot(game: fixture.game, team: fixture.visitingTeam, rosterPlayers: fixture.visitingPlayers).availableReplacementPlayers.contains { $0.identifier == correctedOut.identifier })

        for _ in 0..<9 {
            try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        }
        let reloadedCorrectedIn = try player(with: correctedIn.identifier, in: fixture)
        let reloadedLaterIncoming = try player(with: laterIncoming.identifier, in: fixture)
        try submitBatterSubstitution(fixture: fixture, outgoing: reloadedCorrectedIn, incoming: reloadedLaterIncoming)

        fixture = try reloadStressFixture(harness: harness, fixture: fixture)
        try assertParticipation(
            fixture: fixture,
            slot: 9,
            expectedHistoryIDs: [correctedIn.identifier, laterIncoming.identifier],
            expectedCurrentID: laterIncoming.identifier,
            unavailableIDs: [correctedIn.identifier, laterIncoming.identifier],
            availableIDs: [correctedOut.identifier]
        )
    }

    func testDeterministicSubstitutionStressBenchmark20CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "benchmark20",
            gameCount: 20,
            seed: 0x5C0A_EE20,
            persistenceStride: 10
        )
        XCTAssertEqual(summary.completedGames, 20)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay200CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay200",
            gameCount: 200,
            seed: 0x5C0A_EE20,
            persistenceStride: 25
        )
        XCTAssertEqual(summary.completedGames, 200)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay500Chunk0CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay500_chunk0",
            gameCount: 100,
            seed: 0x5C0A_EE20,
            persistenceStride: 25,
            startIndex: 0
        )
        XCTAssertEqual(summary.completedGames, 100)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay500Chunk1CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay500_chunk1",
            gameCount: 100,
            seed: 0x5C0A_EE20,
            persistenceStride: 25,
            startIndex: 100
        )
        XCTAssertEqual(summary.completedGames, 100)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay500Chunk2CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay500_chunk2",
            gameCount: 100,
            seed: 0x5C0A_EE20,
            persistenceStride: 25,
            startIndex: 200
        )
        XCTAssertEqual(summary.completedGames, 100)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay500Chunk3CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay500_chunk3",
            gameCount: 100,
            seed: 0x5C0A_EE20,
            persistenceStride: 25,
            startIndex: 300
        )
        XCTAssertEqual(summary.completedGames, 100)
        print(summary.reportLine)
    }

    func testDeterministicSubstitutionStressReplay500Chunk4CompleteGames() throws {
        let summary = try runDeterministicSubstitutionStress(
            label: "replay500_chunk4",
            gameCount: 100,
            seed: 0x5C0A_EE20,
            persistenceStride: 25,
            startIndex: 400
        )
        XCTAssertEqual(summary.completedGames, 100)
        print(summary.reportLine)
    }

    func testCapturedScenario35FirstTripSlotFourSubstitutionIsRejected() throws {
        let fixture = try insertMaterializedRosterGame(
            playerCount: 13,
            activeRosterOrder: 1...9,
            everyoneHits: false,
            numInnings: 6,
            into: modelContext
        )
        for _ in 0..<2 {
            try scoreCurrentAtBat(in: fixture, result: "Ground Out")
        }
        let outgoing = fixture.visitingPlayers[3]
        let incoming = fixture.visitingPlayers[9]

        let result = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.duplicateOrConflicting)
        XCTAssertEqual(result.message, "This batting slot has not completed its first plate appearance. Use lineup correction before the first trip through the order.")
        XCTAssertTrue(fixture.game.replaced.isEmpty)
        XCTAssertTrue(fixture.game.incomings.isEmpty)
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

    func testLivePitcherBoundaryAdvancesAfterOneMidInningOut() throws {
        let fixture = insertPitcherBoundaryGame(
            completedOuts: 2,
            currentPitcherStartInning: 1,
            currentPitcherStartOuts: 1,
            currentPitcherStartBatters: 1
        )

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.battingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher]
        )
        let result = coordinator.refreshProjections(
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            game: fixture.game,
            maintainPitcherMarkers: coordinator.shouldMaintainPitcherMarkers(preparedState: prepared),
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(fixture.currentPitcher.startInn, 1)
        XCTAssertEqual(fixture.currentPitcher.sOuts, 1)
        XCTAssertEqual(fixture.currentPitcher.sBats, 1)
        XCTAssertEqual(fixture.currentPitcher.endInn, 1)
        XCTAssertEqual(fixture.currentPitcher.eOuts, 2)
        XCTAssertEqual(fixture.currentPitcher.eBats, 2)
        XCTAssertEqual(ScoreKeep.PitchingInningsCalculator.recordedOuts(for: fixture.currentPitcher), 1)
    }

    func testLivePitcherBoundaryAdvancesWhenMidInningPitcherRecordsInningEndingOut() throws {
        let fixture = insertPitcherBoundaryGame(
            completedOuts: 3,
            currentPitcherStartInning: 1,
            currentPitcherStartOuts: 2,
            currentPitcherStartBatters: 2
        )
        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.battingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher]
        )

        XCTAssertNil(prepared.currentOrPendingLegacyAtbat)
        XCTAssertFalse(coordinator.shouldMaintainPitcherMarkers(preparedState: prepared))
        XCTAssertTrue(coordinator.shouldMaintainPitcherMarkers(preparedState: prepared, afterScoringSubmission: true))

        let result = coordinator.refreshProjections(
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            game: fixture.game,
            maintainPitcherMarkers: coordinator.shouldMaintainPitcherMarkers(preparedState: prepared, afterScoringSubmission: true),
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(fixture.currentPitcher.endInn, 2)
        XCTAssertEqual(fixture.currentPitcher.eOuts, 0)
        XCTAssertEqual(fixture.currentPitcher.eBats, 0)
        XCTAssertEqual(ScoreKeep.PitchingInningsCalculator.recordedOuts(for: fixture.currentPitcher), 1)
        XCTAssertEqual(ScoreKeep.PitchingInningsCalculator.displayString(fromOuts: ScoreKeep.PitchingInningsCalculator.recordedOuts(for: fixture.currentPitcher)), "⅓")
    }

    func testLivePitcherBoundaryAdvancesWhenPitcherRecordsTwoOutsToFinishInning() throws {
        let fixture = insertPitcherBoundaryGame(
            completedOuts: 21,
            currentPitcherStartInning: 7,
            currentPitcherStartOuts: 1,
            currentPitcherStartBatters: 1,
            initialCurrentPitcherEndInning: 7,
            initialCurrentPitcherEndOuts: 2,
            initialCurrentPitcherEndBatters: 2
        )
        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.battingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher]
        )

        XCTAssertNil(prepared.currentOrPendingLegacyAtbat)

        let result = coordinator.refreshProjections(
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            game: fixture.game,
            maintainPitcherMarkers: coordinator.shouldMaintainPitcherMarkers(preparedState: prepared, afterScoringSubmission: true),
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(fixture.currentPitcher.startInn, 7)
        XCTAssertEqual(fixture.currentPitcher.sOuts, 1)
        XCTAssertEqual(fixture.currentPitcher.sBats, 1)
        XCTAssertEqual(fixture.currentPitcher.endInn, 8)
        XCTAssertEqual(fixture.currentPitcher.eOuts, 0)
        XCTAssertEqual(fixture.currentPitcher.eBats, 0)
        let recordedOuts = ScoreKeep.PitchingInningsCalculator.recordedOuts(for: fixture.currentPitcher)
        XCTAssertEqual(recordedOuts, 2)
        XCTAssertEqual(ScoreKeep.PitchingInningsCalculator.displayString(fromOuts: recordedOuts), "⅔")
    }

    func testLivePitcherBoundaryAdvancesAfterCompleteFullInning() throws {
        let fixture = insertPitcherBoundaryGame(
            completedOuts: 3,
            currentPitcherStartInning: 1,
            currentPitcherStartOuts: 0,
            currentPitcherStartBatters: 0
        )
        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.battingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher]
        )
        let result = coordinator.refreshProjections(
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [fixture.currentPitcher],
            game: fixture.game,
            maintainPitcherMarkers: coordinator.shouldMaintainPitcherMarkers(preparedState: prepared, afterScoringSubmission: true),
            save: { try modelContext.save() }
        )

        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.Disposition.success)
        XCTAssertEqual(fixture.currentPitcher.endInn, 2)
        XCTAssertEqual(fixture.currentPitcher.eOuts, 0)
        XCTAssertEqual(fixture.currentPitcher.eBats, 0)
        XCTAssertEqual(ScoreKeep.PitchingInningsCalculator.recordedOuts(for: fixture.currentPitcher), 3)
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

    private func runDeterministicSubstitutionStress(
        label: String,
        gameCount: Int,
        seed: UInt64,
        persistenceStride: Int,
        startIndex: Int = 0
    ) throws -> SubstitutionStressRunSummary {
        let start = Date()
        var summary = SubstitutionStressRunSummary(label: label, seed: seed)
        let endIndex = startIndex + gameCount
        for index in startIndex..<endIndex {
            var generator = DeterministicGenerator(seed: seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15)
            let scenario = SubstitutionStressScenario(index: index, generator: &generator)
            let usesPersistence = persistenceStride > 0 && (index % persistenceStride == 0 || index == endIndex - 1)
            do {
                let result = try runSubstitutionStressScenario(scenario, usesPersistence: usesPersistence)
                summary.record(result)
            } catch {
                summary.elapsedSeconds = Date().timeIntervalSince(start)
                print("\(summary.reportLine) failedAtIndex=\(index) scenario=\"\(scenario.reproductionDescription)\"")
                XCTFail("Substitution stress failed for \(scenario.reproductionDescription): \(error)")
                throw error
            }
        }
        summary.elapsedSeconds = Date().timeIntervalSince(start)
        return summary
    }

    private func assertSlotBecomesSubstitutionEligibleAfterFirstPlateAppearance(
        slot: Int,
        activeSlots: Int,
        playerCount: Int,
        everyoneHits: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let fixture = insertFullRosterGame(playerCount: playerCount, materializedSlots: activeSlots, everyOneHits: everyoneHits)
        let outgoing = fixture.visitingPlayers[slot - 1]
        let incoming = fixture.visitingPlayers[activeSlots]

        let premature = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        XCTAssertEqual(premature.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.duplicateOrConflicting, file: file, line: line)
        XCTAssertTrue(fixture.game.replaced.isEmpty, file: file, line: line)
        XCTAssertTrue(fixture.game.incomings.isEmpty, file: file, line: line)

        for _ in 0..<slot {
            try scoreCurrentAtBat(in: fixture, result: "Ground Out", file: file, line: line)
        }
        XCTAssertTrue(GameLineupParticipation.hasCompletedFirstPlateAppearance(slot: slot, game: fixture.game, team: fixture.visitingTeam), file: file, line: line)

        let accepted = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        XCTAssertEqual(accepted.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted, accepted.message ?? "", file: file, line: line)
        XCTAssertTrue(fixture.game.replaced.contains { $0.identifier == outgoing.identifier }, file: file, line: line)
        XCTAssertTrue(fixture.game.incomings.contains { $0.identifier == incoming.identifier }, file: file, line: line)
        try assertParticipation(
            fixture: fixture,
            slot: slot,
            expectedHistoryIDs: [outgoing.identifier, incoming.identifier],
            expectedCurrentID: incoming.identifier,
            unavailableIDs: [outgoing.identifier, incoming.identifier],
            availableIDs: [],
            file: file,
            line: line
        )
    }

    private func runSubstitutionStressScenario(
        _ scenario: SubstitutionStressScenario,
        usesPersistence: Bool
    ) throws -> SubstitutionStressScenarioResult {
        let harness = usesPersistence ? try FileBackedSubstitutionHarness() : nil
        defer { harness?.cleanup() }

        var fixture = try harness?.insertMaterializedRosterGame(
            playerCount: scenario.rosterSize,
            activeRosterOrder: 1...scenario.activeSlotCount,
            everyoneHits: scenario.everyoneHits,
            numInnings: scenario.targetOuts / 3
        ) ?? insertMaterializedRosterGame(
            playerCount: scenario.rosterSize,
            activeRosterOrder: 1...scenario.activeSlotCount,
            everyoneHits: scenario.everyoneHits,
            numInnings: scenario.targetOuts / 3,
            into: modelContext
        )
        let originalOrders = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        let reliefPitchers = try (1...2).map { number in
            try insertHomePitcherPlayer(
                name: "Stress Relief \(scenario.index)-\(number)",
                number: "\(90 + number)",
                fixture: fixture
            )
        }
        var state = SubstitutionStressGameState(
            scenario: scenario,
            originalOrders: originalOrders,
            activeSlotOccupants: Dictionary(uniqueKeysWithValues: (1...scenario.activeSlotCount).map { slot in
                (slot, fixture.visitingPlayers[slot - 1].identifier)
            }),
            slotHistories: Dictionary(uniqueKeysWithValues: (1...scenario.activeSlotCount).map { slot in
                (slot, [fixture.visitingPlayers[slot - 1].identifier])
            }),
            availableBenchIDs: Array(fixture.visitingPlayers.dropFirst(scenario.activeSlotCount).map(\.identifier)),
            reliefPitcherIDs: reliefPitchers.map(\.identifier),
            currentPitcherID: fixture.homePitcher.identifier
        )

        try validateStressInvariants(fixture: fixture, state: state, phase: "initial")
        var plateAppearance = 0
        var substitutionIndex = 0
        var pitcherChangeIndex = 0
        var reloadCount = 0
        let reloadPlateAppearances = Set(scenario.reloadPlateAppearances)

        while state.recordedOuts < scenario.targetOuts {
            while substitutionIndex < scenario.substitutions.count &&
                    scenario.substitutions[substitutionIndex].plateAppearance == plateAppearance {
                try performStressSubstitution(
                    fixture: fixture,
                    state: &state,
                    event: scenario.substitutions[substitutionIndex],
                    phase: "pa\(plateAppearance).sub\(substitutionIndex)"
                )
                substitutionIndex += 1
                if usesPersistence && reloadPlateAppearances.contains(plateAppearance) {
                    fixture = try reloadStressFixture(harness: harness, fixture: fixture)
                    reloadCount += 1
                    try validateStressInvariants(fixture: fixture, state: state, phase: "pa\(plateAppearance).reloadAfterSub")
                }
            }

            while pitcherChangeIndex < scenario.pitcherChanges.count &&
                    scenario.pitcherChanges[pitcherChangeIndex] == plateAppearance {
                let pitcherID = state.reliefPitcherIDs[pitcherChangeIndex % state.reliefPitcherIDs.count]
                let pitcher = try player(with: pitcherID, in: fixture)
                try submitPitcherChange(fixture: fixture, incomingPitcher: pitcher)
                state.currentPitcherID = pitcherID
                pitcherChangeIndex += 1
                try validateStressInvariants(fixture: fixture, state: state, phase: "pa\(plateAppearance).pitcher")
            }

            let scoringResult = scenario.result(forPlateAppearance: plateAppearance)
            let scored = try scoreStressCurrentAtBat(in: fixture, result: scoringResult, expectedState: state)
            state.lastScoredSlot = scored.slot
            if scored.recordedOut {
                state.recordedOuts += 1
            }
            plateAppearance += 1
            try validateStressInvariants(fixture: fixture, state: state, phase: "pa\(plateAppearance).score")

            if usesPersistence && reloadPlateAppearances.contains(plateAppearance) {
                fixture = try reloadStressFixture(harness: harness, fixture: fixture)
                reloadCount += 1
                try validateStressInvariants(fixture: fixture, state: state, phase: "pa\(plateAppearance).reload")
            }

            guard plateAppearance < scenario.maximumPlateAppearances else {
                throw SubstitutionStressFailure.invariant("Exceeded maximum plate appearances for \(scenario.reproductionDescription)")
            }
        }

        if usesPersistence {
            fixture = try reloadStressFixture(harness: harness, fixture: fixture)
            reloadCount += 1
        }
        try validateStressInvariants(fixture: fixture, state: state, phase: "completed")
        return SubstitutionStressScenarioResult(
            everyoneHits: scenario.everyoneHits,
            substitutions: scenario.substitutions.count,
            replacementOfReplacement: scenario.hasReplacementOfReplacement,
            pitcherChanges: scenario.pitcherChanges.count,
            usesPersistence: usesPersistence,
            reloads: reloadCount,
            plateAppearances: plateAppearance
        )
    }

    private func performStressSubstitution(
        fixture: FullRosterFixture,
        state: inout SubstitutionStressGameState,
        event: SubstitutionStressSubstitutionEvent,
        phase: String
    ) throws {
        let outgoingID = try XCTUnwrap(
            state.activeSlotOccupants[event.slot],
            "Missing active slot \(event.slot) for \(state.scenario.reproductionDescription) \(phase)"
        )
        let incomingID = try state.nextBenchPlayerID(for: event, phase: phase)
        let outgoing = try player(with: outgoingID, in: fixture)
        let incoming = try player(with: incomingID, in: fixture)
        try submitBatterSubstitution(fixture: fixture, outgoing: outgoing, incoming: incoming)
        state.slotHistories[event.slot, default: []].append(incomingID)
        state.activeSlotOccupants[event.slot] = incomingID
        state.usedOrReplacedIDs.insert(outgoingID)
        state.usedOrReplacedIDs.insert(incomingID)
        try validateStressInvariants(fixture: fixture, state: state, phase: phase)
    }

    private func scoreStressCurrentAtBat(
        in fixture: FullRosterFixture,
        result: String,
        expectedState: SubstitutionStressGameState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> StressScoredAtBat {
        let prepared = preparedState(for: fixture)
        guard prepared.disposition == .ready else {
            throw SubstitutionStressFailure.invariant("Prepared state was \(prepared.disposition) for \(expectedState.scenario.reproductionDescription)")
        }
        let currentSlot = try XCTUnwrap(prepared.battingOrderPosition, file: file, line: line)
        let expectedCurrentID = try XCTUnwrap(
            expectedState.activeSlotOccupants[currentSlot],
            "Prepared current slot \(currentSlot) is outside expected active slots for \(expectedState.scenario.reproductionDescription)",
            file: file,
            line: line
        )
        guard prepared.currentBatter?.identity == expectedCurrentID else {
            throw SubstitutionStressFailure.invariant("Current batter mismatch for \(expectedState.scenario.reproductionDescription): slot \(currentSlot)")
        }
        let currentSource = try XCTUnwrap(
            GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
                .last { $0.player.identifier == expectedCurrentID },
            file: file,
            line: line
        )
        let currentColumn = try XCTUnwrap(prepared.currentScorecardColumn, file: file, line: line)
        let selection = coordinator.selectAtbat(
            column: currentColumn,
            rowIndex: max(0, currentSlot - 1),
            sourceAtbat: currentSource,
            displayedAtbats: teamAtbats(fixture),
            game: fixture.game,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        guard selection.disposition == .success || selection.disposition == .noChange else {
            throw SubstitutionStressFailure.invariant("Selection failed for \(expectedState.scenario.reproductionDescription): \(selection.message ?? "no message")")
        }
        let target = try XCTUnwrap(selection.atbat, file: file, line: line)
        let submission = coordinator.submitScoringAction(
            legacyResult: result,
            targetAtbat: target,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            supportedLegacyResults: ["Single", "Double", "Ground Out", "Fly Out", "Strikeout"],
            save: { try fixture.context.save() }
        )
        guard submission.disposition == .accepted else {
            throw SubstitutionStressFailure.invariant("Scoring failed for \(expectedState.scenario.reproductionDescription): \(submission.message ?? "no message")")
        }
        return StressScoredAtBat(
            slot: currentSlot,
            playerID: expectedCurrentID,
            recordedOut: ["Ground Out", "Fly Out", "Strikeout"].contains(result)
        )
    }

    private func validateStressInvariants(
        fixture: FullRosterFixture,
        state: SubstitutionStressGameState,
        phase: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let context = "\(state.scenario.reproductionDescription) phase=\(phase)"
        let currentOrders = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        guard currentOrders == state.originalOrders else {
            throw SubstitutionStressFailure.invariant("Team Player.batOrder changed for \(context)")
        }
        guard fixture.game.replaced.count == fixture.game.incomings.count else {
            throw SubstitutionStressFailure.invariant("Substitution arrays unpaired for \(context)")
        }

        let rows = GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        let activeIDs = Set(participation.activePlayers.map(\.identifier))
        let availableIDs = Set(participation.availableReplacementPlayers.map(\.identifier))
        guard activeIDs == Set(state.activeSlotOccupants.values) else {
            throw SubstitutionStressFailure.invariant("Active lineup mismatch for \(context)")
        }
        guard activeIDs.count == state.scenario.activeSlotCount else {
            throw SubstitutionStressFailure.invariant("Active lineup count mismatch for \(context)")
        }

        for slot in 1...state.scenario.activeSlotCount {
            let expectedHistory = state.slotHistories[slot, default: []]
            let actualHistory = rows
                .filter { $0.batOrder == slot }
                .map { $0.player.identifier }
            guard actualHistory == expectedHistory else {
                throw SubstitutionStressFailure.invariant("Slot \(slot) history mismatch for \(context)")
            }
            if let activeID = state.activeSlotOccupants[slot] {
                guard activeIDs.contains(activeID) else {
                    throw SubstitutionStressFailure.invariant("Slot \(slot) active occupant missing for \(context)")
                }
            }
        }

        for playerID in state.usedOrReplacedIDs {
            guard availableIDs.contains(playerID) == false else {
                throw SubstitutionStressFailure.invariant("Used/replaced player became available for \(context)")
            }
        }

        let usedIncomingIDs = Set(fixture.game.incomings.map(\.identifier))
        for playerID in usedIncomingIDs {
            guard availableIDs.contains(playerID) == false else {
                throw SubstitutionStressFailure.invariant("Incoming player became available for \(context)")
            }
        }

        let prepared = preparedState(for: fixture)
        guard prepared.disposition == .ready else {
            throw SubstitutionStressFailure.invariant("Prepared state was \(prepared.disposition) for \(context)")
        }
        if let currentSlot = prepared.battingOrderPosition,
           let expectedCurrentID = state.activeSlotOccupants[currentSlot] {
            guard prepared.currentBatter?.identity == expectedCurrentID else {
                throw SubstitutionStressFailure.invariant("Current batter mismatch for \(context)")
            }
        } else {
            throw SubstitutionStressFailure.invariant("Current batter slot unavailable for \(context)")
        }
        guard prepared.currentPitcher?.player.identity == state.currentPitcherID else {
            throw SubstitutionStressFailure.invariant("Current pitcher mismatch for \(context): expected \(state.currentPitcherID), got \(String(describing: prepared.currentPitcher?.player.identity)); pitchers=\(pitcherDebugDescription(fixture.game.pitchers))")
        }
    }

    private func pitcherDebugDescription(_ pitchers: [Pitcher]) -> String {
        pitchers
            .map {
                "\($0.player.name)|id=\($0.player.identifier)|start=\($0.startInn).\($0.sOuts).\($0.sBats)|end=\($0.endInn).\($0.eOuts).\($0.eBats)"
            }
            .joined(separator: "; ")
    }

    private func reloadStressFixture(
        harness: FileBackedSubstitutionHarness?,
        fixture: FullRosterFixture
    ) throws -> FullRosterFixture {
        guard let harness else { return fixture }
        return try harness.reloadFixture(gameID: fixture.game.ident, teamID: fixture.visitingTeam.ident)
    }

    private func insertHomePitcherPlayer(name: String, number: String, fixture: FullRosterFixture) throws -> Player {
        let player = Player(name: name, number: number, position: "P", batDir: "R", batOrder: PlayerRosterBattingOrder.notHitting, team: fixture.homeTeam)
        fixture.context.insert(player)
        fixture.homeTeam.players.append(player)
        fixture.game.players.append(player)
        try fixture.context.save()
        return player
    }

    private func player(with identity: UUID, in fixture: FullRosterFixture) throws -> Player {
        try XCTUnwrap(fixture.visitingPlayers.first { $0.identifier == identity } ?? fixture.homeTeam.players.first { $0.identifier == identity })
    }

    private func scoreCurrentAtBat(
        in fixture: FullRosterFixture,
        result: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let prepared = preparedState(for: fixture)
        XCTAssertEqual(prepared.disposition, LiveScoringWorkflowCoordinator.PreparedStateDisposition.ready, file: file, line: line)
        let currentID = try XCTUnwrap(prepared.currentBatter?.identity, file: file, line: line)
        let currentColumn = try XCTUnwrap(prepared.currentScorecardColumn, file: file, line: line)
        let currentSource = try XCTUnwrap(
            GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
                .last { $0.player.identifier == currentID },
            file: file,
            line: line
        )
        let selection = coordinator.selectAtbat(
            column: currentColumn,
            rowIndex: max(0, currentSource.batOrder - 1),
            sourceAtbat: currentSource,
            displayedAtbats: teamAtbats(fixture),
            game: fixture.game,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        XCTAssertTrue(
            selection.disposition == LiveScoringWorkflowCoordinator.Disposition.success ||
            selection.disposition == LiveScoringWorkflowCoordinator.Disposition.noChange,
            selection.message ?? "Unexpected at-bat selection failure",
            file: file,
            line: line
        )
        let targetAtbat = try XCTUnwrap(selection.atbat, file: file, line: line)
        let submission = coordinator.submitScoringAction(
            legacyResult: result,
            targetAtbat: targetAtbat,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            supportedLegacyResults: ["Single", "Double", "Ground Out", "Fly Out", "Strikeout"],
            save: { try fixture.context.save() }
        )
        XCTAssertEqual(submission.disposition, LiveScoringWorkflowCoordinator.SubmissionDisposition.accepted, submission.message ?? "", file: file, line: line)
    }

    private func submitBatterSubstitution(
        fixture: FullRosterFixture,
        outgoing: Player,
        incoming: Player,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let result = coordinator.submitSubstitution(
            gameIdentity: fixture.game.ident,
            outgoingParticipant: outgoing.identifier,
            incomingParticipant: incoming.identifier,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted, result.message ?? "", file: file, line: line)
    }

    private func submitPitcherChange(
        fixture: FullRosterFixture,
        incomingPitcher: Player,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let result = coordinator.submitPitcherChange(
            gameIdentity: fixture.game.ident,
            teamIdentity: fixture.homeTeam.ident,
            incomingPitcherIdentity: incomingPitcher.identifier,
            startInning: 0,
            startOuts: 0,
            startBatters: 0,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers,
            modelContext: fixture.context,
            save: { try fixture.context.save() }
        )
        XCTAssertEqual(result.disposition, LiveScoringWorkflowCoordinator.SubstitutionDisposition.accepted, result.message ?? "", file: file, line: line)
        XCTAssertEqual(result.refreshedState?.currentPitcher?.player.identity, incomingPitcher.identifier, file: file, line: line)
    }

    private func preparedState(for fixture: FullRosterFixture) -> LiveScoringWorkflowCoordinator.PreparedLiveGameState {
        coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: teamAtbats(fixture),
            pitchers: fixture.game.pitchers
        )
    }

    private func assertParticipation(
        fixture: FullRosterFixture,
        slot: Int,
        expectedHistory: [Player],
        expectedCurrent: Player,
        unavailable: [Player],
        available: [Player],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertParticipation(
            fixture: fixture,
            slot: slot,
            expectedHistoryIDs: expectedHistory.map(\.identifier),
            expectedCurrentID: expectedCurrent.identifier,
            unavailableIDs: unavailable.map(\.identifier),
            availableIDs: available.map(\.identifier),
            file: file,
            line: line
        )
    }

    private func assertParticipation(
        fixture: FullRosterFixture,
        slot: Int,
        expectedHistoryIDs: [UUID],
        expectedCurrentID: UUID,
        unavailableIDs: [UUID],
        availableIDs: [UUID],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let participation = GameLineupParticipation.snapshot(
            game: fixture.game,
            team: fixture.visitingTeam,
            rosterPlayers: fixture.visitingPlayers
        )
        let history = GameLineupParticipation.firstColumnLineupRows(game: fixture.game, team: fixture.visitingTeam)
            .filter { $0.batOrder == slot }
            .map { $0.player.identifier }
        XCTAssertEqual(history, expectedHistoryIDs, file: file, line: line)
        XCTAssertTrue(participation.activePlayers.contains { $0.identifier == expectedCurrentID }, file: file, line: line)
        for playerID in expectedHistoryIDs where playerID != expectedCurrentID {
            XCTAssertFalse(participation.activePlayers.contains { $0.identifier == playerID }, file: file, line: line)
        }
        for playerID in unavailableIDs {
            XCTAssertFalse(participation.availableReplacementPlayers.contains { $0.identifier == playerID }, file: file, line: line)
        }
        for playerID in availableIDs {
            XCTAssertTrue(participation.availableReplacementPlayers.contains { $0.identifier == playerID }, file: file, line: line)
        }
    }

    private func insertFullRosterGame(
        playerCount: Int,
        materializedSlots: Int,
        everyOneHits: Bool = false,
        into context: ModelContext? = nil
    ) -> FullRosterFixture {
        let context = context ?? modelContext!
        let visitingTeam = Team(name: "Visitors \(UUID().uuidString)", coach: "", details: "")
        let homeTeam = Team(name: "Home \(UUID().uuidString)", coach: "", details: "")
        let visitingPlayers = (1...playerCount).map {
            Player(name: "Visitor \($0)", number: "\($0)", position: "P\($0)", batDir: "R", batOrder: $0, team: visitingTeam)
        }
        let homePitcher = Player(name: "Home Pitcher", number: "99", position: "P", batDir: "R", batOrder: 99, team: homeTeam)
        let game = Game(
            date: "2026-09-10T12:00:00Z",
            location: "Replacement Slot Park \(UUID().uuidString)",
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyOneHits,
            numInnings: 9,
            vteam: visitingTeam,
            hteam: homeTeam
        )
        let activePlayers = Array(visitingPlayers.prefix(materializedSlots))
        let lineup = Lineup(everyoneHits: everyOneHits, game: game, team: visitingTeam, inning: 1, players: activePlayers)
        let atbats = activePlayers.enumerated().map { index, player in
            Atbat(
                game: game,
                team: visitingTeam,
                player: player,
                result: "Result",
                maxbase: "No Bases",
                batOrder: index + 1,
                outAt: "Safe",
                inning: 1,
                seq: index + 1,
                col: 1,
                rbis: 0,
                outs: 0,
                sacFly: 0,
                sacBunt: 0,
                stolenBases: 0
            )
        }
        let pitcher = Pitcher(player: homePitcher, team: homeTeam, game: game, startInn: 1, endInn: 1)

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(homePitcher)
        context.insert(game)
        context.insert(lineup)
        context.insert(pitcher)
        visitingPlayers.forEach(context.insert)
        atbats.forEach(context.insert)
        visitingTeam.players = visitingPlayers
        homeTeam.players = [homePitcher]
        game.players = activePlayers + [homePitcher]
        game.lineups = [lineup]
        game.atbats = atbats
        game.pitchers = [pitcher]

        return FullRosterFixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingPlayers: visitingPlayers,
            homePitcher: homePitcher,
            currentPitcher: pitcher,
            displayedAtbats: atbats,
            context: context
        )
    }

    private func insertMaterializedRosterGame(
        playerCount: Int,
        activeRosterOrder: ClosedRange<Int>,
        everyoneHits: Bool,
        numInnings: Int,
        into context: ModelContext
    ) throws -> FullRosterFixture {
        let visitingTeam = Team(name: "Stress Visitors \(UUID().uuidString)", coach: "", details: "")
        let homeTeam = Team(name: "Stress Home \(UUID().uuidString)", coach: "", details: "")
        let visitingPlayers = (1...playerCount).map { index in
            Player(
                name: "Stress Visitor \(index)",
                number: "\(index)",
                position: "P\(index)",
                batDir: "R",
                batOrder: activeRosterOrder.contains(index) ? index : PlayerRosterBattingOrder.notHitting,
                team: visitingTeam
            )
        }
        let homePitcher = Player(name: "Stress Starter", number: "99", position: "P", batDir: "R", batOrder: PlayerRosterBattingOrder.notHitting, team: homeTeam)
        let game = Game(
            date: "2026-09-10T12:00:00Z",
            location: "Stress Park \(UUID().uuidString)",
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyoneHits,
            numInnings: numInnings,
            vteam: visitingTeam,
            hteam: homeTeam
        )
        let pitcher = Pitcher(player: homePitcher, team: homeTeam, game: game, startInn: 1, endInn: 1)

        context.insert(visitingTeam)
        context.insert(homeTeam)
        visitingPlayers.forEach(context.insert)
        context.insert(homePitcher)
        context.insert(game)
        context.insert(pitcher)
        visitingTeam.players = visitingPlayers
        homeTeam.players = [homePitcher]
        game.players = [homePitcher]
        game.pitchers = [pitcher]

        _ = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: game,
            team: visitingTeam,
            modelContext: context
        )
        try context.save()

        return FullRosterFixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingPlayers: visitingPlayers,
            homePitcher: homePitcher,
            currentPitcher: pitcher,
            displayedAtbats: game.atbats.filter { $0.team.ident == visitingTeam.ident },
            context: context
        )
    }

    private func completeSlotsThroughFour(_ fixture: FullRosterFixture) {
        for slot in 1...4 {
            if let atbat = fixture.game.atbats.first(where: { $0.batOrder == slot && $0.col == 1 }) {
                atbat.result = "Single"
                atbat.outs = 0
                atbat.inning = 1
                atbat.seq = slot
            }
        }
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

    private func teamAtbats(_ fixture: FullRosterFixture) -> [Atbat] {
        fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident }
    }

    private struct FullRosterFixture {
        let game: Game
        let visitingTeam: Team
        let homeTeam: Team
        let visitingPlayers: [Player]
        let homePitcher: Player
        let currentPitcher: Pitcher
        let displayedAtbats: [Atbat]
        let context: ModelContext
    }

    private struct DeterministicGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0xC0FF_EE00_0000_0001 : seed
        }

        mutating func nextInt(in range: Range<Int>) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let width = UInt64(range.upperBound - range.lowerBound)
            return range.lowerBound + Int((state >> 32) % width)
        }

        mutating func nextBool() -> Bool {
            nextInt(in: 0..<2) == 0
        }

        mutating func nextRawSeed(index: Int) -> UInt64 {
            state = state &* 2862933555777941757 &+ 3037000493 &+ UInt64(index)
            return state
        }
    }

    private struct SubstitutionStressSubstitutionEvent {
        let plateAppearance: Int
        let slot: Int
    }

    private struct SubstitutionStressScenario {
        let index: Int
        let seed: UInt64
        let everyoneHits: Bool
        let activeSlotCount: Int
        let rosterSize: Int
        let targetOuts: Int
        let maximumPlateAppearances: Int
        let substitutions: [SubstitutionStressSubstitutionEvent]
        let pitcherChanges: [Int]
        let reloadPlateAppearances: [Int]

        var hasReplacementOfReplacement: Bool {
            let slotCounts = Dictionary(grouping: substitutions, by: \.slot).mapValues(\.count)
            return slotCounts.values.contains { $0 > 1 }
        }

        var reproductionDescription: String {
            let substitutionSummary = substitutions
                .map { "pa\($0.plateAppearance):slot\($0.slot)" }
                .joined(separator: ",")
            let pitcherSummary = pitcherChanges
                .map { "pa\($0)" }
                .joined(separator: ",")
            let reloadSummary = reloadPlateAppearances
                .map { "pa\($0)" }
                .joined(separator: ",")
            return "seed=\(seed) index=\(index) everyoneHits=\(everyoneHits) activeSlots=\(activeSlotCount) rosterSize=\(rosterSize) substitutions=[\(substitutionSummary)] pitcherChanges=[\(pitcherSummary)] reloads=[\(reloadSummary)]"
        }

        init(index: Int, generator: inout DeterministicGenerator) {
            self.index = index
            seed = generator.nextRawSeed(index: index)
            everyoneHits = index % 3 == 1 || generator.nextBool()
            activeSlotCount = everyoneHits ? 10 + generator.nextInt(in: 0..<4) : 9
            rosterSize = activeSlotCount + 4
            targetOuts = 18
            maximumPlateAppearances = 80

            let slotA = 1 + generator.nextInt(in: 0..<activeSlotCount)
            var slotB = 1 + generator.nextInt(in: 0..<activeSlotCount)
            if slotB == slotA {
                slotB = (slotB % activeSlotCount) + 1
            }
            var slotC = 1 + generator.nextInt(in: 0..<activeSlotCount)
            if slotC == slotA || slotC == slotB {
                slotC = ((slotC + 1) % activeSlotCount) + 1
            }

            substitutions = [
                SubstitutionStressSubstitutionEvent(plateAppearance: slotA + generator.nextInt(in: 0..<3), slot: slotA),
                SubstitutionStressSubstitutionEvent(plateAppearance: activeSlotCount + generator.nextInt(in: 0..<4), slot: slotB),
                SubstitutionStressSubstitutionEvent(plateAppearance: activeSlotCount + 3 + generator.nextInt(in: 0..<4), slot: slotA),
                SubstitutionStressSubstitutionEvent(plateAppearance: (2 * activeSlotCount) + generator.nextInt(in: 0..<5), slot: slotC)
            ].sorted {
                if $0.plateAppearance != $1.plateAppearance {
                    return $0.plateAppearance < $1.plateAppearance
                }
                return $0.slot < $1.slot
            }
            pitcherChanges = [
                max(1, activeSlotCount / 2),
                activeSlotCount + 5 + generator.nextInt(in: 0..<3)
            ].sorted()
            reloadPlateAppearances = [
                substitutions[0].plateAppearance,
                substitutions[2].plateAppearance + 1,
                targetOuts + 2
            ]
        }

        func result(forPlateAppearance plateAppearance: Int) -> String {
            let pattern = (plateAppearance + index) % 9
            switch pattern {
            case 0, 3, 6: return "Ground Out"
            case 2, 7: return "Fly Out"
            case 5: return "Strikeout"
            case 1, 8: return "Single"
            default: return "Double"
            }
        }

        init(
            index: Int,
            seed: UInt64,
            everyoneHits: Bool,
            activeSlotCount: Int,
            rosterSize: Int,
            targetOuts: Int,
            maximumPlateAppearances: Int,
            substitutions: [SubstitutionStressSubstitutionEvent],
            pitcherChanges: [Int],
            reloadPlateAppearances: [Int]
        ) {
            self.index = index
            self.seed = seed
            self.everyoneHits = everyoneHits
            self.activeSlotCount = activeSlotCount
            self.rosterSize = rosterSize
            self.targetOuts = targetOuts
            self.maximumPlateAppearances = maximumPlateAppearances
            self.substitutions = substitutions
            self.pitcherChanges = pitcherChanges
            self.reloadPlateAppearances = reloadPlateAppearances
        }
    }

    private struct SubstitutionStressGameState {
        let scenario: SubstitutionStressScenario
        let originalOrders: [UUID: Int]
        var activeSlotOccupants: [Int: UUID]
        var slotHistories: [Int: [UUID]]
        var availableBenchIDs: [UUID]
        var reliefPitcherIDs: [UUID]
        var currentPitcherID: UUID
        var usedOrReplacedIDs: Set<UUID> = []
        var recordedOuts = 0
        var lastScoredSlot: Int?

        mutating func nextBenchPlayerID(
            for event: SubstitutionStressSubstitutionEvent,
            phase: String
        ) throws -> UUID {
            guard availableBenchIDs.isEmpty == false else {
                throw SubstitutionStressFailure.invariant("No bench player available for \(scenario.reproductionDescription) \(phase)")
            }
            return availableBenchIDs.removeFirst()
        }
    }

    private struct StressScoredAtBat {
        let slot: Int
        let playerID: UUID
        let recordedOut: Bool
    }

    private struct SubstitutionStressScenarioResult {
        let everyoneHits: Bool
        let substitutions: Int
        let replacementOfReplacement: Bool
        let pitcherChanges: Int
        let usesPersistence: Bool
        let reloads: Int
        let plateAppearances: Int
    }

    private struct SubstitutionStressRunSummary {
        let label: String
        let seed: UInt64
        var completedGames = 0
        var conventionalGames = 0
        var everyoneHitsGames = 0
        var persistenceGames = 0
        var reloads = 0
        var substitutions = 0
        var replacementOfReplacementGames = 0
        var pitcherChanges = 0
        var plateAppearances = 0
        var elapsedSeconds: TimeInterval = 0

        mutating func record(_ result: SubstitutionStressScenarioResult) {
            completedGames += 1
            if result.everyoneHits {
                everyoneHitsGames += 1
            } else {
                conventionalGames += 1
            }
            if result.usesPersistence {
                persistenceGames += 1
            }
            reloads += result.reloads
            substitutions += result.substitutions
            if result.replacementOfReplacement {
                replacementOfReplacementGames += 1
            }
            pitcherChanges += result.pitcherChanges
            plateAppearances += result.plateAppearances
        }

        var reportLine: String {
            String(
                format: "SUBSTITUTION_STRESS_SUMMARY label=%@ seed=%llu games=%d elapsed=%.3fs conventional=%d everyoneHits=%d persistenceGames=%d reloads=%d substitutions=%d replacementOfReplacementGames=%d pitcherChanges=%d plateAppearances=%d",
                label,
                seed,
                completedGames,
                elapsedSeconds,
                conventionalGames,
                everyoneHitsGames,
                persistenceGames,
                reloads,
                substitutions,
                replacementOfReplacementGames,
                pitcherChanges,
                plateAppearances
            )
        }
    }

    private enum SubstitutionStressFailure: Error, CustomStringConvertible {
        case invariant(String)

        var description: String {
            switch self {
            case .invariant(let message):
                return message
            }
        }
    }

    @MainActor
    private final class FileBackedSubstitutionHarness {
        private let url: URL
        private let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        private var container: ModelContainer?
        private(set) var context: ModelContext

        init() throws {
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SubstitutionScenario-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("Store.sqlite")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-Scenario", url: url)]
            )
            self.container = container
            context = ModelContext(container)
        }

        func cleanup() {
            container = nil
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }

        func insertMaterializedRosterGame(
            playerCount: Int,
            activeRosterOrder: ClosedRange<Int>,
            everyoneHits: Bool,
            numInnings: Int = 9
        ) throws -> FullRosterFixture {
            let visitingTeam = Team(name: "Scenario Visitors", coach: "", details: "")
            let homeTeam = Team(name: "Scenario Home", coach: "", details: "")
            let visitingPlayers = (1...playerCount).map { index in
                Player(
                    name: "Scenario Visitor \(index)",
                    number: "\(index)",
                    position: "P\(index)",
                    batDir: "R",
                    batOrder: activeRosterOrder.contains(index) ? index : PlayerRosterBattingOrder.notHitting,
                    team: visitingTeam
                )
            }
            let homePitcher = Player(name: "Scenario Starter", number: "99", position: "P", batDir: "R", batOrder: PlayerRosterBattingOrder.notHitting, team: homeTeam)
            let game = Game(
                date: "2026-09-10T12:00:00Z",
                location: "Scenario Park \(UUID().uuidString)",
                highLights: "",
                hscore: 0,
                vscore: 0,
                everyOneHits: everyoneHits,
                numInnings: numInnings,
                vteam: visitingTeam,
                hteam: homeTeam
            )
            let pitcher = Pitcher(player: homePitcher, team: homeTeam, game: game, startInn: 1, endInn: 1)

            context.insert(visitingTeam)
            context.insert(homeTeam)
            visitingPlayers.forEach(context.insert)
            context.insert(homePitcher)
            context.insert(game)
            context.insert(pitcher)
            visitingTeam.players = visitingPlayers
            homeTeam.players = [homePitcher]
            game.players = [homePitcher]
            game.pitchers = [pitcher]

            _ = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
                game: game,
                team: visitingTeam,
                modelContext: context
            )
            try context.save()

            return try makeFixture(game: game, teamID: visitingTeam.ident)
        }

        func insertHomePitcherPlayer(name: String, number: String, fixture: FullRosterFixture) throws -> Player {
            let player = Player(name: name, number: number, position: "P", batDir: "R", batOrder: PlayerRosterBattingOrder.notHitting, team: fixture.homeTeam)
            context.insert(player)
            fixture.homeTeam.players.append(player)
            fixture.game.players.append(player)
            try context.save()
            return player
        }

        func reloadFixture(gameID: UUID, teamID: UUID) throws -> FullRosterFixture {
            container = nil
            let reloadedContainer = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("LiveScoringWorkflowCoordinatorSubstitutionTests-Scenario-Reopen-\(UUID().uuidString)", url: url)]
            )
            container = reloadedContainer
            context = ModelContext(reloadedContainer)
            let game = try XCTUnwrap(try context.fetch(FetchDescriptor<Game>()).first { $0.ident == gameID })
            return try makeFixture(game: game, teamID: teamID)
        }

        private func makeFixture(game: Game, teamID: UUID) throws -> FullRosterFixture {
            let visitingTeam = try XCTUnwrap([game.vteam, game.hteam].compactMap { $0 }.first { $0.ident == teamID })
            let homeTeam = try XCTUnwrap([game.vteam, game.hteam].compactMap { $0 }.first { $0.ident != teamID })
            let visitingPlayers = try context.fetch(FetchDescriptor<Player>())
                .filter { $0.team?.ident == teamID }
                .sorted {
                    if $0.batOrder != $1.batOrder {
                        return $0.batOrder < $1.batOrder
                    }
                    return $0.number < $1.number
                }
            let homePitcher = try XCTUnwrap(homeTeam.players.first)
            let currentPitcher = try XCTUnwrap(game.pitchers.filter { $0.team.ident == homeTeam.ident }.last)
            return FullRosterFixture(
                game: game,
                visitingTeam: visitingTeam,
                homeTeam: homeTeam,
                visitingPlayers: visitingPlayers,
                homePitcher: homePitcher,
                currentPitcher: currentPitcher,
                displayedAtbats: game.atbats.filter { $0.team.ident == teamID },
                context: context
            )
        }
    }

    private struct PitcherBoundaryFixture {
        let game: Game
        let battingTeam: Team
        let currentPitcher: Pitcher
        let displayedAtbats: [Atbat]
    }

    private func insertPitcherBoundaryGame(
        completedOuts: Int,
        currentPitcherStartInning: Int,
        currentPitcherStartOuts: Int,
        currentPitcherStartBatters: Int,
        initialCurrentPitcherEndInning: Int = 0,
        initialCurrentPitcherEndOuts: Int = 0,
        initialCurrentPitcherEndBatters: Int = 0
    ) -> PitcherBoundaryFixture {
        let battingTeam = Team(name: "Guardians", coach: "", details: "")
        let pitchingTeam = Team(name: "Tigers", coach: "", details: "")
        let batters = [
            Player(name: "Batter One", number: "1", position: "CF", batDir: "L", batOrder: 1, team: battingTeam),
            Player(name: "Batter Two", number: "2", position: "SS", batDir: "R", batOrder: 2, team: battingTeam),
            Player(name: "Batter Three", number: "3", position: "1B", batDir: "L", batOrder: 3, team: battingTeam)
        ]
        let pitcherPlayer = Player(name: "Holton", number: "87", position: "P", batDir: "L", batOrder: 99, team: pitchingTeam)
        let game = Game(
            date: "2026-08-13T17:05:00Z",
            location: "Comerica",
            highLights: "",
            hscore: 2,
            vscore: 1,
            numInnings: 9,
            vteam: battingTeam,
            hteam: pitchingTeam
        )
        let currentPitcher = Pitcher(
            player: pitcherPlayer,
            team: pitchingTeam,
            game: game,
            startInn: currentPitcherStartInning,
            sOuts: currentPitcherStartOuts,
            sBats: currentPitcherStartBatters,
            endInn: initialCurrentPitcherEndInning,
            eOuts: initialCurrentPitcherEndOuts,
            eBats: initialCurrentPitcherEndBatters
        )
        let atbats = (1...completedOuts).map { outNumber in
            let inning = ((outNumber - 1) / 3) + 1
            let inningOut = outNumber % 3 == 0 ? 3 : outNumber % 3
            let batterIndex = (outNumber - 1) % batters.count
            return Atbat(
                game: game,
                team: battingTeam,
                player: batters[batterIndex],
                result: "Ground Out",
                maxbase: "No Bases",
                batOrder: batters[batterIndex].batOrder,
                outAt: "Safe",
                inning: CGFloat(inning),
                seq: batterIndex + 1,
                col: inning,
                rbis: 0,
                outs: inningOut,
                sacFly: 0,
                sacBunt: 0,
                stolenBases: 0,
                endOfInning: inningOut == 3
            )
        }

        modelContext.insert(battingTeam)
        modelContext.insert(pitchingTeam)
        batters.forEach(modelContext.insert)
        modelContext.insert(pitcherPlayer)
        modelContext.insert(game)
        modelContext.insert(currentPitcher)
        atbats.forEach(modelContext.insert)
        battingTeam.players = batters
        pitchingTeam.players = [pitcherPlayer]
        game.players = batters + [pitcherPlayer]
        game.atbats = atbats
        game.pitchers = [currentPitcher]

        return PitcherBoundaryFixture(
            game: game,
            battingTeam: battingTeam,
            currentPitcher: currentPitcher,
            displayedAtbats: atbats
        )
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
