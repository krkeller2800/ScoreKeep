import Foundation
@testable import ScoreKeep

enum CanonicalRosterMembershipTestSupport {
    static let teamA = CanonicalTeamMeaningTestSupport.teamA
    static let teamB = CanonicalTeamMeaningTestSupport.teamB
    static let teamC = CanonicalTeamMeaningTestSupport.teamC
    static let playerA = CanonicalPlayerMeaningTestSupport.playerA
    static let playerB = CanonicalPlayerMeaningTestSupport.playerB
    static let playerC = CanonicalPlayerMeaningTestSupport.playerC
    static let gameA = CanonicalPlayerMeaningTestSupport.gameA
    static let gameB = CanonicalPlayerMeaningTestSupport.gameB

    static func team(
        id: UUID? = teamA,
        rawID: String? = nil,
        name: String = "Fixture Tigers"
    ) -> ReusableCanonicalTeam {
        CanonicalTeamMeaningTestSupport.team(
            id: id,
            rawID: rawID,
            display: CanonicalTeamMeaningTestSupport.display(name: .present(name)),
            rosterEvidence: .relationshipReference(count: nil),
            source: .currentReusableRecord
        )
    }

    static func player(
        id: UUID? = playerA,
        rawID: String? = nil,
        name: String = "Casey Smith",
        number: String = "12",
        position: String = "SS"
    ) -> ReusableCanonicalPlayer {
        CanonicalPlayerMeaningTestSupport.player(
            id: id,
            rawID: rawID,
            display: CanonicalPlayerMeaningTestSupport.display(
                name: .present(name),
                jerseyNumber: .present(number),
                position: .present(position)
            ),
            rosterEvidence: .currentRelationship(teamIdentity: .valid(teamA)),
            source: .currentReusableRecord
        )
    }

    static func display(
        number: PlayerTextEvidence = .present("12"),
        position: PlayerTextEvidence = .present("SS"),
        rosterOrder: Int? = 1,
        battingOrder: Int? = nil,
        media: PlayerMediaEvidence = .missing
    ) -> RosterMembershipDisplayEvidence {
        RosterMembershipDisplayEvidence(
            jerseyNumber: number,
            position: position,
            rosterOrder: OrderEvidence(kind: .sourceFile, value: rosterOrder),
            battingOrder: battingOrder.map { OrderEvidence(kind: .battingOrder, value: $0) },
            media: media
        )
    }

    static func membership(
        team: ReusableCanonicalTeam? = team(),
        player: ReusableCanonicalPlayer? = player(),
        display: RosterMembershipDisplayEvidence = display(),
        source: RosterMembershipEvidenceSource = .currentReusableRelationship
    ) -> CurrentRosterMembership {
        CurrentRosterMembership(
            teamEvidence: team.map { .reusableTeam($0) } ?? .missing,
            playerEvidence: player.map { .reusablePlayer($0) } ?? .missing,
            displayEvidence: display,
            source: source
        )
    }

    static func invalidTeamMembership() -> CurrentRosterMembership {
        CurrentRosterMembership(
            teamEvidence: .invalidIdentity(.invalid("not-a-team-uuid"), CanonicalTeamMeaningTestSupport.display()),
            playerEvidence: .reusablePlayer(player()),
            displayEvidence: display(),
            source: .importedRoster
        )
    }

    static func invalidPlayerMembership() -> CurrentRosterMembership {
        CurrentRosterMembership(
            teamEvidence: .reusableTeam(team()),
            playerEvidence: .invalidIdentity(.invalid("not-a-player-uuid"), CanonicalPlayerMeaningTestSupport.display()),
            displayEvidence: display(),
            source: .importedRoster
        )
    }

    static func importedMembership(from sharePlayer: SharePlayer, sourceIndex: Int? = nil) -> CurrentRosterMembership {
        let teamEvidence: RosterMembershipTeamEvidence
        if let shareTeam = sharePlayer.team {
            teamEvidence = .reusableTeam(
                ReusableCanonicalTeam(
                    identity: .valid(shareTeam.id),
                    display: TeamDisplayEvidence(
                        name: .present(shareTeam.name),
                        coach: .present(shareTeam.coach),
                        details: .present(shareTeam.details),
                        logo: shareTeam.logo.isEmpty ? .missing : .present(shareTeam.logo)
                    ),
                    rosterEvidence: .importedRosterReference(count: shareTeam.players.count),
                    source: .importedRoster
                )
            )
        } else {
            teamEvidence = .missing
        }

        let player = ReusableCanonicalPlayer(
            identity: .valid(sharePlayer.id),
            display: CanonicalPlayerMeaningTestSupport.display(from: sharePlayer),
            rosterEvidence: .importedRosterReference(teamIdentity: sharePlayer.team.map { .valid($0.id) }, sourceCount: nil),
            source: .importedRoster
        )

        return CurrentRosterMembership(
            teamEvidence: teamEvidence,
            playerEvidence: .reusablePlayer(player),
            displayEvidence: RosterMembershipDisplayEvidence(
                jerseyNumber: .present(sharePlayer.number),
                position: .present(sharePlayer.position),
                rosterOrder: OrderEvidence(kind: .sourceFile, value: sourceIndex),
                battingOrder: OrderEvidence(kind: .battingOrder, value: sharePlayer.batOrder),
                media: sharePlayer.photo.isEmpty ? .missing : .present(sharePlayer.photo)
            ),
            source: .importedRoster
        )
    }
}
