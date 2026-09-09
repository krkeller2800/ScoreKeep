import Testing
import SwiftData
@testable import ScoreKeep

@MainActor
@Suite("Scorecard lineup slot integration")
struct ScorecardLineupSlotIntegrationTests {
    @Test func scorecardCorrectionOffersPlayersAlreadyInOtherEditableSlots() {
        let fixture = LineupSlotFixture(playerCount: 3)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = PlayerLineupMenuSupport.selectableRosterPlayers(
            from: fixture.players,
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(fixture.players[0].identifier))
        #expect(candidates.map(\.identifier).contains(fixture.players[1].identifier))
        #expect(candidates.map(\.identifier).contains(fixture.players[2].identifier))
    }

    @Test func benchPitchersAndPositionPlayersAreOfferedWhenUnassigned() {
        let fixture = LineupSlotFixture(playerCount: 2)
        let starter = Player(name: "Starting Pitcher", number: "35", position: "SP", batDir: "R", batOrder: 99, team: fixture.team)
        let reliever = Player(name: "Relief Pitcher", number: "48", position: "RP", batDir: "L", batOrder: 99, team: fixture.team)
        let pitcher = Player(name: "Pitcher", number: "44", position: "P", batDir: "R", batOrder: 99, team: fixture.team)
        let benchPositionPlayer = Player(name: "Bench Outfielder", number: "12", position: "LF", batDir: "L", batOrder: 99, team: fixture.team)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = PlayerLineupMenuSupport.selectableRosterPlayers(
            from: fixture.players + [starter, reliever, pitcher, benchPositionPlayer],
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )
        let candidateIdentities = Set(candidates.map(\.identifier))

        #expect(candidateIdentities.contains(starter.identifier))
        #expect(candidateIdentities.contains(reliever.identifier))
        #expect(candidateIdentities.contains(pitcher.identifier))
        #expect(candidateIdentities.contains(benchPositionPlayer.identifier))
    }

    @Test func playersAreNotExcludedSolelyByPosition() {
        let fixture = LineupSlotFixture(playerCount: 1)
        let unusualPositions = ["SP", "RP", "P", "C", "DH", "OF", ""]
        let unassignedPlayers = unusualPositions.enumerated().map { index, position in
            Player(
                name: "Available \(index)",
                number: "\(index)",
                position: position,
                batDir: index.isMultiple(of: 2) ? "R" : "L",
                batOrder: 99,
                team: fixture.team
            )
        }
        let slots = fixture.slots(editabilities: [.editable])

        let candidates = PlayerLineupMenuSupport.selectableRosterPlayers(
            from: fixture.players + unassignedPlayers,
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )
        let candidateIdentities = Set(candidates.map(\.identifier))

        for player in unassignedPlayers {
            #expect(candidateIdentities.contains(player.identifier))
        }
    }

    @Test func pickerCandidatesUsePersistentIdentityRatherThanName() {
        let fixture = LineupSlotFixture(playerCount: 3)
        let duplicateNameBenchPlayer = Player(
            name: fixture.players[1].name,
            number: "22",
            position: "CF",
            batDir: "L",
            batOrder: 99,
            team: fixture.team
        )
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = PlayerLineupMenuSupport.selectableRosterPlayers(
            from: fixture.players + [duplicateNameBenchPlayer],
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(fixture.players[1].identifier))
        #expect(candidates.map(\.identifier).contains(duplicateNameBenchPlayer.identifier))
    }

    @Test func pickerCandidatesExcludeOtherTeams() {
        let fixture = LineupSlotFixture(playerCount: 2)
        let otherTeam = Team(name: "Other", coach: "", details: "")
        let otherTeamPlayer = Player(name: "Other Player", number: "9", position: "RF", batDir: "R", batOrder: 99, team: otherTeam)
        let slots = fixture.slots(editabilities: [.editable])

        let candidates = PlayerLineupMenuSupport.selectableRosterPlayers(
            from: fixture.players + [otherTeamPlayer],
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(otherTeamPlayer.identifier) == false)
    }

    @Test func addPlayerMenuItemIsFirst() {
        let fixture = LineupSlotFixture(playerCount: 3)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let items = PlayerLineupMenuSupport.playerMenuItems(
            from: fixture.players,
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        guard case .addPlayer = items.first else {
            Issue.record("Expected Add Player to be first")
            return
        }
        guard case .player(let selectedPlayer, let isSelected) = items[1] else {
            Issue.record("Expected roster Players after Add Player")
            return
        }
        #expect(selectedPlayer.identifier == fixture.players[0].identifier)
        #expect(isSelected)
    }

    @Test func playerMenuRowLabelUsesCompactTrailingMetadataAndFullAccessibility() {
        let team = Team(name: "Lineup Team", coach: "", details: "")
        let player = Player(
            name: "Very Long Player Name That Should Truncate Visibly",
            number: "27",
            position: "SS",
            batDir: "L",
            batOrder: 1,
            team: team
        )

        #expect(PlayerMenuRowLabel.trailingText(for: player) == "#27 | L")
        #expect(PlayerMenuRowLabel.accessibilityDescription(for: player, isSelected: true) == "Selected, Very Long Player Name That Should Truncate Visibly, number 27, bats L")
    }

    @Test func scorecardPlayerMenuShowsFullSameTeamRosterIncludingLaterSlots() {
        let fixture = LineupSlotFixture(playerCount: 4)
        let benchPlayer = Player(name: "Bench Hitter", number: "30", position: "OF", batDir: "L", batOrder: 99, team: fixture.team)
        let startingPitcher = Player(name: "Starter", number: "45", position: "SP", batDir: "R", batOrder: 99, team: fixture.team)
        let reliefPitcher = Player(name: "Reliever", number: "55", position: "RP", batDir: "R", batOrder: 99, team: fixture.team)
        let otherTeam = Team(name: "Other", coach: "", details: "")
        let otherTeamPlayer = Player(name: "Other Hitter", number: "9", position: "CF", batDir: "L", batOrder: 99, team: otherTeam)
        let slots = fixture.slots(editabilities: [.editable, .editable, .editable, .editable])

        let items = PlayersToScoreView.scorecardPlayerMenuItems(
            from: fixture.players + [benchPlayer, startingPitcher, reliefPitcher, otherTeamPlayer],
            slots: slots,
            targetSlot: slots[1],
            team: fixture.team
        )
        let playerItems = items.compactMap { item -> Player? in
            guard case .player(let player, _) = item else { return nil }
            return player
        }
        let candidateIdentities = Set(playerItems.map(\.identifier))

        guard case .addPlayer = items.first else {
            Issue.record("Expected Add Player to be first")
            return
        }
        #expect(candidateIdentities.contains(fixture.players[0].identifier))
        #expect(candidateIdentities.contains(fixture.players[1].identifier))
        #expect(candidateIdentities.contains(fixture.players[2].identifier))
        #expect(candidateIdentities.contains(fixture.players[3].identifier))
        #expect(candidateIdentities.contains(benchPlayer.identifier))
        #expect(candidateIdentities.contains(startingPitcher.identifier))
        #expect(candidateIdentities.contains(reliefPitcher.identifier))
        #expect(candidateIdentities.contains(otherTeamPlayer.identifier) == false)
    }

    @Test func scorecardOccupiedSlotSelectionSwapsEditablePlayersAndTeamDefault() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 4)
        _ = fixture.insert(into: store.context)
        let atbatIdentitiesBefore = fixture.placeholders.map(\.ident)
        let slots = LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context
        )

        let result = try LineupSlotSafetyCoordinator.swapPlayers(
            in: slots[1].battingOrder,
            withPlayerIn: slots[3].battingOrder,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )

        let resolved = LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context
        )
        #expect(result.targetSlot.player.identifier == fixture.players[3].identifier)
        #expect(result.occupiedSlot.player.identifier == fixture.players[1].identifier)
        #expect(resolved.map(\.player.identifier)[1] == fixture.players[3].identifier)
        #expect(resolved.map(\.player.identifier)[3] == fixture.players[1].identifier)
        #expect(Set(resolved.map(\.player.identifier)).count == resolved.count)
        #expect(fixture.placeholders.map(\.ident) == atbatIdentitiesBefore)
        #expect(fixture.players[3].batOrder == 2)
        #expect(fixture.players[1].batOrder == 4)
    }

    @Test func futureGameUsesScorecardSwappedTeamDefault() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 4)
        _ = fixture.insert(into: store.context)
        _ = try LineupSlotSafetyCoordinator.swapPlayers(
            in: 2,
            withPlayerIn: 4,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )
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

        let future = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: futureGame,
            team: fixture.team,
            modelContext: store.context
        )

        #expect(future.slots.map(\.player.identifier)[1] == fixture.players[3].identifier)
        #expect(future.slots.map(\.player.identifier)[3] == fixture.players[1].identifier)
    }

    @Test func lockedPlayerCannotParticipateInScorecardSwap() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 4)
        _ = fixture.insert(into: store.context)
        let defaultOrderBefore = Dictionary(uniqueKeysWithValues: fixture.players.map { ($0.identifier, $0.batOrder) })
        fixture.placeholders[3].result = "Single"
        fixture.placeholders[3].maxbase = "First"
        try store.context.save()

        do {
            _ = try LineupSlotSafetyCoordinator.swapPlayers(
                in: 2,
                withPlayerIn: 4,
                game: fixture.game,
                team: fixture.team,
                modelContext: store.context,
                updateTeamDefaultOrder: true
            )
            Issue.record("Expected locked scorecard swap to fail")
        } catch LineupSlotSafetyError.slotLocked(let reason) {
            #expect(reason == .placeholderNotPristine)
            let resolved = LineupSlotSafetyCoordinator.resolvedSlots(
                game: fixture.game,
                team: fixture.team,
                modelContext: store.context
            )
            #expect(resolved.map(\.player.identifier)[1] == fixture.players[1].identifier)
            #expect(resolved.map(\.player.identifier)[3] == fixture.players[3].identifier)
            #expect(Dictionary(uniqueKeysWithValues: fixture.players.map { ($0.identifier, $0.batOrder) }) == defaultOrderBefore)
        }
    }

    @Test func scorecardUnassignedPlayerCorrectionUpdatesTeamDefault() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 3)
        _ = fixture.insert(into: store.context)
        let bench = Player(name: "Bench Hitter", number: "33", position: "OF", batDir: "L", batOrder: 99, team: fixture.team)
        fixture.team.players.append(bench)
        store.context.insert(bench)

        let result = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 2,
            to: bench,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )

        #expect(result.slot.player.identifier == bench.identifier)
        #expect(bench.batOrder == 2)
        #expect(fixture.players[1].batOrder == 99)
    }

    @Test func scorecardAddPlayerAssignmentUpdatesTeamDefault() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 3)
        _ = fixture.insert(into: store.context)
        let added = Player(name: "Added Player", number: "42", position: "OF", batDir: "L", batOrder: 99, team: fixture.team)
        fixture.team.players.append(added)
        store.context.insert(added)

        let result = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 3,
            to: added,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )

        #expect(result.slot.player.identifier == added.identifier)
        #expect(added.batOrder == 3)
        #expect(fixture.players[2].batOrder == 99)
    }

    @Test func scorecardSwapPreservesExistingScoringStateAndUnrelatedSlots() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 5)
        _ = fixture.insert(into: store.context)
        fixture.game.hscore = 2
        fixture.game.vscore = 3
        fixture.placeholders[0].result = "Single"
        fixture.placeholders[0].maxbase = "First"
        let pitcher = Pitcher(player: fixture.players[0], team: fixture.team, game: fixture.game, startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 0, eBats: 1)
        let incoming = Player(name: "Incoming", number: "50", position: "OF", batDir: "R", batOrder: 99, team: fixture.team)
        store.context.insert(pitcher)
        store.context.insert(incoming)
        fixture.game.pitchers = [pitcher]
        fixture.game.incomings = [incoming]
        let thirdSlotIdentity = fixture.placeholders[2].ident

        _ = try LineupSlotSafetyCoordinator.swapPlayers(
            in: 4,
            withPlayerIn: 5,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )

        let resolved = LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context
        )
        #expect(fixture.game.hscore == 2)
        #expect(fixture.game.vscore == 3)
        #expect(fixture.placeholders[0].result == "Single")
        #expect(fixture.placeholders[0].maxbase == "First")
        #expect(fixture.game.pitchers.map(\.ident) == [pitcher.ident])
        #expect(fixture.game.incomings.map(\.identifier) == [incoming.identifier])
        #expect(resolved[2].placeholderAtbat.ident == thirdSlotIdentity)
        #expect(resolved[2].player.identifier == fixture.players[2].identifier)
        #expect(resolved[3].player.identifier == fixture.players[4].identifier)
        #expect(resolved[4].player.identifier == fixture.players[3].identifier)
    }

    @Test func reopeningCurrentGamePreservesScorecardSwapAndDefaultOrder() throws {
        let store = try LineupSlotStore()
        let fixture = LineupSlotFixture(playerCount: 4)
        _ = fixture.insert(into: store.context)
        _ = try LineupSlotSafetyCoordinator.swapPlayers(
            in: 2,
            withPlayerIn: 4,
            game: fixture.game,
            team: fixture.team,
            modelContext: store.context,
            updateTeamDefaultOrder: true
        )

        let reopenedContext = ModelContext(store.container)
        let reopenedGame = try #require(try reopenedContext.fetch(FetchDescriptor<Game>()).first)
        let reopenedTeam = try #require(reopenedGame.vteam)
        let result = LineupSlotSafetyCoordinator.resolvedSlots(
            game: reopenedGame,
            team: reopenedTeam,
            modelContext: reopenedContext
        )

        #expect(result.map(\.player.number)[1] == "4")
        #expect(result.map(\.player.number)[3] == "2")
        #expect(result.map(\.player.batOrder)[1] == 2)
        #expect(result.map(\.player.batOrder)[3] == 4)
    }

    @Test func scorecardRenderedPlaceholderMapsOnlyToMatchingCoordinatorSlot() {
        let fixture = LineupSlotFixture(playerCount: 2)
        let slots = fixture.slots(editabilities: [.editable, .locked(.placeholderNotPristine)])
        let matchingAtbat = fixture.placeholders[0]
        let mismatchedPlayerAtbat = Atbat(
            game: fixture.game,
            team: fixture.team,
            player: fixture.players[1],
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

        #expect(PlayersToScoreView.scorecardLineupSlot(for: matchingAtbat, slots: slots)?.isEditable == true)
        #expect(PlayersToScoreView.scorecardLineupSlot(for: fixture.placeholders[1], slots: slots)?.isEditable == false)
        #expect(PlayersToScoreView.scorecardLineupSlot(for: mismatchedPlayerAtbat, slots: slots) == nil)
    }
}

@MainActor
private struct LineupSlotFixture {
    let team: Team
    let opponent: Team
    let game: Game
    let players: [Player]
    let placeholders: [Atbat]

    init(playerCount: Int, everyoneHits: Bool = false) {
        let createdTeam = Team(name: "Lineup Team", coach: "", details: "")
        let opponent = Team(name: "Opponent", coach: "", details: "")
        let createdGame = Game(
            date: "2026-09-08T12:00:00Z",
            location: "Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyoneHits,
            vteam: createdTeam,
            hteam: opponent
        )
        let createdPlayers = (1...playerCount).map {
            Player(name: "Player \($0)", number: "\($0)", position: "SS", batDir: "R", batOrder: $0, team: createdTeam)
        }
        let createdPlaceholders = createdPlayers.enumerated().map { index, player in
            Atbat(
                game: createdGame,
                team: createdTeam,
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
        createdTeam.players = createdPlayers
        createdGame.players = createdPlayers
        createdGame.atbats = createdPlaceholders
        team = createdTeam
        self.opponent = opponent
        game = createdGame
        players = createdPlayers
        placeholders = createdPlaceholders
    }

    func insert(into context: ModelContext) -> Lineup {
        let lineup = Lineup(everyoneHits: game.everyOneHits, game: game, team: team, inning: 1, players: players)
        context.insert(team)
        context.insert(opponent)
        context.insert(game)
        context.insert(lineup)
        for player in players {
            context.insert(player)
        }
        for placeholder in placeholders {
            context.insert(placeholder)
        }
        game.lineups = [lineup]
        return lineup
    }

    func slots(editabilities: [LineupSlotEditability]) -> [LineupSlot] {
        zip(players, editabilities).enumerated().map { index, pair in
            LineupSlot(
                battingOrder: index + 1,
                player: pair.0,
                placeholderAtbat: placeholders[index],
                editability: pair.1
            )
        }
    }
}

@MainActor
private struct LineupSlotStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }
}
