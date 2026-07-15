import Testing
@testable import ScoreKeep

struct CanonicalLineupMeaningTests {
    @Test func lineupIdentityPreservesValidIdentifierAcrossDisplayChanges() {
        let base = CanonicalLineupMeaningTestSupport.lineup()
        let renamedPlayer = CanonicalLineupMeaningTestSupport.player(name: "Casey Renamed", number: "44")
        let changedDisplay = CanonicalLineupMeaningTestSupport.lineup(
            entries: [CanonicalLineupMeaningTestSupport.entry(player: renamedPlayer)]
        )

        #expect(base == changedDisplay)
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(base, changedDisplay) == .sameIdentityMatchingEvidence)
    }

    @Test func sameLineupIdentifierWithConflictingGameOrSideIsClassified() {
        let base = CanonicalLineupMeaningTestSupport.lineup()
        let differentGame = CanonicalLineupMeaningTestSupport.lineup(gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameB))
        let visitingSide = CanonicalLineupMeaningTestSupport.lineup(side: .visiting)

        #expect(CanonicalLineupMeaningClassifier.compareIdentity(base, differentGame) == .sameIdentityConflictingEvidence(["gameIdentity"]))
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(base, visitingSide) == .sameIdentityConflictingEvidence(["side"]))
        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet([base, visitingSide]).contains(.conflictingSide))
    }

    @Test func differentLineupIdentifiersWithIdenticalEntriesRemainDistinct() {
        let base = CanonicalLineupMeaningTestSupport.lineup(id: CanonicalLineupMeaningTestSupport.lineupA)
        let differentID = CanonicalLineupMeaningTestSupport.lineup(id: CanonicalLineupMeaningTestSupport.lineupB)

        #expect(base != differentID)
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(base, differentID) == .distinctIdentitiesMatchingEvidence)
    }

    @Test func missingInvalidDuplicateAndUnresolvedLineupIdentityRemainClassified() {
        let missing = CanonicalLineupMeaningTestSupport.lineup(id: nil)
        let invalid = CanonicalLineupMeaningTestSupport.lineup(rawID: "not-a-lineup-uuid")
        let duplicate = CanonicalLineupMeaningTestSupport.lineup()

        #expect(CanonicalLineupMeaningClassifier.compareIdentity(missing, CanonicalLineupMeaningTestSupport.lineup()) == .missingIdentity)
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(invalid, CanonicalLineupMeaningTestSupport.lineup()) == .invalidIdentity)
        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet([CanonicalLineupMeaningTestSupport.lineup(), duplicate]).contains(.duplicateLineup))
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(missing, CanonicalLineupMeaningTestSupport.lineup(id: nil, entries: [])) == .missingIdentity)
    }

    @Test func homeAndVisitingLineupsRemainGameSpecificAndDistinct() {
        let homeSide = CanonicalLineupMeaningTestSupport.side(role: .home)
        let visitingSide = CanonicalLineupMeaningTestSupport.side(
            role: .visiting,
            team: CanonicalLineupMeaningTestSupport.team(id: CanonicalLineupMeaningTestSupport.teamB, name: "Fixture Hawks")
        )
        let home = CanonicalLineupMeaningTestSupport.lineup(
            side: .gameSide(homeSide),
            teamEvidence: .gameSide(homeSide)
        )
        let visiting = CanonicalLineupMeaningTestSupport.lineup(
            id: CanonicalLineupMeaningTestSupport.lineupB,
            side: .gameSide(visitingSide),
            teamEvidence: .gameSide(visitingSide),
            entries: [CanonicalLineupMeaningTestSupport.entry(player: CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB), sideRole: .visiting)]
        )

        let classifications = CanonicalLineupMeaningClassifier.classifyLineupSet([home, visiting])
        #expect(classifications.contains(.multipleLineups))
        #expect(classifications.contains(.completeLineup))
        #expect(classifications.contains(.conflictingSide) == false)
    }

    @Test func missingInvalidAndUnresolvedGameOrSideContextAreExplicit() {
        let missingGame = CanonicalLineupMeaningTestSupport.lineup(gameIdentity: .missing)
        let invalidGame = CanonicalLineupMeaningTestSupport.lineup(gameIdentity: .invalid("bad-game-id"))
        let missingSide = CanonicalLineupMeaningTestSupport.lineup(side: .missing)
        let unresolvedSide = CanonicalLineupMeaningTestSupport.lineup(side: .unresolved)

        #expect(CanonicalLineupMeaningClassifier.classifyLineup(missingGame).contains(.missingGame))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(invalidGame).contains(.invalidGame))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(missingSide).contains(.missingSide))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(unresolvedSide).contains(.unresolvedSide))
    }

    @Test func teamSideAndParticipantSideConflictsAreNotNormalized() {
        let homeSide = CanonicalLineupMeaningTestSupport.side(role: .home)
        let wrongTeam = CanonicalLineupMeaningTestSupport.team(id: CanonicalLineupMeaningTestSupport.teamB, name: "Fixture Hawks")
        let wrongSideEntry = CanonicalLineupMeaningTestSupport.entry(sideRole: .visiting)
        let lineup = CanonicalLineupMeaningTestSupport.lineup(
            side: .gameSide(homeSide),
            teamEvidence: .reusableTeam(wrongTeam),
            entries: [wrongSideEntry]
        )

        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup)
        #expect(classifications.contains(.teamSideConflict))
        #expect(classifications.contains(.participantSideConflict))
        #expect(classifications.contains(.contradictoryEvidence))
    }

    @Test func lineupMembershipIsSeparateFromReusablePlayerGameParticipantAndRosterMembership() {
        let player = CanonicalLineupMeaningTestSupport.player()
        let participant = CanonicalLineupMeaningTestSupport.participant(player: player)
        let rosterMembership = CanonicalRosterMembershipTestSupport.membership(player: player)
        let participantEntry = CanonicalLineupMeaningTestSupport.entry(participant: .gameParticipant(participant))
        let rosterEntry = CanonicalLineupMeaningTestSupport.entry(participant: .currentRosterMembership(rosterMembership), slot: .known(2))

        #expect(participantEntry.participant.playerIdentity == player.identity)
        #expect(rosterEntry.participant.playerIdentity == rosterMembership.playerEvidence.identity)
        #expect(participantEntry != rosterEntry)
        #expect(CanonicalLineupMeaningClassifier.classifyEntry(participantEntry).contains(.validMember))
        #expect(CanonicalLineupMeaningClassifier.classifyEntry(rosterEntry).contains(.validMember))
    }
}
