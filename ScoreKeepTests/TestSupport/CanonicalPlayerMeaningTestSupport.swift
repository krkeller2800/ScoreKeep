import Foundation
@testable import ScoreKeep

enum CanonicalPlayerMeaningTestSupport {
    static let playerA = StableIdentityAndOrderingTestSupport.playerA
    static let playerB = StableIdentityAndOrderingTestSupport.playerB
    static let playerC = StableIdentityAndOrderingTestSupport.fixedUUID("20000000-0000-0000-0000-000000000003")
    static let participantA = StableIdentityAndOrderingTestSupport.fixedUUID("21000000-0000-0000-0000-000000000001")
    static let participantB = StableIdentityAndOrderingTestSupport.fixedUUID("21000000-0000-0000-0000-000000000002")
    static let lineupA = StableIdentityAndOrderingTestSupport.fixedUUID("50000000-0000-0000-0000-000000000001")
    static let pitcherA = StableIdentityAndOrderingTestSupport.fixedUUID("60000000-0000-0000-0000-000000000001")
    static let substitutionA = StableIdentityAndOrderingTestSupport.fixedUUID("70000000-0000-0000-0000-000000000001")
    static let teamA = StableIdentityAndOrderingTestSupport.teamA
    static let teamB = StableIdentityAndOrderingTestSupport.teamB
    static let gameA = StableIdentityAndOrderingTestSupport.gameA
    static let gameB = StableIdentityAndOrderingTestSupport.gameB
    static let eventA = StableIdentityAndOrderingTestSupport.eventA
    static let eventB = StableIdentityAndOrderingTestSupport.eventB

    static let photoA = Data([0x10, 0x11, 0x12])
    static let photoB = Data([0x20, 0x21, 0x22, 0x23])

    static func display(
        name: PlayerTextEvidence = .present("Casey Smith"),
        jerseyNumber: PlayerTextEvidence = .present("12"),
        position: PlayerTextEvidence = .present("SS"),
        battingDirection: PlayerTextEvidence = .present("R"),
        photo: PlayerMediaEvidence = .missing
    ) -> PlayerDisplayEvidence {
        PlayerDisplayEvidence(
            name: name,
            jerseyNumber: jerseyNumber,
            position: position,
            battingDirection: battingDirection,
            photo: photo
        )
    }

    static func player(
        id: UUID? = playerA,
        rawID: String? = nil,
        display: PlayerDisplayEvidence = display(),
        rosterEvidence: PlayerRosterEvidence = .notRepresented,
        source: PlayerEvidenceSource = .currentReusableRecord
    ) -> ReusableCanonicalPlayer {
        let identity: ImportedIdentifierEvidence
        if let rawID {
            identity = ImportedIdentifierEvidence(rawValue: rawID)
        } else if let id {
            identity = .valid(id)
        } else {
            identity = .missing
        }

        return ReusableCanonicalPlayer(
            identity: identity,
            display: display,
            rosterEvidence: rosterEvidence,
            source: source
        )
    }

    static func side(
        gameID: UUID = gameA,
        role: TeamSideRole = .home,
        teamID: UUID = teamA,
        name: String = "Fixture Tigers"
    ) -> GameSideTeamParticipation {
        let team = CanonicalTeamMeaningTestSupport.team(
            id: teamID,
            display: CanonicalTeamMeaningTestSupport.display(name: .present(name))
        )
        return CanonicalTeamMeaningTestSupport.side(gameID: gameID, role: role, team: team, display: team.display)
    }

    static func participant(
        participantID: UUID? = participantA,
        gameID: UUID = gameA,
        player: ReusableCanonicalPlayer = player(),
        teamEvidence: PlayerTeamEvidence? = nil,
        historicalDisplay: PlayerDisplayEvidence = display(),
        roles: Set<PlayerParticipantRole> = [.lineupParticipant],
        lineupEvidence: PlayerLineupParticipationEvidence? = nil,
        plateAppearanceEvidence: [PlayerPlateAppearanceEvidence] = [],
        pitcherAppearanceEvidence: [PlayerPitcherAppearanceEvidence] = [],
        substitutionEvidence: [PlayerSubstitutionEvidence] = [],
        source: PlayerEvidenceSource = .historicalGameParticipation
    ) -> GamePlayerParticipation {
        GamePlayerParticipation(
            participantIdentity: participantID.map { .valid($0) } ?? .missing,
            gameIdentity: .valid(gameID),
            playerResolution: .reusablePlayer(player),
            teamEvidence: teamEvidence ?? .gameSide(side(gameID: gameID)),
            historicalDisplay: historicalDisplay,
            roles: roles,
            lineupEvidence: lineupEvidence,
            plateAppearanceEvidence: plateAppearanceEvidence,
            pitcherAppearanceEvidence: pitcherAppearanceEvidence,
            substitutionEvidence: substitutionEvidence,
            source: source
        )
    }

    static func reusablePlayer(from sharePlayer: SharePlayer, source: PlayerEvidenceSource) -> ReusableCanonicalPlayer {
        ReusableCanonicalPlayer(
            identity: .valid(sharePlayer.id),
            display: display(from: sharePlayer),
            rosterEvidence: .importedRosterReference(teamIdentity: sharePlayer.team.map { .valid($0.id) }, sourceCount: nil),
            source: source
        )
    }

    static func display(from sharePlayer: SharePlayer) -> PlayerDisplayEvidence {
        PlayerDisplayEvidence(
            name: .present(sharePlayer.name),
            jerseyNumber: .present(sharePlayer.number),
            position: .present(sharePlayer.position),
            battingDirection: .present(sharePlayer.batDir),
            photo: sharePlayer.photo.isEmpty ? .missing : .present(sharePlayer.photo)
        )
    }
}
