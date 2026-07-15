import Testing
@testable import ScoreKeep

struct CanonicalRosterMembershipTests {
    @Test func validTeamAndPlayerProduceCurrentMembership() {
        let membership = CanonicalRosterMembershipTestSupport.membership()

        #expect(CanonicalRosterMembershipClassifier.classify(membership) == .current)
        #expect(membership.teamEvidence.identity == .valid(CanonicalRosterMembershipTestSupport.teamA))
        #expect(membership.playerEvidence.identity == .valid(CanonicalRosterMembershipTestSupport.playerA))
    }

    @Test func displayEvidenceChangesDoNotChangeMembershipIdentity() {
        let base = CanonicalRosterMembershipTestSupport.membership()
        let changedNumber = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(number: .present("44"))
        )
        let changedPosition = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(position: .present("CF"))
        )
        let changedOrder = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(rosterOrder: 8)
        )

        #expect(base == changedNumber)
        #expect(base == changedPosition)
        #expect(base == changedOrder)
        #expect(CanonicalRosterMembershipClassifier.compare(base, changedNumber) == .sameTeamAndPlayerConflictingEvidence([.jerseyNumber]))
        #expect(CanonicalRosterMembershipClassifier.compare(base, changedPosition) == .sameTeamAndPlayerConflictingEvidence([.position]))
        #expect(CanonicalRosterMembershipClassifier.compare(base, changedOrder) == .sameTeamAndPlayerConflictingEvidence([.rosterOrder]))
    }

    @Test func exactRepeatedAndMatchingDuplicateMembershipsAreClassifiedWithoutMerging() {
        let base = CanonicalRosterMembershipTestSupport.membership()
        let exactRepeat = CanonicalRosterMembershipTestSupport.membership()
        let matchingPairDifferentSource = CanonicalRosterMembershipTestSupport.membership(source: .compatibilityTransport)

        #expect(CanonicalRosterMembershipClassifier.compare(base, exactRepeat) == .exactRepeatedEvidence)
        #expect(CanonicalRosterMembershipClassifier.compare(base, matchingPairDifferentSource) == .sameTeamAndPlayerConflictingEvidence([.source]))

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster([base, exactRepeat, matchingPairDifferentSource])
        #expect(classifications.contains(.containsDuplicateMembership))
        #expect(classifications.contains(.containsConflictingMembership))
    }

    @Test func sameNameAndSameNumberPlayersWithDifferentIdentifiersRemainDistinct() {
        let playerA = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerA, name: "Jordan Lee", number: "7")
        let playerB = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerB, name: "Jordan Lee", number: "7")
        let membershipA = CanonicalRosterMembershipTestSupport.membership(
            player: playerA,
            display: CanonicalRosterMembershipTestSupport.display(number: .present("7"))
        )
        let membershipB = CanonicalRosterMembershipTestSupport.membership(
            player: playerB,
            display: CanonicalRosterMembershipTestSupport.display(number: .present("7"))
        )

        #expect(CanonicalRosterMembershipClassifier.compare(membershipA, membershipB) == .distinctMemberships)
        #expect(membershipA != membershipB)

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster([membershipA, membershipB])
        #expect(classifications.contains(.duplicateJerseyNumber("7")))
        #expect(classifications.contains(.multipleCurrentMemberships))
    }

    @Test func sameLastNamePlayersWithDifferentIdentifiersRemainDistinct() {
        let playerA = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerA, name: "Casey Morgan", number: "8")
        let playerB = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerB, name: "Riley Morgan", number: "18")
        let membershipA = CanonicalRosterMembershipTestSupport.membership(player: playerA)
        let membershipB = CanonicalRosterMembershipTestSupport.membership(player: playerB)

        #expect(CanonicalRosterMembershipClassifier.compare(membershipA, membershipB) == .distinctMemberships)
    }

    @Test func samePlayerCanHaveDistinctMembershipEvidenceForDifferentTeams() {
        let teamA = CanonicalRosterMembershipTestSupport.team(id: CanonicalRosterMembershipTestSupport.teamA, name: "Fixture Tigers")
        let teamB = CanonicalRosterMembershipTestSupport.team(id: CanonicalRosterMembershipTestSupport.teamB, name: "Fixture Hawks")
        let player = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerA)
        let membershipA = CanonicalRosterMembershipTestSupport.membership(team: teamA, player: player)
        let membershipB = CanonicalRosterMembershipTestSupport.membership(team: teamB, player: player)

        #expect(CanonicalRosterMembershipClassifier.compare(membershipA, membershipB) == .samePlayerDifferentCurrentTeams)

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster([membershipA, membershipB])
        #expect(classifications.contains(.playerOnMultipleCurrentTeams(CanonicalRosterMembershipTestSupport.playerA)))
        #expect(classifications.contains(.mixedTeamEvidence))
    }

    @Test func playerWithoutCurrentTeamAndHistoricalParticipationRemainRepresentable() {
        let player = CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerA)
        let historical = CanonicalPlayerMeaningTestSupport.participant(
            gameID: CanonicalRosterMembershipTestSupport.gameA,
            player: player,
            roles: [.lineupParticipant, .batter]
        )
        let absence = PlayerWithoutCurrentRosterMembership(player: player, historicalParticipation: [historical])

        let classifications = CanonicalRosterMembershipClassifier.classifyPlayerWithoutCurrentTeam(absence)
        #expect(classifications.contains(.playerWithoutCurrentTeam(CanonicalRosterMembershipTestSupport.playerA)))
        #expect(classifications.contains(.historicalParticipationOnly))
    }

    @Test func repeatedSemanticEvaluationIsDeterministic() {
        let memberships = [
            CanonicalRosterMembershipTestSupport.membership(display: CanonicalRosterMembershipTestSupport.display(rosterOrder: 2)),
            CanonicalRosterMembershipTestSupport.membership(display: CanonicalRosterMembershipTestSupport.display(rosterOrder: 2)),
            CanonicalRosterMembershipTestSupport.membership(
                player: CanonicalRosterMembershipTestSupport.player(id: CanonicalRosterMembershipTestSupport.playerB, number: "12"),
                display: CanonicalRosterMembershipTestSupport.display(number: .present("12"), rosterOrder: nil)
            )
        ]

        let first = CanonicalRosterMembershipClassifier.classifyRoster(memberships)
        let second = CanonicalRosterMembershipClassifier.classifyRoster(memberships.reversed())

        #expect(first == second)
        #expect(first.contains(.duplicateRosterOrder(2)))
        #expect(first.contains(.duplicateJerseyNumber("12")))
    }
}
