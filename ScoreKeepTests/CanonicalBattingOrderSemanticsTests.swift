import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalBattingOrderSemanticsTests {
    @Test func knownMissingInvalidUnsupportedDuplicateAndConflictingSlotsClassify() {
        let known = evidence(slots: [.known(1), .known(2)])
        let missing = evidence(slots: [.missing])
        let invalid = evidence(slots: [.invalidRaw("first")])
        let unsupported = evidence(slots: [.unsupportedRaw(-1)])
        let duplicate = evidence(slots: [.known(1), .known(1)])
        let conflicting = evidence(slots: [.conflicting([1, 2])])

        #expect(CanonicalBattingOrderClassifier.classify(known).contains(.knownDistinctSlots))
        #expect(CanonicalBattingOrderClassifier.classify(missing).contains(.missingSlot))
        #expect(CanonicalBattingOrderClassifier.classify(invalid).contains(.invalidRawSlot))
        #expect(CanonicalBattingOrderClassifier.classify(unsupported).contains(.unsupportedRawSlot(-1)))
        #expect(CanonicalBattingOrderClassifier.classify(duplicate).contains(.duplicateSlot(1)))
        #expect(CanonicalBattingOrderClassifier.classify(conflicting).contains(.conflictingSlotEvidence))
    }

    @Test func playerWithoutSlotAndUnresolvedParticipantWithSlotRemainRepresentable() {
        let playerWithoutSlot = CanonicalBattingOrderEntry(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            participant: .gameParticipant(CanonicalLineupMeaningTestSupport.participant()),
            slotEvidence: .playerWithoutSlot
        )
        let unresolved = CanonicalBattingOrderEntry(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            participant: .unknown(PlayerDisplayEvidence()),
            slotEvidence: .unresolvedParticipant(slot: 3)
        )
        let classifications = CanonicalBattingOrderClassifier.classify(
            CanonicalBattingOrderEvidence(
                gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
                lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
                context: .traditional,
                entries: [playerWithoutSlot, unresolved]
            )
        )

        #expect(classifications.contains(.playerWithoutSlot))
        #expect(classifications.contains(.unresolvedParticipantWithSlot(3)))
    }

    @Test func traditionalEveryoneHitsUnknownAndSentinelEvidenceClassify() {
        let traditional = evidence(context: .traditional, slots: [.known(1)])
        let everyoneHits = evidence(context: .everyoneHits, slots: [.known(10), .nonHittingSentinel(99)])
        let unknown = evidence(context: .unknown, slots: [.known(1)])

        #expect(CanonicalBattingOrderClassifier.classify(traditional).contains(.traditionalContext))
        #expect(CanonicalBattingOrderClassifier.classify(everyoneHits).contains(.everyoneHitsContext))
        #expect(CanonicalBattingOrderClassifier.classify(everyoneHits).contains(.nonHittingSentinel(99)))
        #expect(CanonicalBattingOrderClassifier.classify(unknown).contains(.unknownLineupMode))
    }

    @Test func samePlayerDifferentGamesAndHistoricalChangesRemainSeparate() {
        let player = CanonicalLineupMeaningTestSupport.player()
        let gameA = evidence(gameID: CanonicalLineupMeaningTestSupport.gameA, player: player, slots: [.known(1)])
        let gameB = evidence(gameID: CanonicalLineupMeaningTestSupport.gameB, player: player, slots: [.known(7)])
        let historical = CanonicalBattingOrderEvidence(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            context: .traditional,
            entries: [entry(player: player, slot: .historicalSlot(4), sourceIndex: 0)],
            historicalChangeEvidence: true
        )

        #expect(gameA.gameIdentity != gameB.gameIdentity)
        #expect(gameA.entries[0].slotEvidence != gameB.entries[0].slotEvidence)
        #expect(CanonicalBattingOrderClassifier.classify(historical).contains(.historicalSlotEvidence))
        #expect(CanonicalBattingOrderClassifier.progressionHint(for: historical) == .historicalContext([4]))
    }

    @Test func samePlayerAndDifferentPlayersConflictingSlotEvidenceClassifies() {
        let player = CanonicalLineupMeaningTestSupport.player()
        let samePlayer = CanonicalBattingOrderEvidence(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            context: .traditional,
            entries: [entry(player: player, slot: .known(1), sourceIndex: 0), entry(player: player, slot: .known(2), sourceIndex: 1)]
        )
        let differentPlayersSameSlot = evidence(slots: [.known(1), .known(1)])

        #expect(CanonicalBattingOrderClassifier.classify(samePlayer).contains(.conflictingSlotEvidence))
        #expect(CanonicalBattingOrderClassifier.classify(differentPlayersSameSlot).contains(.duplicateSlot(1)))
    }

    @Test func rosterDisplayJerseyAndSourceOrderDoNotDefineBattingOrder() {
        let entry = CanonicalBattingOrderEntry(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            participant: .gameParticipant(CanonicalLineupMeaningTestSupport.participant()),
            slotEvidence: .known(3),
            sourceOrderEvidence: OrderEvidence(kind: .sourceFile, value: 0, sourceIndex: 0),
            rosterOrderEvidence: OrderEvidence(kind: .battingOrder, value: 9),
            displaySortEvidence: OrderEvidence(kind: .displaySort, value: 1),
            jerseyNumberEvidence: .present("99")
        )
        let classifications = CanonicalBattingOrderClassifier.classify(
            CanonicalBattingOrderEvidence(
                gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
                lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
                context: .traditional,
                entries: [entry]
            )
        )

        #expect(classifications.contains(.sourceOrderEvidence))
        #expect(classifications.contains(.rosterOrderIgnored))
        #expect(classifications.contains(.displaySortIgnored))
        #expect(classifications.contains(.jerseyNumberIgnored))
        #expect(classifications.contains(.knownDistinctSlots))
    }

    @Test func currentPlayerBatOrderChangeDoesNotRewriteHistoricalLineupEvidence() {
        let lineupSlot = CanonicalBattingSlotEvidence.known(1)
        let currentRosterHint = OrderEvidence(kind: .battingOrder, value: 8)

        #expect(lineupSlot.knownSlotValue == 1)
        #expect(currentRosterHint.value == 8)
        #expect(lineupSlot.knownSlotValue != currentRosterHint.value)
    }

    @Test func progressionHintsDoNotProjectCurrentOrNextBatter() {
        let ordered = evidence(slots: [.known(2), .known(1)])
        let missing = evidence(slots: [.known(1), .missing])
        let duplicate = evidence(slots: [.known(1), .known(1)])

        #expect(CanonicalBattingOrderClassifier.progressionHint(for: ordered) == .orderedKnownSlots([1, 2], direction: .forward, expectsWraparound: true))
        #expect(CanonicalBattingOrderClassifier.progressionHint(for: missing) == .unknownIncompleteEvidence)
        #expect(CanonicalBattingOrderClassifier.progressionHint(for: duplicate) == .ambiguousDuplicateSlots([1]))
    }

    @Test func importedFixtureBattingEvidenceUsesCompatibilityValuesWithoutMutation() throws {
        let lineupGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let pitcherGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("PitcherGame.ScoreKeep_Games")
        let missingRoster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MissingOptionalValues.ScoreKeep_Players")
        let lineup = try #require(lineupGame.lineups.first.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: lineupGame.id) })
        let batting = CanonicalBattingOrderEvidence(lineup: lineup)

        #expect(CanonicalBattingOrderClassifier.classify(batting).contains(.everyoneHitsContext))
        #expect(pitcherGame.pitchers.first?.player.batOrder == 99)
        #expect(missingRoster.first?.batOrder == 51)
    }

    @Test func repeatedEvaluationIsDeterministic() {
        let batting = evidence(slots: [.known(2), .known(1), .nonHittingSentinel(99)])
        let first = CanonicalBattingOrderClassifier.classify(batting)
        let second = CanonicalBattingOrderClassifier.classify(batting)

        #expect(first == second)
        #expect(CanonicalBattingOrderClassifier.progressionHint(for: batting) == CanonicalBattingOrderClassifier.progressionHint(for: batting))
    }

    private func evidence(
        context: CanonicalBattingLineupContext = .traditional,
        gameID: UUID = CanonicalLineupMeaningTestSupport.gameA,
        player: ReusableCanonicalPlayer? = nil,
        slots: [CanonicalBattingSlotEvidence]
    ) -> CanonicalBattingOrderEvidence {
        CanonicalBattingOrderEvidence(
            gameIdentity: .valid(gameID),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            context: context,
            entries: slots.enumerated().map { index, slot in
                entry(
                    player: player ?? CanonicalLineupMeaningTestSupport.player(id: StableIdentityAndOrderingTestSupport.fixedUUID("51000000-0000-0000-0000-0000000000\(String(format: "%02d", index + 1))")),
                    slot: slot,
                    sourceIndex: index
                )
            }
        )
    }

    private func entry(
        player: ReusableCanonicalPlayer,
        slot: CanonicalBattingSlotEvidence,
        sourceIndex: Int
    ) -> CanonicalBattingOrderEntry {
        CanonicalBattingOrderEntry(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            participant: .gameParticipant(CanonicalLineupMeaningTestSupport.participant(player: player)),
            slotEvidence: slot,
            sourceOrderEvidence: OrderEvidence(kind: .sourceFile, value: sourceIndex, sourceIndex: sourceIndex),
            jerseyNumberEvidence: player.display.jerseyNumber
        )
    }
}
