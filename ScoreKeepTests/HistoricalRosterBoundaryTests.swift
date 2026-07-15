import Testing
@testable import ScoreKeep

struct HistoricalRosterBoundaryTests {
    @Test func currentRosterRemovalDoesNotEraseHistoricalParticipation() {
        let player = CanonicalRosterMembershipTestSupport.player()
        let currentMembership = CanonicalRosterMembershipTestSupport.membership(player: player)
        let historical = CanonicalPlayerMeaningTestSupport.participant(
            gameID: CanonicalRosterMembershipTestSupport.gameA,
            player: player,
            historicalDisplay: CanonicalPlayerMeaningTestSupport.display(name: .present("Casey Game Name")),
            roles: [.lineupParticipant, .batter]
        )
        let removedCurrentEvidence = PlayerWithoutCurrentRosterMembership(player: player, historicalParticipation: [historical])

        #expect(CanonicalRosterMembershipClassifier.classify(currentMembership) == .current)
        #expect(CanonicalRosterMembershipClassifier.classifyPlayerWithoutCurrentTeam(removedCurrentEvidence).contains(.historicalParticipationOnly))
        #expect(historical.historicalDisplay.name == .present("Casey Game Name"))
    }

    @Test func currentRosterAdditionDoesNotFabricateHistoricalParticipation() {
        let membership = CanonicalRosterMembershipTestSupport.membership()
        let roster = TeamRosterMembershipSet(team: CanonicalRosterMembershipTestSupport.team(), memberships: [membership])

        #expect(CanonicalRosterMembershipClassifier.classifyTeamRoster(roster).contains(.oneCurrentMembership))
        #expect(CanonicalRosterMembershipClassifier.classify(membership) == .current)
    }

    @Test func currentNumberPositionPlayerRenameAndTeamRenameDoNotRewriteHistoricalParticipantEvidence() {
        let currentPlayer = CanonicalRosterMembershipTestSupport.player(name: "Casey Current", number: "44", position: "CF")
        let currentTeam = CanonicalRosterMembershipTestSupport.team(name: "Current Tigers")
        let membership = CanonicalRosterMembershipTestSupport.membership(
            team: currentTeam,
            player: currentPlayer,
            display: CanonicalRosterMembershipTestSupport.display(number: .present("44"), position: .present("CF"))
        )
        let historical = CanonicalPlayerMeaningTestSupport.participant(
            gameID: CanonicalRosterMembershipTestSupport.gameA,
            player: currentPlayer,
            historicalDisplay: CanonicalPlayerMeaningTestSupport.display(
                name: .present("Casey Historical"),
                jerseyNumber: .present("12"),
                position: .present("SS")
            ),
            roles: [.lineupParticipant]
        )

        #expect(CanonicalRosterMembershipClassifier.classify(membership) == .current)
        #expect(historical.historicalDisplay.name == .present("Casey Historical"))
        #expect(historical.historicalDisplay.jerseyNumber == .present("12"))
        #expect(historical.historicalDisplay.position == .present("SS"))
        #expect(currentTeam.display.name == .present("Current Tigers"))
    }

    @Test func currentMembershipAndGameParticipantAreSeparateSemanticTypes() {
        let player = CanonicalRosterMembershipTestSupport.player()
        let membership = CanonicalRosterMembershipTestSupport.membership(player: player)
        let participant = CanonicalPlayerMeaningTestSupport.participant(
            participantID: CanonicalPlayerMeaningTestSupport.participantA,
            gameID: CanonicalRosterMembershipTestSupport.gameA,
            player: player,
            roles: [.lineupParticipant, .batter]
        )

        #expect(CanonicalRosterMembershipClassifier.classify(membership) == .current)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(participant) == .resolvedParticipant)
        #expect(participant.participantIdentity == .valid(CanonicalPlayerMeaningTestSupport.participantA))
        #expect(participant.reusablePlayerIdentity == membership.playerEvidence.identity)
    }

    @Test func playerCanAppearHistoricallyForDifferentTeamsWithoutChangingCurrentMembership() {
        let player = CanonicalRosterMembershipTestSupport.player()
        let currentTeam = CanonicalRosterMembershipTestSupport.team(id: CanonicalRosterMembershipTestSupport.teamA)
        let oldTeamSide = CanonicalPlayerMeaningTestSupport.side(
            gameID: CanonicalRosterMembershipTestSupport.gameB,
            role: .visiting,
            teamID: CanonicalRosterMembershipTestSupport.teamB,
            name: "Historical Hawks"
        )
        let currentMembership = CanonicalRosterMembershipTestSupport.membership(team: currentTeam, player: player)
        let historicalForOldTeam = CanonicalPlayerMeaningTestSupport.participant(
            gameID: CanonicalRosterMembershipTestSupport.gameB,
            player: player,
            teamEvidence: .gameSide(oldTeamSide),
            roles: [.lineupParticipant]
        )

        #expect(CanonicalRosterMembershipClassifier.classify(currentMembership) == .current)
        #expect(historicalForOldTeam.teamEvidence == .gameSide(oldTeamSide))
        #expect(currentMembership.teamEvidence.identity == .valid(CanonicalRosterMembershipTestSupport.teamA))
    }
}
