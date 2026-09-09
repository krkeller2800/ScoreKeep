import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team default batting order view")
struct TeamDefaultBattingOrderViewTests {
    @Test func editTeamExposesDefaultBattingOrderNavigation() throws {
        let editTeamSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/Edit Data/EditTeamView.swift")
        let teamViewSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/TeamView.swift")
        let playersOnTeamSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")
        let playerViewSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/PlayerView.swift")

        #expect(editTeamSource.contains("openDefaultBattingOrder: openDefaultBattingOrder"))
        #expect(editTeamSource.contains("Button(\"Default Batting Order\")") == false)
        #expect(playersOnTeamSource.contains("Text(\"Select a Player to edit\")"))
        #expect(playersOnTeamSource.contains("Label(\"Default Batting Order\", systemImage: \"list.number\")"))
        #expect(playersOnTeamSource.contains("Image(systemName: \"plus\")"))
        #expect(playersOnTeamSource.contains("Label(\"Add Player\", systemImage: \"plus\")") == false)
        #expect(playersOnTeamSource.contains(".foregroundStyle(.primary)"))
        #expect(playersOnTeamSource.contains("if usesStandardPlayerAdd == false && showsQuickAddRow"))
        #expect(playerViewSource.contains("Text(\"Select a Player to edit\")"))
        #expect(playerViewSource.contains("Label(\"Default Batting Order\", systemImage: \"list.number\")"))
        #expect(playerViewSource.contains("playerNavigationPath.append(TeamDefaultBattingOrderNavigationDestination(teamIdentity: pTeam.ident))"))
        #expect(playerViewSource.contains("TeamDefaultBattingOrderDestinationView(destination: destination, navigationPath: $playerNavigationPath)"))
        #expect(playerViewSource.contains(".foregroundStyle(.primary)"))
        #expect(playerViewSource.contains(".buttonStyle(.plain)"))
        #expect(teamViewSource.contains("TeamDefaultBattingOrderDestinationView(destination: destination, navigationPath: $navigationPath)"))
    }

    @Test func defaultOrderViewUsesDirectDragTable() throws {
        let source = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/TeamDefaultBattingOrderView.swift")

        #expect(source.contains("TeamDefaultBattingOrderDraft(players: players)"))
        #expect(source.contains("Text(\"Batting Order\")"))
        #expect(source.contains(".onMove"))
        #expect(source.contains(".environment(\\.editMode, .constant(editMode))"))
        #expect(source.contains("EditButton()") == false)
        #expect(source.contains("minus.circle") == false)
        #expect(source.contains("plus.circle") == false)
        #expect(source.contains("draft.moveRosterEntries(fromOffsets: offsets, toOffset: newOffset)"))
    }

    @Test func compactPositionFieldsUseSharedDisplayFormatter() throws {
        let playerViewSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/PlayerView.swift")
        let playersOnTeamSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/PlayersOnTeamView.swift")
        let defaultOrderSource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/TeamDefaultBattingOrderView.swift")
        let scorecardIdentitySource = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/Common/ScorecardPlayerIdentityView.swift")

        #expect(playerViewSource.contains("PlayerCompactPositionDisplay.string(for: player.position)"))
        #expect(playersOnTeamSource.contains("PlayerCompactPositionDisplay.string(for: player.position)"))
        #expect(defaultOrderSource.contains("PlayerCompactPositionDisplay.string(for: position)"))
        #expect(scorecardIdentitySource.contains("PlayerCompactPositionDisplay.string(for: player.position)"))
    }

    @Test func defaultOrderViewUsesExplicitSaveAndDirtyBackProtection() throws {
        let source = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/TeamDefaultBattingOrderView.swift")

        #expect(source.contains("Button(\"Save\")"))
        #expect(source.contains(".disabled(hasUnsavedChanges == false)"))
        #expect(source.contains("navigationBarBackButtonHidden(hasUnsavedChanges)"))
        #expect(source.contains("showingUnsavedChangesAlert = true"))
        #expect(source.contains("Button(\"Save Changes\")"))
        #expect(source.contains("Button(\"Discard Changes\", role: .destructive)"))
        #expect(source.contains("Button(\"Keep Editing\", role: .cancel) { }"))
    }

    @Test func defaultOrderAddPlayerReturnsAsNotInOrder() throws {
        let source = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/List Data/TeamDefaultBattingOrderView.swift")

        #expect(source.contains("AddPlayerDraftView(team: team) { savedPlayer in"))
        #expect(source.contains("savedPlayer.batOrder = PlayerRosterBattingOrder.notHitting"))
        #expect(source.contains("draft.synchronizeRosterPlayers(currentPlayers)"))
        #expect(source.contains("savedDraft = TeamDefaultBattingOrderDraft(players: currentPlayers)"))
    }

    @Test func explicitSavePersistsTeamDefaultWithoutChangingExistingGameEvidence() throws {
        let store = try TeamDefaultBattingOrderViewStore()
        let fixture = TeamDefaultBattingOrderViewFixture()
        fixture.insert(into: store.context)
        var draft = TeamDefaultBattingOrderDraft(players: fixture.players)

        draft.movePlayerToOrder(playerIdentifier: fixture.bench.identifier, at: 0)
        draft.movePlayerOutOfOrder(playerIdentifier: fixture.second.identifier)

        try TeamDefaultBattingOrderView.save(draft: draft, modelContext: store.context)

        #expect(fixture.bench.batOrder == 1)
        #expect(fixture.first.batOrder == 2)
        #expect(fixture.second.batOrder == 99)
        #expect(Set(fixture.existingLineup.players.map(\.identifier)) == Set([fixture.first.identifier, fixture.second.identifier]))
        #expect(Set(fixture.existingGame.atbats.map(\.ident)) == Set(fixture.existingAtbats.map(\.ident)))
        #expect(fixture.existingAtbats[0].batOrder == 1)
        #expect(fixture.existingAtbats[0].player.identifier == fixture.first.identifier)
        #expect(fixture.existingAtbats[1].batOrder == 2)
        #expect(fixture.existingAtbats[1].player.identifier == fixture.second.identifier)

        let futureGame = Game(
            date: "2026-09-10T12:00:00Z",
            location: "Future Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: fixture.team,
            hteam: fixture.opponent
        )
        store.context.insert(futureGame)

        let materialized = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: futureGame,
            team: fixture.team,
            modelContext: store.context
        )

        #expect(materialized.slots.map { $0.player.identifier } == [fixture.bench.identifier, fixture.first.identifier])
    }
}

@MainActor
private struct TeamDefaultBattingOrderViewFixture {
    let team = Team(name: "Default Order Team", coach: "", details: "")
    let opponent = Team(name: "Opponent", coach: "", details: "")
    let first: Player
    let second: Player
    let bench: Player
    let existingGame: Game
    let existingLineup: Lineup
    let existingAtbats: [Atbat]

    var players: [Player] {
        [first, second, bench]
    }

    init() {
        first = Player(name: "First", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team)
        second = Player(name: "Second", number: "2", position: "CF", batDir: "L", batOrder: 2, team: team)
        bench = Player(name: "Bench Pitcher", number: "35", position: "SP", batDir: "R", batOrder: 99, team: team)
        existingGame = Game(
            date: "2026-09-09T12:00:00Z",
            location: "Existing Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: team,
            hteam: opponent
        )
        existingLineup = Lineup(everyoneHits: false, game: existingGame, team: team, inning: 1, players: [first, second])
        existingAtbats = [
            Self.placeholder(game: existingGame, team: team, player: first, slot: 1),
            Self.placeholder(game: existingGame, team: team, player: second, slot: 2)
        ]
        team.players = players
        existingGame.players = [first, second]
        existingGame.lineups = [existingLineup]
        existingGame.atbats = existingAtbats
    }

    func insert(into context: ModelContext) {
        context.insert(team)
        context.insert(opponent)
        context.insert(existingGame)
        context.insert(existingLineup)
        for player in players {
            context.insert(player)
        }
        for atbat in existingAtbats {
            context.insert(atbat)
        }
    }

    private static func placeholder(game: Game, team: Team, player: Player, slot: Int) -> Atbat {
        Atbat(
            game: game,
            team: team,
            player: player,
            result: "Result",
            maxbase: "No Bases",
            batOrder: slot,
            outAt: "Safe",
            inning: 1,
            seq: slot,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
    }
}

@MainActor
private struct TeamDefaultBattingOrderViewStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }
}
