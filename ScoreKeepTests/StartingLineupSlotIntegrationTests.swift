import Testing
@testable import ScoreKeep

@MainActor
@Suite("Starting lineup slot integration")
struct StartingLineupSlotIntegrationTests {
    @Test func duplicateRosterPlayerCannotBeAssignedFromPickerCandidates() {
        let fixture = StartingLineupSlotFixture(playerCount: 3)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = StartingLineupView.selectableRosterPlayers(
            from: fixture.players,
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(fixture.players[0].identifier))
        #expect(candidates.map(\.identifier).contains(fixture.players[1].identifier) == false)
        #expect(candidates.map(\.identifier).contains(fixture.players[2].identifier))
    }

    @Test func benchPitchersAndPositionPlayersAreOfferedWhenUnassigned() {
        let fixture = StartingLineupSlotFixture(playerCount: 2)
        let starter = Player(name: "Starting Pitcher", number: "35", position: "SP", batDir: "R", batOrder: 99, team: fixture.team)
        let reliever = Player(name: "Relief Pitcher", number: "48", position: "RP", batDir: "L", batOrder: 99, team: fixture.team)
        let pitcher = Player(name: "Pitcher", number: "44", position: "P", batDir: "R", batOrder: 99, team: fixture.team)
        let benchPositionPlayer = Player(name: "Bench Outfielder", number: "12", position: "LF", batDir: "L", batOrder: 99, team: fixture.team)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = StartingLineupView.selectableRosterPlayers(
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
        let fixture = StartingLineupSlotFixture(playerCount: 1)
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

        let candidates = StartingLineupView.selectableRosterPlayers(
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
        let fixture = StartingLineupSlotFixture(playerCount: 3)
        let duplicateNameBenchPlayer = Player(
            name: fixture.players[1].name,
            number: "22",
            position: "CF",
            batDir: "L",
            batOrder: 99,
            team: fixture.team
        )
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let candidates = StartingLineupView.selectableRosterPlayers(
            from: fixture.players + [duplicateNameBenchPlayer],
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(fixture.players[1].identifier) == false)
        #expect(candidates.map(\.identifier).contains(duplicateNameBenchPlayer.identifier))
    }

    @Test func pickerCandidatesExcludeOtherTeams() {
        let fixture = StartingLineupSlotFixture(playerCount: 2)
        let otherTeam = Team(name: "Other", coach: "", details: "")
        let otherTeamPlayer = Player(name: "Other Player", number: "9", position: "RF", batDir: "R", batOrder: 99, team: otherTeam)
        let slots = fixture.slots(editabilities: [.editable])

        let candidates = StartingLineupView.selectableRosterPlayers(
            from: fixture.players + [otherTeamPlayer],
            slots: slots,
            targetSlot: slots[0],
            team: fixture.team
        )

        #expect(candidates.map(\.identifier).contains(otherTeamPlayer.identifier) == false)
    }

    @Test func addPlayerMenuItemIsFirst() {
        let fixture = StartingLineupSlotFixture(playerCount: 3)
        let slots = fixture.slots(editabilities: [.editable, .editable])

        let items = StartingLineupView.playerMenuItems(
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

    @Test func preScoringReorderIsAvailableOnlyWhenAllSlotsAreEditable() {
        let fixture = StartingLineupSlotFixture(playerCount: 2)

        #expect(StartingLineupView.canReorder(slots: fixture.slots(editabilities: [.editable, .editable])))
        #expect(StartingLineupView.canReorder(slots: fixture.slots(editabilities: [.editable, .locked(.placeholderNotPristine)])) == false)
        #expect(StartingLineupView.canReorder(slots: []) == false)
    }

    @Test func lockReasonsUseUserVisibleLanguage() {
        #expect(StartingLineupView.userVisibleLockExplanation(for: .placeholderNotPristine) == "This Player has participated in the game and can no longer be corrected as lineup entry.")
        #expect(StartingLineupView.userVisibleLockExplanation(for: .pitcherParticipation) == "This Player has participated in the game and can no longer be corrected as lineup entry.")
        #expect(StartingLineupView.userVisibleLockExplanation(for: .duplicateLineupSlot) == "This lineup slot cannot be safely changed.")
        #expect(StartingLineupView.userVisibleLockExplanation(for: .incomingPlayerUnavailable) == "That Player is already used in this game lineup.")
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
}

@MainActor
private struct StartingLineupSlotFixture {
    let team: Team
    let game: Game
    let players: [Player]
    let placeholders: [Atbat]

    init(playerCount: Int) {
        let createdTeam = Team(name: "Lineup Team", coach: "", details: "")
        let opponent = Team(name: "Opponent", coach: "", details: "")
        let createdGame = Game(date: "2026-09-08T12:00:00Z", location: "Field", highLights: "", hscore: 0, vscore: 0, vteam: createdTeam, hteam: opponent)
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
        game = createdGame
        players = createdPlayers
        placeholders = createdPlaceholders
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
