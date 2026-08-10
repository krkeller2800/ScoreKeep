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

struct CanonicalBatterProjectionTests {
    @Test func firstNextProgressionWraparoundAndDeterminism() {
        let lineup = battingLineup(count: 3)
        let first = CanonicalBatterProjector.project(input(lineup: lineup))
        let afterOne = CanonicalBatterProjector.project(input(lineup: lineup, events: [event(sequence: 1, batter: lineup.entries[0].participant)]))
        let wrapped = CanonicalBatterProjector.project(input(lineup: lineup, events: [
            event(sequence: 1, batter: lineup.entries[0].participant),
            event(sequence: 2, batter: lineup.entries[1].participant),
            event(sequence: 3, batter: lineup.entries[2].participant)
        ]))

        #expect(first.disposition == .resolved)
        #expect(first.currentSlot == 1)
        #expect(first.nextSlot == 2)
        #expect(afterOne.currentSlot == 2)
        #expect(afterOne.nextSlot == 3)
        #expect(wrapped.currentSlot == 1)
        #expect(wrapped.nextSlot == 2)
        #expect(wrapped.wraparoundApplied)
        #expect(CanonicalBatterProjector.project(input(lineup: lineup, events: [event(sequence: 1, batter: lineup.entries[0].participant)])) == afterOne)
    }

    @Test func homeVisitingProgressionAndInningBoundariesRemainIndependent() {
        let home = battingLineup(side: .home, count: 3)
        let visiting = battingLineup(side: .visiting, count: 3)
        let homeEvent = event(sequence: 1, batter: home.entries[0].participant, inning: 1.0, side: .home)
        let visitingEvent = event(sequence: 1, batter: visiting.entries[0].participant, inning: 1.0, side: .visiting)
        let laterHomeEvent = event(sequence: 2, batter: home.entries[1].participant, inning: 2.0, side: .home)

        let homeProjection = CanonicalBatterProjector.project(input(side: .home, lineup: home, events: [homeEvent, visitingEvent, laterHomeEvent]))
        let visitingProjection = CanonicalBatterProjector.project(input(side: .visiting, lineup: visiting, events: [homeEvent, visitingEvent, laterHomeEvent]))

        #expect(homeProjection.currentSlot == 3)
        #expect(visitingProjection.currentSlot == 2)
        #expect(homeProjection.sourceEvidenceIgnored.contains("opposingSideEvents"))
        #expect(visitingProjection.sourceEvidenceIgnored.contains("opposingSideEvents"))
    }

    @Test func traditionalAndEveryoneHitsUseLineupEvidenceOnly() {
        let traditional = battingLineup(mode: .traditional, count: 9)
        let everyoneHits = battingLineup(mode: .everyoneHits, count: 11)

        let traditionalProjection = CanonicalBatterProjector.project(input(lineup: traditional, events: [event(sequence: 1, batter: traditional.entries[8].participant)]))
        let everyoneHitsProjection = CanonicalBatterProjector.project(input(lineup: everyoneHits, events: [event(sequence: 1, batter: everyoneHits.entries[8].participant)]))

        #expect(traditionalProjection.lineupContext == .traditional)
        #expect(traditionalProjection.currentSlot == 1)
        #expect(everyoneHitsProjection.lineupContext == .everyoneHits)
        #expect(everyoneHitsProjection.currentSlot == 10)
        #expect(everyoneHitsProjection.nextSlot == 11)
        #expect(everyoneHitsProjection.sourceEvidenceIgnored.contains("currentRosterOrder"))
    }

    @Test func incompleteAmbiguousUnsupportedAndConflictingLineupEvidenceClassifiesWithoutFabrication() {
        let empty = CanonicalBatterProjector.project(input(lineup: battingLineup(count: 0)))
        let missingSlot = CanonicalBatterProjector.project(input(lineup: battingLineup(slots: [.known(1), .missing])))
        let duplicateSlot = CanonicalBatterProjector.project(input(lineup: battingLineup(slots: [.known(1), .known(1)])))
        let gap = CanonicalBatterProjector.project(input(lineup: battingLineup(slots: [.known(1), .known(3)])))
        let conflicting = CanonicalBatterProjector.project(input(lineup: battingLineup(slots: [.known(1), .conflicting([1, 2])])))
        let missingParticipant = CanonicalBatterProjector.project(input(lineup: battingLineup(entries: [
            entry(slot: .known(1), participant: .missingPlayerIdentity(PlayerDisplayEvidence()))
        ])))
        let invalidParticipant = CanonicalBatterProjector.project(input(lineup: battingLineup(entries: [
            entry(slot: .known(1), participant: .invalidPlayerIdentity(.invalid("bad-player"), PlayerDisplayEvidence()))
        ])))
        let unknownMode = CanonicalBatterProjector.project(input(lineup: battingLineup(mode: .unknown, count: 2)))

        #expect(empty.disposition == .incomplete)
        #expect(missingSlot.disposition == .resolvedWithWarnings)
        #expect(gap.disposition == .resolvedWithWarnings)
        #expect(duplicateSlot.disposition == .ambiguous)
        #expect(conflicting.disposition == .contradictory)
        #expect(missingParticipant.disposition == .incomplete)
        #expect(invalidParticipant.disposition == .rejected)
        #expect(unknownMode.disposition == .unresolved)
        #expect(duplicateSlot.currentBatter == nil)
        #expect(conflicting.currentBatter == nil)
    }

    @Test func unresolvedAndUnorderedEventsDoNotFabricateBatterProjection() {
        let lineup = battingLineup(count: 3)
        let unresolved = CanonicalBatterProjector.project(input(lineup: lineup, events: [
            event(sequence: 1, batter: lineup.entries[0].participant),
            event(sequence: 2, batter: .unknown(PlayerDisplayEvidence()))
        ]))
        let missingSequence = CanonicalBatterProjector.project(input(lineup: lineup, events: [
            event(sequence: nil, batter: lineup.entries[0].participant)
        ]))
        let duplicateSequence = CanonicalBatterProjector.project(input(lineup: lineup, events: [
            event(sequence: 1, batter: lineup.entries[0].participant),
            event(sequence: 1, batter: lineup.entries[1].participant)
        ]))

        #expect(unresolved.disposition == .unresolved)
        #expect(missingSequence.disposition == .resolvedWithWarnings)
        #expect(duplicateSequence.disposition == .ambiguous)
        #expect(duplicateSequence.currentBatter == nil)
    }

    @Test func historicalLineupEvidenceSurvivesRosterAndPlayerBatOrderChanges() {
        var lineup = battingLineup(count: 2)
        let rosterHint = CanonicalBattingOrderEntry(
            gameIdentity: lineup.entries[0].gameIdentity,
            lineupIdentity: lineup.entries[0].lineupIdentity,
            participant: lineup.entries[0].participant,
            slotEvidence: lineup.entries[0].slotEvidence,
            rosterOrderEvidence: OrderEvidence(kind: .battingOrder, value: 8),
            displaySortEvidence: OrderEvidence(kind: .displaySort, value: 1),
            jerseyNumberEvidence: .present("99")
        )
        lineup = CanonicalBattingOrderEvidence(
            gameIdentity: lineup.gameIdentity,
            lineupIdentity: lineup.lineupIdentity,
            context: lineup.context,
            entries: [rosterHint, lineup.entries[1]]
        )

        let projection = CanonicalBatterProjector.project(input(lineup: lineup))

        #expect(projection.currentSlot == 1)
        #expect(projection.sourceEvidenceIgnored.contains("currentRosterOrder"))
        #expect(projection.sourceEvidenceIgnored.contains("displaySortOrder"))
        #expect(lineup.entries[0].slotEvidence.knownSlotValue == 1)
    }

    @Test func knownSubstitutionChangesSlotAndAmbiguousSubstitutionDoesNot() {
        let lineup = battingLineup(count: 3)
        let incoming = participant(id: "51000000-0000-0000-0000-000000000099", name: "Incoming Batter", side: .home)
        let known = substitution(incoming: incoming, outgoing: lineup.entries[1].participant, slot: 2, order: 1)
        let ambiguous = CanonicalSubstitutionEvidence(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            incoming: .participant(incoming),
            outgoing: .participant(lineup.entries[2].participant),
            roleEvidence: [.batterReplacement],
            source: .syntheticVerification
        )

        let applied = CanonicalBatterProjector.project(input(lineup: lineup, events: [event(sequence: 1, batter: lineup.entries[0].participant)], substitutions: [known]))
        let notApplied = CanonicalBatterProjector.project(input(lineup: lineup, events: [event(sequence: 1, batter: lineup.entries[0].participant)], substitutions: [ambiguous]))

        #expect(applied.currentSlot == 2)
        #expect(applied.currentBatter?.participant.playerIdentity == incoming.playerIdentity)
        #expect(applied.disposition == .resolvedWithWarnings)
        #expect(notApplied.currentBatter?.participant.playerIdentity == lineup.entries[1].participant.playerIdentity)
        #expect(notApplied.disposition == .unresolved)
    }

    @Test func replacementBeforeUnscoredSlotReceivesNextScoringCell() {
        let lineup = battingLineup(count: 3)
        let replacement = participant(id: "51000000-0000-0000-0000-000000000101", name: "Replacement One", side: .home)
        let projection = CanonicalBatterProjector.project(input(
            lineup: lineup,
            substitutions: [substitution(incoming: replacement, outgoing: lineup.entries[0].participant, slot: 1, order: 1)]
        ))

        #expect(projection.currentSlot == 1)
        #expect(projection.currentBatter?.participant.playerIdentity == replacement.playerIdentity)
        #expect(projection.currentBatter?.participant.playerIdentity != lineup.entries[0].participant.playerIdentity)
    }

    @Test func replacementAfterHistoricalAtBatsPreservesPastAndReceivesTurnoverSlot() {
        let lineup = battingLineup(count: 3)
        let replacement = participant(id: "51000000-0000-0000-0000-000000000102", name: "Replacement Two", side: .home)
        let historicalFirst = event(sequence: 1, batter: lineup.entries[0].participant)
        let projection = CanonicalBatterProjector.project(input(
            lineup: lineup,
            events: [
                historicalFirst,
                event(sequence: 2, batter: lineup.entries[1].participant),
                event(sequence: 3, batter: lineup.entries[2].participant)
            ],
            substitutions: [substitution(incoming: replacement, outgoing: lineup.entries[0].participant, slot: 1, order: 1)]
        ))

        #expect(historicalFirst.participants.batter?.playerIdentity == lineup.entries[0].participant.playerIdentity)
        #expect(projection.currentSlot == 1)
        #expect(projection.currentBatter?.participant.playerIdentity == replacement.playerIdentity)
    }

    @Test func battingOrderTurnoverAfterReplacementKeepsReplacementInSlot() {
        let lineup = battingLineup(count: 3)
        let replacement = participant(id: "51000000-0000-0000-0000-000000000103", name: "Replacement Three", side: .home)
        let projection = CanonicalBatterProjector.project(input(
            lineup: lineup,
            events: [
                event(sequence: 1, batter: lineup.entries[0].participant),
                event(sequence: 2, batter: lineup.entries[1].participant),
                event(sequence: 3, batter: lineup.entries[2].participant),
                event(sequence: 4, batter: replacement),
                event(sequence: 5, batter: lineup.entries[1].participant),
                event(sequence: 6, batter: lineup.entries[2].participant)
            ],
            substitutions: [substitution(incoming: replacement, outgoing: lineup.entries[0].participant, slot: 1, order: 1)]
        ))

        #expect(projection.currentSlot == 1)
        #expect(projection.currentBatter?.participant.playerIdentity == replacement.playerIdentity)
        #expect(projection.currentBatter?.participant.playerIdentity != lineup.entries[0].participant.playerIdentity)
    }

    @Test func multipleReplacementsLeaveOnlyCurrentSlotOccupantEligible() {
        let lineup = battingLineup(count: 3)
        let firstReplacement = participant(id: "51000000-0000-0000-0000-000000000104", name: "First Replacement", side: .home)
        let secondReplacement = participant(id: "51000000-0000-0000-0000-000000000105", name: "Second Replacement", side: .home)
        let projection = CanonicalBatterProjector.project(input(
            lineup: lineup,
            events: [
                event(sequence: 1, batter: lineup.entries[0].participant),
                event(sequence: 2, batter: lineup.entries[1].participant),
                event(sequence: 3, batter: lineup.entries[2].participant)
            ],
            substitutions: [
                substitution(incoming: firstReplacement, outgoing: lineup.entries[0].participant, slot: 1, order: 1),
                substitution(incoming: secondReplacement, outgoing: firstReplacement, slot: 1, order: 2)
            ]
        ))

        #expect(projection.currentSlot == 1)
        #expect(projection.currentBatter?.participant.playerIdentity == secondReplacement.playerIdentity)
        #expect(projection.currentBatter?.participant.playerIdentity != firstReplacement.playerIdentity)
        #expect(projection.currentBatter?.participant.playerIdentity != lineup.entries[0].participant.playerIdentity)
    }

    @Test func normalProgressionWithoutReplacementStillUsesLineupOrder() {
        let lineup = battingLineup(count: 3)
        let projection = CanonicalBatterProjector.project(input(
            lineup: lineup,
            events: [event(sequence: 1, batter: lineup.entries[0].participant)]
        ))

        #expect(projection.currentSlot == 2)
        #expect(projection.currentBatter?.participant.playerIdentity == lineup.entries[1].participant.playerIdentity)
        #expect(projection.nextSlot == 3)
    }

    @Test func projectionInputsRemainUnchangedAndReplayPrepared() throws {
        let fixture = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let importedLineup = try #require(fixture.lineups.first.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: fixture.id) })
        let lineup = CanonicalBattingOrderEvidence(lineup: importedLineup)
        let original = input(lineup: lineup)

        let first = CanonicalBatterProjector.project(original)
        let second = CanonicalBatterProjector.project(original)

        #expect(first == second)
        #expect(original.lineup == lineup)
        #expect(first.sourceEvidenceIgnored.contains("swiftDataFetchOrder"))
        #expect(first.sourceEvidenceIgnored.contains("currentDate"))
        #expect(first.validation.findings.map(\.code) == second.validation.findings.map(\.code))
    }

    private func input(
        side: TeamSideRole = .home,
        lineup: CanonicalBattingOrderEvidence,
        events: [CanonicalScoringEventEvidence] = [],
        substitutions: [CanonicalSubstitutionEvidence] = []
    ) -> CanonicalBatterProjectionInput {
        CanonicalBatterProjectionInput(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            battingSide: side,
            lineup: lineup,
            recordedEvents: events,
            substitutions: substitutions,
            sourceLocation: "CanonicalBatterProjectionTests"
        )
    }

    private func battingLineup(
        side: TeamSideRole = .home,
        mode: CanonicalBattingLineupContext = .traditional,
        count: Int
    ) -> CanonicalBattingOrderEvidence {
        battingLineup(side: side, mode: mode, slots: count <= 0 ? [] : (1...count).map { .known($0) })
    }

    private func battingLineup(
        side: TeamSideRole = .home,
        mode: CanonicalBattingLineupContext = .traditional,
        slots: [CanonicalBattingSlotEvidence]
    ) -> CanonicalBattingOrderEvidence {
        battingLineup(mode: mode, entries: slots.enumerated().map { index, slot in
            entry(slot: slot, participant: participant(id: "51000000-0000-0000-0000-0000000000\(String(format: "%02d", index + 1))", name: "Batter \(index + 1)", side: side))
        })
    }

    private func battingLineup(
        mode: CanonicalBattingLineupContext = .traditional,
        entries: [CanonicalBattingOrderEntry]
    ) -> CanonicalBattingOrderEvidence {
        CanonicalBattingOrderEvidence(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            context: mode,
            entries: entries
        )
    }

    private func entry(
        slot: CanonicalBattingSlotEvidence,
        participant: LineupParticipantEvidence
    ) -> CanonicalBattingOrderEntry {
        CanonicalBattingOrderEntry(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            lineupIdentity: .valid(CanonicalLineupMeaningTestSupport.lineupA),
            participant: participant,
            slotEvidence: slot
        )
    }

    private func participant(id: String, name: String, side: TeamSideRole) -> LineupParticipantEvidence {
        .gameParticipant(
            CanonicalLineupMeaningTestSupport.participant(
                player: CanonicalLineupMeaningTestSupport.player(
                    id: StableIdentityAndOrderingTestSupport.fixedUUID(id),
                    name: name
                ),
                sideRole: side
            )
        )
    }

    private func event(
        sequence: Int?,
        batter: LineupParticipantEvidence?,
        inning: CGFloat = 1.0,
        side: TeamSideRole = .home
    ) -> CanonicalScoringEventEvidence {
        CanonicalScoringEventEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("70000000-0000-0000-0000-0000000000\(String(format: "%02d", sequence ?? 99))")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            orderingEvidence: sequence.map { [.knownSequence(OrderEvidence(kind: .eventSequence, value: $0))] } ?? [.missingSequence],
            inningContext: nil,
            teamSide: side,
            participants: ScoringEventParticipantEvidence(batter: batter),
            resultEvidence: .batterReachesBase(rawValue: "Single")
        )
    }

    private func substitution(
        incoming: LineupParticipantEvidence,
        outgoing: LineupParticipantEvidence,
        slot: Int,
        order: Int
    ) -> CanonicalSubstitutionEvidence {
        CanonicalSubstitutionEvidence(
            substitutionIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("72000000-0000-0000-0000-000000000001")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            incoming: .participant(incoming),
            outgoing: .participant(outgoing),
            effectiveOrder: OrderEvidence(kind: .substitution, value: order),
            battingSlotContext: .known(slot),
            roleEvidence: [.batterReplacement],
            source: .syntheticVerification
        )
    }
}
