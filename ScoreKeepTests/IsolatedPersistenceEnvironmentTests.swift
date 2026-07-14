import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct IsolatedPersistenceEnvironmentTests {
    @Test("fresh isolated store starts empty")
    func freshIsolatedStoreStartsEmpty() throws {
        let environment = try IsolatedPersistenceEnvironment()

        #expect(try environment.fetch(FetchDescriptor<Game>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Team>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Atbat>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Lineup>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Pitcher>()).isEmpty)
    }

    @Test("inserted records can be saved and fetched")
    func insertedRecordsCanBeSavedAndFetched() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let graph = try insertSyntheticGameGraph(into: environment)

        try environment.save()

        let games = try environment.fetch(FetchDescriptor<Game>())
        let teams = try environment.fetch(FetchDescriptor<Team>())
        let players = try environment.fetch(FetchDescriptor<Player>())
        let atbats = try environment.fetch(FetchDescriptor<Atbat>())
        let lineups = try environment.fetch(FetchDescriptor<Lineup>())
        let pitchers = try environment.fetch(FetchDescriptor<Pitcher>())

        let fetchedGame = try #require(games.first)
        #expect(games.count == 1)
        #expect(teams.count == 2)
        #expect(players.count == 2)
        #expect(atbats.count == 1)
        #expect(lineups.count == 1)
        #expect(pitchers.count == 1)
        #expect(fetchedGame.ident == graph.gameID)
        #expect(fetchedGame.vteam?.ident == graph.visitingTeamID)
        #expect(fetchedGame.hteam?.ident == graph.homeTeamID)
        #expect(fetchedGame.atbats.first?.ident == graph.atbatID)
        #expect(fetchedGame.lineups.first?.ident == graph.lineupID)
        #expect(fetchedGame.pitchers.first?.ident == graph.pitcherID)
    }

    @Test("separate isolated stores do not share records")
    func separateIsolatedStoresDoNotShareRecords() throws {
        let firstEnvironment = try IsolatedPersistenceEnvironment()
        let secondEnvironment = try IsolatedPersistenceEnvironment()

        let team = Team(name: "Isolated Visitors", coach: "", details: "")
        firstEnvironment.context.insert(team)
        try firstEnvironment.save()

        #expect(try firstEnvironment.fetch(FetchDescriptor<Team>()).count == 1)
        #expect(try secondEnvironment.fetch(FetchDescriptor<Team>()).isEmpty)
    }

    @Test("test-created data can be deleted without affecting another isolated store")
    func testCreatedDataCanBeDeletedWithoutAffectingAnotherIsolatedStore() throws {
        let firstEnvironment = try IsolatedPersistenceEnvironment()
        let secondEnvironment = try IsolatedPersistenceEnvironment()

        let firstTeam = Team(name: "Delete Me", coach: "", details: "")
        let secondTeam = Team(name: "Keep Me", coach: "", details: "")
        firstEnvironment.context.insert(firstTeam)
        secondEnvironment.context.insert(secondTeam)
        try firstEnvironment.save()
        try secondEnvironment.save()

        let storedFirstTeam = try #require(try firstEnvironment.fetch(FetchDescriptor<Team>()).first)
        firstEnvironment.delete(storedFirstTeam)
        try firstEnvironment.save()

        #expect(try firstEnvironment.fetch(FetchDescriptor<Team>()).isEmpty)
        #expect(try secondEnvironment.fetch(FetchDescriptor<Team>()).map(\.name) == ["Keep Me"])
    }

    @Test("isolated store creation does not import the production seed")
    func isolatedStoreCreationDoesNotImportProductionSeed() throws {
        _ = try IsolatedPersistenceEnvironment.fixtureURL(relativePath: "ScoreKeep/Seed/seededGame.ScoreKeep_Games")
        let environment = try IsolatedPersistenceEnvironment()

        #expect(try environment.fetch(FetchDescriptor<Game>()).isEmpty)
    }

    @Test("curated roster fixture can be decoded without persistence writes")
    func curatedRosterFixtureCanBeDecodedWithoutPersistenceWrites() throws {
        let fixtureURL = try IsolatedPersistenceEnvironment.fixtureURL(
            relativePath: "ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/MinimalValid.ScoreKeep_Players"
        )
        let data = try Data(contentsOf: fixtureURL)
        let players = try JSONDecoder().decode([SharePlayer].self, from: data)
        let environment = try IsolatedPersistenceEnvironment()

        #expect(players.isEmpty == false)
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    private func insertSyntheticGameGraph(into environment: IsolatedPersistenceEnvironment) throws -> SyntheticGraphIDs {
        let visitingTeamID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let homeTeamID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let visitingPlayerID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000201"))
        let homePlayerID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000202"))
        let gameID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000301"))
        let atbatID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))
        let lineupID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000501"))
        let pitcherID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000601"))

        let visitingTeam = Team(ident: visitingTeamID, name: "Isolated Visitors", coach: "", details: "")
        let homeTeam = Team(ident: homeTeamID, name: "Isolated Home", coach: "", details: "")
        let visitingPlayer = Player(
            identifier: visitingPlayerID,
            name: "Visitor Batter",
            number: "7",
            position: "SS",
            batDir: "R",
            batOrder: 1,
            team: visitingTeam
        )
        let homePlayer = Player(
            identifier: homePlayerID,
            name: "Home Pitcher",
            number: "12",
            position: "P",
            batDir: "L",
            batOrder: 1,
            team: homeTeam
        )
        let game = Game(
            ident: gameID,
            date: "2026-07-14T12:00:00Z",
            location: "Isolated Test Field",
            highLights: "Synthetic test graph",
            hscore: 0,
            vscore: 0,
            everyOneHits: false,
            numInnings: 7,
            vteam: visitingTeam,
            hteam: homeTeam,
            players: [visitingPlayer, homePlayer]
        )
        let atbat = Atbat(
            ident: atbatID,
            game: game,
            team: visitingTeam,
            player: visitingPlayer,
            result: "Single",
            maxbase: "First",
            batOrder: 1,
            outAt: "Safe",
            inning: 1.0,
            seq: 1,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let lineup = Lineup(
            ident: lineupID,
            everyoneHits: false,
            game: game,
            team: visitingTeam,
            inning: 1,
            players: [visitingPlayer]
        )
        let pitcher = Pitcher(
            ident: pitcherID,
            player: homePlayer,
            team: homeTeam,
            game: game,
            startInn: 1,
            sOuts: 0,
            sBats: 1
        )

        visitingTeam.players.append(visitingPlayer)
        homeTeam.players.append(homePlayer)
        visitingTeam.games.append(game)
        homeTeam.games.append(game)
        game.atbats.append(atbat)
        game.lineups.append(lineup)
        game.pitchers.append(pitcher)

        environment.context.insert(visitingTeam)
        environment.context.insert(homeTeam)
        environment.context.insert(visitingPlayer)
        environment.context.insert(homePlayer)
        environment.context.insert(game)
        environment.context.insert(atbat)
        environment.context.insert(lineup)
        environment.context.insert(pitcher)

        return SyntheticGraphIDs(
            gameID: gameID,
            visitingTeamID: visitingTeamID,
            homeTeamID: homeTeamID,
            atbatID: atbatID,
            lineupID: lineupID,
            pitcherID: pitcherID
        )
    }
}

private struct SyntheticGraphIDs {
    let gameID: UUID
    let visitingTeamID: UUID
    let homeTeamID: UUID
    let atbatID: UUID
    let lineupID: UUID
    let pitcherID: UUID
}
