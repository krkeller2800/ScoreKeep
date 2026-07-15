import Foundation
import Testing
@testable import ScoreKeep

struct LineupConflictAndCompletenessTests {
    @Test func validParticipantAndExactRepeatedParticipantAreClassifiedWithoutMerging() {
        let entry = CanonicalLineupMeaningTestSupport.entry()
        let repeated = CanonicalLineupMeaningTestSupport.entry()
        let lineup = CanonicalLineupMeaningTestSupport.lineup(entries: [entry, repeated])

        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup)
        #expect(classifications.contains(.repeatedParticipantExact))
        #expect(classifications.contains(.duplicateParticipant(CanonicalLineupMeaningTestSupport.playerA)))
    }

    @Test func samePlayerRepeatedWithMatchingAndConflictingSlotEvidenceIsClassified() {
        let player = CanonicalLineupMeaningTestSupport.player()
        let matchingA = CanonicalLineupMeaningTestSupport.entry(player: player, slot: .known(1))
        let matchingB = CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: player, slot: .known(1), sourceIndex: 1)
        let conflicting = CanonicalLineupMeaningTestSupport.entry(id: nil, player: player, slot: .known(2), sourceIndex: 2)

        let matchingClassifications = CanonicalLineupMeaningClassifier.classifyLineup(
            CanonicalLineupMeaningTestSupport.lineup(entries: [matchingA, matchingB])
        )
        let conflictingClassifications = CanonicalLineupMeaningClassifier.classifyLineup(
            CanonicalLineupMeaningTestSupport.lineup(entries: [matchingA, conflicting])
        )

        #expect(matchingClassifications.contains(.duplicateParticipant(CanonicalLineupMeaningTestSupport.playerA)))
        #expect(conflictingClassifications.contains(.participantConflictingSlot(CanonicalLineupMeaningTestSupport.playerA)))
        #expect(conflictingClassifications.contains(.contradictoryEvidence))
    }

    @Test func sameNameAndSameNumberDifferentPlayersRemainDistinct() {
        let playerA = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerA, name: "Jordan Lee", number: "7")
        let playerB = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB, name: "Jordan Lee", number: "7")
        let lineup = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: playerA, slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: playerB, slot: .known(2), sourceIndex: 1)
        ])

        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup)
        #expect(classifications.contains(.duplicateParticipant(CanonicalLineupMeaningTestSupport.playerA)) == false)
        #expect(classifications.contains(.duplicateParticipant(CanonicalLineupMeaningTestSupport.playerB)) == false)
        #expect(classifications.contains(.completeLineup))
    }

    @Test func rosterMemberOmittedAndParticipantAbsentFromCurrentRosterRemainClassifiable() {
        let roster = CanonicalLineupMeaningTestSupport.rosterMemberships()
        let absentPlayer = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerC, name: "Guest Player", number: "99")
        let lineup = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerA), slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: absentPlayer, slot: .known(2), sourceIndex: 1)
        ])

        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup, currentRosterMemberships: roster)
        #expect(classifications.contains(.rosterMemberOmitted(CanonicalLineupMeaningTestSupport.playerB)))
        #expect(classifications.contains(.participantAbsentFromCurrentRoster(CanonicalLineupMeaningTestSupport.playerC)))
    }

    @Test func participantWithMissingInvalidAndUnresolvedIdentityIsExplicit() {
        let missing = CanonicalLineupMeaningTestSupport.entry(player: nil)
        let invalid = CanonicalLineupMeaningTestSupport.entry(
            participant: .invalidPlayerIdentity(.invalid("bad-player-id"), PlayerDisplayEvidence()),
            slot: .known(2)
        )
        let unresolved = CanonicalLineupMeaningTestSupport.entry(
            participant: .unknown(PlayerDisplayEvidence()),
            slot: .known(3)
        )
        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(
            CanonicalLineupMeaningTestSupport.lineup(entries: [missing, invalid, unresolved])
        )

        #expect(classifications.contains(.missingParticipant))
        #expect(classifications.contains(.invalidParticipant))
        #expect(classifications.contains(.unresolvedEvidence))
        #expect(classifications.contains(.incompleteLineup))
    }

    @Test func traditionalSlotEvidencePreservesMissingDuplicateGapAndSentinelValues() {
        let playerB = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB)
        let playerC = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerC)
        let lineup = CanonicalLineupMeaningTestSupport.lineup(mode: .traditional, entries: [
            CanonicalLineupMeaningTestSupport.entry(slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: playerB, slot: .missing, sourceIndex: 1),
            CanonicalLineupMeaningTestSupport.entry(id: nil, player: playerC, slot: .nonHittingSentinel(99), sourceIndex: 2)
        ])
        let duplicateSlot = CanonicalLineupMeaningClassifier.classifyLineup(
            CanonicalLineupMeaningTestSupport.lineup(entries: [
                CanonicalLineupMeaningTestSupport.entry(slot: .known(1)),
                CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: playerB, slot: .known(1), sourceIndex: 1)
            ])
        )
        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup)

        #expect(classifications.contains(.traditionalEvidence))
        #expect(classifications.contains(.missingSlot))
        #expect(classifications.contains(.unsupportedRawEvidence))
        #expect(duplicateSlot.contains(.duplicateSlot(1)))
    }

    @Test func moreAndFewerThanNineTraditionalEntriesRemainRepresentable() {
        let fewer = CanonicalLineupMeaningTestSupport.lineup(entries: [CanonicalLineupMeaningTestSupport.entry(slot: .known(1))])
        let moreEntries = (1...10).map { index in
            CanonicalLineupMeaningTestSupport.entry(
                id: nil,
                player: CanonicalLineupMeaningTestSupport.player(id: StableIdentityAndOrderingTestSupport.fixedUUID("22000000-0000-0000-0000-0000000000\(String(format: "%02d", index))")),
                slot: .known(index),
                sourceIndex: index - 1
            )
        }
        let more = CanonicalLineupMeaningTestSupport.lineup(entries: moreEntries)

        #expect(CanonicalLineupMeaningClassifier.classifyLineup(fewer).contains(.completeLineup))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(more).contains(.completeLineup))
    }

    @Test func everyoneHitsEvidenceAllowsLargeUnknownAndIncompleteLineups() {
        let playerB = CanonicalLineupMeaningTestSupport.player(id: CanonicalLineupMeaningTestSupport.playerB)
        let enabled = CanonicalLineupMeaningTestSupport.lineup(mode: .everyoneHits, entries: [
            CanonicalLineupMeaningTestSupport.entry(slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(id: CanonicalLineupMeaningTestSupport.entryB, player: playerB, slot: .known(10), sourceIndex: 1)
        ])
        let disabled = CanonicalLineupMeaningTestSupport.lineup(mode: .traditional)
        let unknown = CanonicalLineupMeaningTestSupport.lineup(mode: .unknown)
        let ambiguous = CanonicalLineupMeaningTestSupport.lineup(mode: .ambiguous("import omitted mode evidence"))

        #expect(CanonicalLineupMeaningClassifier.classifyLineup(enabled).contains(.everyoneHitsEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(disabled).contains(.traditionalEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(unknown).contains(.unknownModeEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(ambiguous).contains(.ambiguousEvidence))
    }

    @Test func completenessClassifiesEmptyCompleteIncompleteUnsupportedAmbiguousAndContradictoryEvidence() {
        let empty = CanonicalLineupMeaningTestSupport.lineup(entries: [])
        let complete = CanonicalLineupMeaningTestSupport.lineup()
        let unsupported = CanonicalLineupMeaningTestSupport.lineup(entries: [CanonicalLineupMeaningTestSupport.entry(slot: .unsupportedRawValue(-1))])
        let contradictory = CanonicalLineupMeaningTestSupport.lineup(entries: [CanonicalLineupMeaningTestSupport.entry(slot: .conflicting([1, 2]))])

        #expect(CanonicalLineupMeaningClassifier.classifyLineup(empty).contains(.emptyLineup))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(complete).contains(.completeLineup))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(unsupported).contains(.unsupportedRawEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineup(contradictory).contains(.contradictoryEvidence))
    }
}
