import Foundation
@testable import ScoreKeep

enum CanonicalLineupMeaningTestSupport {
    static let lineupA = StableIdentityAndOrderingTestSupport.fixedUUID("40000000-0000-0000-0000-000000000001")
    static let lineupB = StableIdentityAndOrderingTestSupport.fixedUUID("40000000-0000-0000-0000-000000000002")
    static let entryA = StableIdentityAndOrderingTestSupport.fixedUUID("41000000-0000-0000-0000-000000000001")
    static let entryB = StableIdentityAndOrderingTestSupport.fixedUUID("41000000-0000-0000-0000-000000000002")
    static let gameA = CanonicalRosterMembershipTestSupport.gameA
    static let gameB = CanonicalRosterMembershipTestSupport.gameB
    static let teamA = CanonicalRosterMembershipTestSupport.teamA
    static let teamB = CanonicalRosterMembershipTestSupport.teamB
    static let playerA = CanonicalRosterMembershipTestSupport.playerA
    static let playerB = CanonicalRosterMembershipTestSupport.playerB
    static let playerC = CanonicalRosterMembershipTestSupport.playerC

    static func team(
        id: UUID? = teamA,
        name: String = "Fixture Tigers"
    ) -> ReusableCanonicalTeam {
        CanonicalRosterMembershipTestSupport.team(id: id, name: name)
    }

    static func player(
        id: UUID? = playerA,
        name: String = "Casey Smith",
        number: String = "12",
        position: String = "SS"
    ) -> ReusableCanonicalPlayer {
        CanonicalRosterMembershipTestSupport.player(id: id, name: name, number: number, position: position)
    }

    static func side(
        role: TeamSideRole = .home,
        gameID: UUID = gameA,
        team: ReusableCanonicalTeam? = team(),
        display: TeamDisplayEvidence = CanonicalTeamMeaningTestSupport.display()
    ) -> GameSideTeamParticipation {
        CanonicalTeamMeaningTestSupport.side(gameID: gameID, role: role, team: team, display: display)
    }

    static func participant(
        gameID: UUID = gameA,
        player: ReusableCanonicalPlayer = player(),
        sideRole: TeamSideRole = .home,
        roles: Set<PlayerParticipantRole> = [.lineupParticipant, .batter],
        historicalDisplay: PlayerDisplayEvidence? = nil
    ) -> GamePlayerParticipation {
        let sideTeam = side(role: sideRole, gameID: gameID, team: sideRole == .home ? team(id: teamA) : team(id: teamB, name: "Fixture Hawks"))
        return CanonicalPlayerMeaningTestSupport.participant(
            gameID: gameID,
            player: player,
            teamEvidence: .gameSide(sideTeam),
            historicalDisplay: historicalDisplay ?? player.display,
            roles: roles,
            lineupEvidence: PlayerLineupParticipationEvidence(
                lineupIdentity: .valid(lineupA),
                slotOrder: OrderEvidence(kind: .lineupSlot, value: 1),
                battingOrder: OrderEvidence(kind: .battingOrder, value: 1)
            ),
            source: .historicalGameParticipation
        )
    }

    static func entry(
        id: UUID? = entryA,
        player: ReusableCanonicalPlayer? = player(),
        participant: LineupParticipantEvidence? = nil,
        gameID: UUID = gameA,
        sideRole: TeamSideRole = .home,
        slot: RawBattingSlotEvidence = .known(1),
        sourceIndex: Int? = 0,
        position: RawLineupPositionEvidence = .present("SS"),
        source: LineupEvidenceSource = .currentLineupRecord
    ) -> LineupEntryEvidence {
        let resolvedParticipant: LineupParticipantEvidence
        if let participant {
            resolvedParticipant = participant
        } else if let player {
            resolvedParticipant = .gameParticipant(self.participant(gameID: gameID, player: player, sideRole: sideRole))
        } else {
            resolvedParticipant = .missingPlayerIdentity(PlayerDisplayEvidence())
        }
        return LineupEntryEvidence(
            entryIdentity: id.map { .valid($0) } ?? .missing,
            participant: resolvedParticipant,
            battingSlot: slot,
            sourceOrder: sourceIndex.map { OrderEvidence(kind: .sourceFile, value: $0, sourceIndex: $0) },
            rawPosition: position,
            historicalDisplay: player?.display ?? PlayerDisplayEvidence(),
            source: source
        )
    }

    static func lineup(
        id: UUID? = lineupA,
        rawID: String? = nil,
        gameIdentity: ImportedIdentifierEvidence = .valid(gameA),
        side: LineupSideEvidence = .gameSide(side(role: .home)),
        teamEvidence: LineupTeamEvidence = .gameSide(side(role: .home)),
        mode: LineupModeEvidence = .traditional,
        entries: [LineupEntryEvidence] = [entry()],
        source: LineupEvidenceSource = .currentLineupRecord,
        inning: Int? = 1
    ) -> CanonicalGameLineup {
        let identity: ImportedIdentifierEvidence
        if let rawID {
            identity = ImportedIdentifierEvidence(rawValue: rawID)
        } else if let id {
            identity = .valid(id)
        } else {
            identity = .missing
        }
        return CanonicalGameLineup(
            lineupIdentity: identity,
            gameIdentity: gameIdentity,
            sideEvidence: side,
            teamEvidence: teamEvidence,
            mode: mode,
            entries: entries,
            source: source,
            rawInningEvidence: inning
        )
    }

    static func rosterMemberships() -> [CurrentRosterMembership] {
        [
            CanonicalRosterMembershipTestSupport.membership(
                player: player(id: playerA, name: "Casey Smith", number: "12")
            ),
            CanonicalRosterMembershipTestSupport.membership(
                player: player(id: playerB, name: "Riley Stone", number: "7"),
                display: CanonicalRosterMembershipTestSupport.display(number: .present("7"), rosterOrder: 2)
            )
        ]
    }

    static func importedLineup(from shareLineup: ShareLineup, gameID: UUID = gameA, sourceIndex: Int = 0) -> CanonicalGameLineup {
        let team = ReusableCanonicalTeam(
            identity: .valid(shareLineup.team.id),
            display: TeamDisplayEvidence(name: .present(shareLineup.team.name), coach: .present(shareLineup.team.coach), details: .present(shareLineup.team.details), logo: shareLineup.team.logo.isEmpty ? .missing : .present(shareLineup.team.logo)),
            rosterEvidence: .importedRosterReference(count: shareLineup.team.players.count),
            source: .importedGame
        )
        let mode: LineupModeEvidence = shareLineup.everyoneHits ? .everyoneHits : .traditional
        let entries = shareLineup.players.enumerated().map { index, sharePlayer in
            let player = ReusableCanonicalPlayer(
                identity: .valid(sharePlayer.id),
                display: CanonicalPlayerMeaningTestSupport.display(from: sharePlayer),
                rosterEvidence: .importedRosterReference(teamIdentity: sharePlayer.team.map { .valid($0.id) }, sourceCount: nil),
                source: .importedGame
            )
            return entry(
                id: nil,
                player: player,
                participant: .historicalPlayer(player, player.display),
                slot: sharePlayer.batOrder == 99 ? .nonHittingSentinel(99) : .known(sharePlayer.batOrder),
                sourceIndex: index,
                position: sharePlayer.position.isEmpty ? .blank : .present(sharePlayer.position),
                source: .importedGame
            )
        }
        return lineup(
            id: shareLineup.id,
            gameIdentity: .valid(gameID),
            side: .unresolved,
            teamEvidence: .reusableTeam(team),
            mode: mode,
            entries: entries,
            source: .importedGame,
            inning: shareLineup.inning
        )
    }
}
