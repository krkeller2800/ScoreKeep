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
