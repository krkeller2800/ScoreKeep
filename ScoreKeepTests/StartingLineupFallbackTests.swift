import Testing
@testable import ScoreKeep

struct StartingLineupFallbackTests {
    @Test func nonEmptySavedLineupIsPreferred() {
        let fixture = LineupFallbackFixture()
        let savedLineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.team, inning: 1, players: [
            fixture.savedSecond,
            fixture.savedFirst
        ])
        let atbat = Atbat(
            game: fixture.game,
            team: fixture.team,
            player: fixture.atbatPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 3,
            outAt: "Safe",
            inning: 1,
            seq: 3,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )

        let resolved = StartingLineupView.resolvedLineupPlayers(
            savedLineup: savedLineup,
            atbats: [atbat],
            fallbackPlayers: [fixture.fallbackPlayer],
            team: fixture.team,
            game: fixture.game
        )

        #expect(resolved.map(\.name) == ["Saved First", "Saved Second"])
    }

    @Test func emptySavedLineupFallsBackToFirstColumnAtbats() {
        let fixture = LineupFallbackFixture()
        let savedLineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.team, inning: 1)
        let secondAtbat = fixture.atbat(player: fixture.savedSecond, batOrder: 2, seq: 2, col: 1)
        let firstAtbat = fixture.atbat(player: fixture.savedFirst, batOrder: 1, seq: 1, col: 1)
        let laterColumnAtbat = fixture.atbat(player: fixture.atbatPlayer, batOrder: 3, seq: 3, col: 2)
        let benchAtbat = fixture.atbat(player: fixture.fallbackPlayer, batOrder: 99, seq: 4, col: 1)

        let resolved = StartingLineupView.resolvedLineupPlayers(
            savedLineup: savedLineup,
            atbats: [secondAtbat, laterColumnAtbat, benchAtbat, firstAtbat],
            fallbackPlayers: [fixture.fallbackPlayer],
            team: fixture.team,
            game: fixture.game
        )

        #expect(resolved.map(\.name) == ["Saved First", "Saved Second"])
    }

    @Test func playerFallbackIsUsedWhenNoAtbatsExist() {
        let fixture = LineupFallbackFixture()
        let savedLineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.team, inning: 1)

        let resolved = StartingLineupView.resolvedLineupPlayers(
            savedLineup: savedLineup,
            atbats: [],
            fallbackPlayers: [fixture.savedSecond, fixture.savedFirst],
            team: fixture.team,
            game: fixture.game
        )

        #expect(resolved.map(\.name) == ["Saved First", "Saved Second"])
    }

    @Test func exportedShareLineupPreservesPlayers() {
        let fixture = LineupFallbackFixture()
        let lineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.team, inning: 1, players: [
            fixture.savedFirst,
            fixture.savedSecond
        ])

        let exported = ShareContentView().getLineups(lineups: [lineup])

        #expect(exported.count == 1)
        #expect(exported[0].players.map(\.name) == ["Saved First", "Saved Second"])
        #expect(exported[0].players.map(\.number) == ["1", "2"])
    }
}

private struct LineupFallbackFixture {
    let team = Team(name: "Cardinals", coach: "", details: "")
    let opponent = Team(name: "Tigers", coach: "", details: "")
    let game: Game
    let savedFirst: Player
    let savedSecond: Player
    let atbatPlayer: Player
    let fallbackPlayer: Player

    init() {
        game = Game(date: "2026-04-04T15:05:00Z", location: "Comerica", highLights: "", hscore: 0, vscore: 0)
        savedFirst = Player(name: "Saved First", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team)
        savedSecond = Player(name: "Saved Second", number: "2", position: "CF", batDir: "L", batOrder: 2, team: team)
        atbatPlayer = Player(name: "Atbat Player", number: "3", position: "RF", batDir: "R", batOrder: 3, team: team)
        fallbackPlayer = Player(name: "Fallback Player", number: "4", position: "1B", batDir: "L", batOrder: 4, team: team)
        game.vteam = team
        game.hteam = opponent
    }

    func atbat(player: Player, batOrder: Int, seq: Int, col: Int) -> Atbat {
        Atbat(
            game: game,
            team: team,
            player: player,
            result: "Result",
            maxbase: "No Bases",
            batOrder: batOrder,
            outAt: "Safe",
            inning: 1,
            seq: seq,
            col: col,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
    }
}
