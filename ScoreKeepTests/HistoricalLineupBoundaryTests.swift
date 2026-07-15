import Testing
@testable import ScoreKeep

struct HistoricalLineupBoundaryTests {
    @Test func currentPlayerRenameDoesNotAlterHistoricalLineupIdentity() {
        let historicalPlayer = CanonicalLineupMeaningTestSupport.player(name: "Casey Smith")
        let renamedPlayer = CanonicalLineupMeaningTestSupport.player(name: "Casey Johnson")
        let historical = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: historicalPlayer)
        ])
        let currentRename = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: renamedPlayer)
        ])

        #expect(historical == currentRename)
        #expect(CanonicalLineupMeaningClassifier.compareIdentity(historical, currentRename) == .sameIdentityMatchingEvidence)
    }

    @Test func currentJerseyPhotoAndPositionChangesDoNotAlterHistoricalMembership() {
        let historicalPlayer = CanonicalLineupMeaningTestSupport.player(number: "12", position: "SS")
        let changedPlayer = CanonicalLineupMeaningTestSupport.player(number: "44", position: "CF")
        let historicalEntry = CanonicalLineupMeaningTestSupport.entry(
            player: historicalPlayer,
            position: .present("SS")
        )
        let changedCurrentEntry = CanonicalLineupMeaningTestSupport.entry(
            player: changedPlayer,
            position: .present("CF")
        )

        #expect(historicalEntry.participant.playerIdentity == changedCurrentEntry.participant.playerIdentity)
        #expect(historicalEntry.rawPosition != changedCurrentEntry.rawPosition)
        #expect(CanonicalLineupMeaningClassifier.classifyEntry(changedCurrentEntry).contains(.validMember))
    }

    @Test func currentTeamChangeAndRosterRemovalDoNotEraseHistoricalLineupEvidence() {
        let historicalPlayer = CanonicalLineupMeaningTestSupport.player()
        let historicalParticipant = CanonicalLineupMeaningTestSupport.participant(player: historicalPlayer, sideRole: .home)
        let removedFromRosterEntry = CanonicalLineupMeaningTestSupport.entry(
            participant: .absentFromCurrentRoster(historicalPlayer),
            slot: .known(1)
        )
        let historicalEntry = CanonicalLineupMeaningTestSupport.entry(
            participant: .gameParticipant(historicalParticipant),
            slot: .known(1)
        )

        #expect(historicalEntry.participant.playerIdentity == removedFromRosterEntry.participant.playerIdentity)
        #expect(CanonicalLineupMeaningClassifier.classifyEntry(removedFromRosterEntry).contains(.playerAbsentFromCurrentRoster))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(CanonicalLineupMeaningTestSupport.lineup(entries: [removedFromRosterEntry])).contains(.participantAbsentFromCurrentRoster(CanonicalLineupMeaningTestSupport.playerA)))
    }

    @Test func currentRosterAdditionDoesNotFabricateHistoricalLineupEvidence() {
        let roster = CanonicalLineupMeaningTestSupport.rosterMemberships()
        let lineup = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerA))
        ])

        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup, currentRosterMemberships: roster)
        #expect(classifications.contains(.rosterMemberOmitted(CanonicalLineupMeaningTestSupport.playerB)))
        #expect(lineup.entries.count == 1)
    }

    @Test func currentBatOrderChangeDoesNotRewriteHistoricalLineupFacts() {
        let slotOne = CanonicalLineupMeaningTestSupport.entry(slot: .known(1))
        let rosterChangedBatOrder = CanonicalRosterMembershipTestSupport.membership(
            display: CanonicalRosterMembershipTestSupport.display(battingOrder: 7)
        )

        #expect(slotOne.battingSlot == .known(1))
        #expect(rosterChangedBatOrder.displayEvidence.battingOrder == OrderEvidence(kind: .battingOrder, value: 7))
        #expect(slotOne.battingSlot != .known(rosterChangedBatOrder.displayEvidence.battingOrder?.value ?? 0))
    }

    @Test func defensivePositionPitcherAndSubstitutionEvidenceArePreservedAsBoundaries() {
        let entry = LineupEntryEvidence(
            participant: .gameParticipant(CanonicalLineupMeaningTestSupport.participant()),
            battingSlot: .known(1),
            sourceOrder: OrderEvidence(kind: .sourceFile, value: 0, sourceIndex: 0),
            rawPosition: .unknown("legacy blank position"),
            pitcherRole: .pitcherCandidate,
            substitutionEvidence: .laterLineupComposition,
            source: .historicalGameParticipation
        )

        let classifications = CanonicalLineupMeaningClassifier.classifyEntry(entry)
        #expect(classifications.contains(.pitcherRoleEvidence))
        #expect(classifications.contains(.substitutionEvidence))
        #expect(classifications.contains(.validMember))
    }

    @Test func orderingBoundariesRemainSeparateAndDeterministic() {
        let playerA = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerA, name: "Zed", number: "9")
        let playerB = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB, name: "Ada", number: "1")
        let entries = [
            CanonicalLineupMeaningTestSupport.entry(player: playerA, slot: .known(2), sourceIndex: 0),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: playerB, slot: .known(1), sourceIndex: 1)
        ]
        let lineup = CanonicalLineupMeaningTestSupport.lineup(entries: entries)

        let first = CanonicalLineupMeaningClassifier.classifyLineup(lineup)
        let second = CanonicalLineupMeaningClassifier.classifyLineup(
            CanonicalLineupMeaningTestSupport.lineup(entries: Array(entries.reversed()))
        )

        #expect(entries[0].sourceOrder == OrderEvidence(kind: .sourceFile, value: 0, sourceIndex: 0))
        #expect(entries[0].battingSlot == .known(2))
        #expect(first == second)
        #expect(first.contains(.completeLineup))
    }

    @Test func duplicateAndMissingSlotsAreNotSilentlyReorderedOrFabricated() {
        let duplicate = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB), slot: .known(1), sourceIndex: 1)
        ])
        let missing = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(slot: .missing)
        ])

        #expect(CanonicalLineupMeaningClassifier.classifyLineup(duplicate).contains(.duplicateSlot(1)))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(missing).contains(.missingSlot))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(missing).contains(.completeLineup) == false)
    }
}
