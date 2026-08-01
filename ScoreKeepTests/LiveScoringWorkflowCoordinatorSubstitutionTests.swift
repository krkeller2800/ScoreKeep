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
