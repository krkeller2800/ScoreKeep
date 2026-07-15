import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalGameReplayStageATests {
    @Test func validEmptyReplayProducesInitialFinalState() {
        let input = ReplayTestSupport.input(events: [])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .complete)
        #expect(result.appliedEventCount == 0)
        #expect(result.unappliedEventCount == 0)
        #expect(result.eventSummaries.isEmpty)
        #expect(result.finalState.score == CanonicalProjectedScore())
        #expect(result.finalState.outs.outs == .known(0))
    }

    @Test func invalidInitialStateIsRejectedBeforeReplay() {
        let input = ReplayTestSupport.input(initialOuts: CanonicalOutsState(outs: .known(4)), events: [ReplayTestSupport.event(sequence: 1, raw: "Single")])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .rejected)
        #expect(result.appliedEventCount == 0)
        #expect(result.eventSummaries.isEmpty)
        #expect(result.validationFindings.map(\.code).contains("outs.invalid"))
    }

    @Test func validOrderingAppliesExplicitSequences() {
        let input = ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 2, raw: "Ground Out", eventID: ReplayTestSupport.eventID(2), batter: ReplayTestSupport.batter(2)),
            ReplayTestSupport.event(sequence: 1, raw: "Ground Out", eventID: ReplayTestSupport.eventID(1), batter: ReplayTestSupport.batter(1))
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .complete)
        #expect(result.eventSummaries.map(\.sourceSequence) == [1, 2])
        #expect(result.appliedEventCount == 2)
    }

    @Test func missingOrderingDoesNotFabricateSequence() {
        let input = ReplayTestSupport.input(events: [ReplayTestSupport.event(sequence: nil, raw: "Single")])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .incomplete)
        #expect(result.appliedEventCount == 0)
        #expect(result.validationFindings.map(\.code).contains("replay.orderMissingSequence"))
    }

    @Test func duplicateAndConflictingOrderingStopBeforeApplication() {
        let duplicate = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single", eventID: ReplayTestSupport.eventID(1), batter: ReplayTestSupport.batter(1)),
            ReplayTestSupport.event(sequence: 1, raw: "Single", eventID: ReplayTestSupport.eventID(2), batter: ReplayTestSupport.batter(2))
        ]))
        let conflicting = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [
            ReplayTestSupport.event(ordering: [.conflictingSequenceAndScorecardColumn(sequence: 1, column: 3)], raw: "Single")
        ]))

        #expect(duplicate.disposition == .contradictory)
        #expect(duplicate.appliedEventCount == 0)
        #expect(conflicting.disposition == .contradictory)
        #expect(conflicting.appliedEventCount == 0)
    }
}

struct CanonicalGameReplayStageBTests {
    @Test func oneSimpleEventAppliesAndInputRemainsUnchanged() {
        let input = ReplayTestSupport.input(events: [ReplayTestSupport.event(sequence: 1, raw: "Single")])
        let original = input
        let result = CanonicalGameReplay.replay(input)
        let repeated = CanonicalGameReplay.replay(input)

        #expect(input == original)
        #expect(result.appliedEventCount == 1)
        #expect(result.eventSummaries.count == 1)
        #expect(result.eventSummaries[0].applied)
        #expect(result.finalState.baseOccupancy.runnerStates.count == 1)
        #expect(result.finalState.score == CanonicalProjectedScore())
        #expect(result.finalState == repeated.finalState)
        #expect(result.eventSummaries == repeated.eventSummaries)
    }
}

struct CanonicalGameReplayStageCTests {
    @Test func multipleEventsMoveRunnerRecordOutAndScore() {
        let batter1 = ReplayTestSupport.batter(1)
        let runner1 = ReplayTestSupport.runner(1)
        let input = ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single", batter: batter1),
            ReplayTestSupport.event(ordering: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 1))], raw: "Home", eventID: ReplayTestSupport.eventID(2), resultEvidence: .runnerScores(rawValue: "Home"), batter: nil, runnerAdvancement: [.scored(runner: runner1, sourceBase: .first)])
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.appliedEventCount == 2)
        #expect(result.finalState.score.visiting == 1)
        #expect(result.eventSummaries[1].changedFacts.contains(.runEvidence))
        #expect(result.finalState.baseOccupancy.runnerStates.isEmpty)
    }

    @Test func inningSpanningSequenceResetsOutsBasesAndChangesHalf() {
        let input = ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Ground Out", batter: ReplayTestSupport.batter(1)),
            ReplayTestSupport.event(sequence: 2, raw: "Ground Out", batter: ReplayTestSupport.batter(2)),
            ReplayTestSupport.event(sequence: 3, raw: "Ground Out", batter: ReplayTestSupport.batter(3))
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.appliedEventCount == 3)
        #expect(result.finalState.outs.outs == .known(0))
        #expect(result.finalState.inning?.half == .known(.bottom))
        #expect(result.finalState.baseOccupancy.runnerStates.isEmpty)
    }

    @Test func rejectedEventDoesNotPartiallyChangeState() {
        let input = ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single"),
            ReplayTestSupport.event(sequence: 2, raw: "Single", runnerAdvancement: [.scored(runner: ReplayTestSupport.runner(99), sourceBase: .first)])
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .partial)
        #expect(result.appliedEventCount == 1)
        #expect(result.unappliedEventCount == 1)
        #expect(result.finalState.score == CanonicalProjectedScore())
        #expect(result.finalState.baseOccupancy.runnerStates.count == 1)
        #expect(result.eventSummaries.last?.applied == false)
    }
}

struct CanonicalGameReplayStageDTests {
    @Test func batterAndPitcherFinalProjectionAreShallowFinalStateFacts() {
        let lineup = ReplayTestSupport.lineup(side: .visiting, count: 3)
        let pitcher = ReplayTestSupport.pitcherInput(side: .home)
        let input = ReplayTestSupport.input(lineups: [lineup], pitchers: [pitcher], events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single", batter: lineup.lineup.entries[0].participant),
            ReplayTestSupport.event(sequence: 2, raw: "Ground Out", batter: lineup.lineup.entries[1].participant)
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.finalState.projectedBatters.first?.currentSlot == 3)
        #expect(result.finalState.projectedBatters.first?.nextSlot == 1)
        #expect(result.finalState.projectedPitchers.first?.activePitcherIdentity == ReplayTestSupport.pitcherIdentity)
        #expect(result.eventSummaries.allSatisfy { $0.resultingScore.home >= 0 && $0.resultingScore.visiting >= 0 })
    }
}

struct CanonicalGameReplayStageETests {
    @Test func fullReplayEqualsPrefixPlusSuffixWithoutStoredCheckpoints() {
        let events = [
            ReplayTestSupport.event(sequence: 1, raw: "Single", batter: ReplayTestSupport.batter(1)),
            ReplayTestSupport.event(sequence: 2, raw: "Ground Out", batter: ReplayTestSupport.batter(2)),
            ReplayTestSupport.event(sequence: 3, raw: "Single", batter: ReplayTestSupport.batter(3))
        ]
        let full = CanonicalGameReplay.replay(ReplayTestSupport.input(events: events))
        let prefix = CanonicalGameReplay.replay(ReplayTestSupport.input(events: Array(events.prefix(2))))
        let suffixInput = ReplayTestSupport.input(
            initialBattingSide: prefix.finalState.battingSide,
            initialInning: prefix.finalState.inning,
            initialOuts: prefix.finalState.outs,
            initialBaseOccupancy: prefix.finalState.baseOccupancy,
            initialScore: prefix.finalState.score,
            events: Array(events.suffix(1)),
            startPosition: CanonicalReplayStartPosition(nextEventSequence: prefix.finalState.nextEventSequence, appliedEventCount: prefix.appliedEventCount)
        )
        let suffix = CanonicalGameReplay.replay(suffixInput)

        #expect(full.finalState.score == suffix.finalState.score)
        #expect(full.finalState.outs == suffix.finalState.outs)
        #expect(full.finalState.baseOccupancy == suffix.finalState.baseOccupancy)
        #expect(full.finalState.inning == suffix.finalState.inning)
        #expect(suffix.appliedEventCount == full.appliedEventCount)
    }
}

struct CanonicalGameReplayStageFTests {
    @Test func unsupportedEventIsPreservedAndStopsWithoutApplying() {
        let input = ReplayTestSupport.input(events: [ReplayTestSupport.event(sequence: 1, raw: "Moon Shot")])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.disposition == .unsupported)
        #expect(result.appliedEventCount == 0)
        #expect(result.eventSummaries.first?.unsupportedRawClassification.contains("Moon Shot") == true)
    }

    @Test func missingBatterAndInvalidRunnerAreClassified() {
        let missingBatter = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single", batter: nil)
        ]))
        let invalidRunner = CanonicalGameReplay.replay(ReplayTestSupport.input(initialBaseOccupancy: CanonicalBaseOccupancy(runnerStates: [
            .activeOccupant(base: .first, runner: ReplayTestSupport.runner(1))
        ]), events: [
            ReplayTestSupport.event(ordering: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0))], raw: "Home", resultEvidence: ScoringEventResultEvidence.runnerScores(rawValue: "Home"), batter: nil, runnerAdvancement: [.scored(runner: .invalidIdentity(.invalid("bad-runner"), PlayerDisplayEvidence()), sourceBase: .first)])
        ]))

        #expect(missingBatter.disposition == .incomplete)
        #expect(missingBatter.validationFindings.map(\.code).contains("scoringCommand.batterMissing"))
        #expect(invalidRunner.disposition == CanonicalReplayDisposition.rejected)
        #expect(invalidRunner.appliedEventCount == 0)
    }

    @Test func brokenPitcherRelationshipDoesNotStopReplay() {
        let input = ReplayTestSupport.input(initialPitcherResponsibility: CanonicalPitcherResponsibilityEvidence(eventIdentity: .missing, gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .home, responsibility: .missingPitcherRelationship, source: .syntheticVerification), events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single")
        ])
        let result = CanonicalGameReplay.replay(input)

        #expect(result.appliedEventCount == 1)
        #expect(result.disposition == .complete)
    }

    @Test func storedScoreComparisonMatchesAndDiffersWithoutMutation() {
        let match = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [ReplayTestSupport.event(sequence: 1, raw: "Home Run")], storedScore: CanonicalProjectedScore(home: 0, visiting: 1)))
        let mismatch = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [ReplayTestSupport.event(sequence: 1, raw: "Home Run")], storedScore: CanonicalProjectedScore(home: 0, visiting: 2)))

        #expect(match.storedScoreComparison == .matchesStoredScore)
        if case .differsFromStoredScore = mismatch.storedScoreComparison {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func partialReplayIdentifiesFirstProblematicEvent() {
        let badID = ReplayTestSupport.eventID(44)
        let result = CanonicalGameReplay.replay(ReplayTestSupport.input(events: [
            ReplayTestSupport.event(sequence: 1, raw: "Single"),
            ReplayTestSupport.event(sequence: 2, raw: "Moon Shot", eventID: badID),
            ReplayTestSupport.event(sequence: 3, raw: "Single", eventID: ReplayTestSupport.eventID(45), batter: ReplayTestSupport.batter(3))
        ]))

        #expect(result.disposition == .partial)
        #expect(result.firstProblematicEventIdentity == .valid(badID))
        #expect(result.firstProblematicEventIndex == 1)
        #expect(result.appliedEventCount == 1)
    }
}

enum ReplayTestSupport {
    static let homeTeamID = StableIdentityAndOrderingTestSupport.fixedUUID("96000000-0000-0000-0000-000000000001")
    static let visitingTeamID = StableIdentityAndOrderingTestSupport.fixedUUID("96000000-0000-0000-0000-000000000002")
    static let lineupID = StableIdentityAndOrderingTestSupport.fixedUUID("97000000-0000-0000-0000-000000000001")
    static let pitcherIdentity: ImportedIdentifierEvidence = .valid(StableIdentityAndOrderingTestSupport.fixedUUID("98000000-0000-0000-0000-000000000002"))

    static func input(
        initialBattingSide: TeamSideRole = .visiting,
        initialInning: CanonicalHalfInning? = CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
        initialOuts: CanonicalOutsState = CanonicalOutsState(outs: .known(0)),
        initialBaseOccupancy: CanonicalBaseOccupancy = CanonicalBaseOccupancy(),
        initialScore: CanonicalProjectedScore = CanonicalProjectedScore(),
        lineups: [CanonicalReplayLineupInput] = [],
        initialPitcherResponsibility: CanonicalPitcherResponsibilityEvidence? = ScoringCommandTestSupport.pitcherResponsibility(),
        pitchers: [CanonicalReplayPitcherInput] = [],
        events: [CanonicalScoringEventEvidence],
        storedScore: CanonicalProjectedScore? = nil,
        startPosition: CanonicalReplayStartPosition = CanonicalReplayStartPosition()
    ) -> CanonicalReplayInput {
        CanonicalReplayInput(
            game: CanonicalGameStatePrimitivesTestSupport.game(lifecycle: .inProgress),
            homeTeamIdentity: .valid(homeTeamID),
            visitingTeamIdentity: .valid(visitingTeamID),
            initialBattingSide: initialBattingSide,
            initialInning: initialInning,
            initialOuts: initialOuts,
            initialBaseOccupancy: initialBaseOccupancy,
            initialScore: initialScore,
            lineups: lineups,
            initialPitcherResponsibility: initialPitcherResponsibility,
            pitchers: pitchers,
            recordedEvents: events,
            storedScore: storedScore,
            startPosition: startPosition
        )
    }

    static func event(
        sequence: Int?,
        raw: String,
        eventID: UUID = eventID(1),
        batter: LineupParticipantEvidence? = batter(1),
        runnerAdvancement: [RunnerStateEvidence] = []
    ) -> CanonicalScoringEventEvidence {
        let ordering: [ScoringEventOrderingEvidence] = sequence.map { [.knownSequence(OrderEvidence(kind: .eventSequence, value: $0, sourceIndex: $0 - 1))] } ?? []
        return event(ordering: ordering, raw: raw, eventID: eventID, batter: batter, runnerAdvancement: runnerAdvancement)
    }

    static func event(
        sequence: Int,
        raw: String,
        eventID: UUID = eventID(1),
        batter: LineupParticipantEvidence? = batter(1),
        runnerAdvancement: [RunnerStateEvidence] = []
    ) -> CanonicalScoringEventEvidence {
        event(sequence: Optional(sequence), raw: raw, eventID: eventID, batter: batter, runnerAdvancement: runnerAdvancement)
    }

    static func event(
        ordering: [ScoringEventOrderingEvidence],
        raw: String,
        eventID: UUID = eventID(1),
        resultEvidence: ScoringEventResultEvidence? = nil,
        batter: LineupParticipantEvidence? = batter(1),
        runnerAdvancement: [RunnerStateEvidence] = []
    ) -> CanonicalScoringEventEvidence {
        CanonicalScoringEventEvidence(
            eventIdentity: .valid(eventID),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: ordering,
            inningContext: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
            teamSide: .visiting,
            participants: ScoringEventParticipantEvidence(batter: batter),
            resultEvidence: resultEvidence ?? ScoringEventResultEvidence(rawValue: raw),
            runnerAdvancement: runnerAdvancement,
            unsupportedRawLegacyEvidence: ScoringEventResultEvidence(rawValue: raw) == .unsupportedRawResult(raw) ? [raw] : [],
            source: .syntheticVerification
        )
    }

    static func eventID(_ value: Int) -> UUID {
        StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "95000000-0000-0000-0000-%012d", value))
    }

    static func batter(_ value: Int) -> LineupParticipantEvidence {
        ScoringCommandTestSupport.batter(id: StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "99000000-0000-0000-0000-%012d", value)))
    }

    static func runner(_ value: Int) -> RunnerIdentityEvidence {
        .gameParticipant(ScoringCommandTestSupport.participant(id: StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "99000000-0000-0000-0000-%012d", value)), name: "Fixture Batter"))
    }

    static func lineup(side: TeamSideRole, count: Int) -> CanonicalReplayLineupInput {
        let entries = (1...count).map { slot in
            CanonicalBattingOrderEntry(
                gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
                lineupIdentity: .valid(lineupID),
                participant: ScoringCommandTestSupport.batter(side: side, id: StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "99000000-0000-0000-0000-%012d", slot))),
                slotEvidence: .known(slot),
                sourceOrderEvidence: OrderEvidence(kind: .sourceFile, value: slot - 1, sourceIndex: slot - 1),
                source: .syntheticVerification
            )
        }
        return CanonicalReplayLineupInput(side: side, lineup: CanonicalBattingOrderEvidence(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), lineupIdentity: .valid(lineupID), context: .traditional, entries: entries))
    }

    static func pitcherInput(side: TeamSideRole) -> CanonicalReplayPitcherInput {
        let appearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("98000000-0000-0000-0000-000000000001")),
            reusablePitcherIdentity: pitcherIdentity,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: side,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 1),
            roleEvidence: [.startingPitcher, .activePitcher],
            source: .syntheticVerification
        )
        return CanonicalReplayPitcherInput(defensiveSide: side, appearances: [appearance])
    }
}
