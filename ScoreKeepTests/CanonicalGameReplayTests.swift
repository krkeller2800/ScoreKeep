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

struct CanonicalCorrectionPlanningStageATests {
    @Test func uniqueMissingDuplicateWrongGameStaleAndAmbiguousTargetsPlanWithoutMutation() {
        let events = CorrectionTestSupport.events()
        let factSet = CorrectionTestSupport.factSet(events)
        let original = factSet
        let intent = CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Double"))
        let plan = CanonicalCorrectionPlanner.plan(intent, in: factSet)
        let repeated = CanonicalCorrectionPlanner.plan(intent, in: factSet)

        #expect(factSet == original)
        #expect(plan.disposition == .planned)
        #expect(plan.earliestReplayPosition == 0)
        #expect(plan.downstreamEventCount == 2)
        #expect(plan.recalculatesScoreProjection)
        #expect(plan == repeated)

        let missing = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: .valid(ReplayTestSupport.eventID(99)), operation: .removeEvent), in: factSet)
        let duplicate = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: events[0].eventIdentity, operation: .removeEvent), in: CorrectionTestSupport.factSet([events[0], events[0]]))
        let wrongGame = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("94000000-0000-0000-0000-000000000001")), targetEventIdentity: events[0].eventIdentity, operation: .removeEvent), in: factSet)
        let stale = CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Double"), expectedOriginal: events[1]), in: factSet)
        let ambiguousEvent = ReplayTestSupport.event(sequence: nil, raw: "Single", eventID: ReplayTestSupport.eventID(10))
        let ambiguous = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: ambiguousEvent.eventIdentity, operation: .removeEvent), in: CorrectionTestSupport.factSet([ambiguousEvent]))
        let unsupported = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: events[0].eventIdentity, operation: .unsupported("insert missing event")), in: factSet)

        #expect(missing.resolution == .missingTarget)
        #expect(duplicate.resolution == .duplicateTargetIdentity)
        #expect(wrongGame.resolution == .wrongGameTarget)
        #expect(stale.resolution == .staleExpectedOriginal)
        #expect(ambiguous.resolution == .ambiguousOrdering)
        #expect(unsupported.disposition == .unsupported)
    }
}

struct CanonicalCorrectionApplicationStageBTests {
    @Test func replaceAndRemoveAreAtomicAndDeterministic() {
        let events = CorrectionTestSupport.events()
        let factSet = CorrectionTestSupport.factSet(events)
        let replacement = CorrectionTestSupport.replacement(for: events[0], raw: "Double")
        let replacePlan = CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: events[0], replacement: replacement), in: factSet)
        let first = CanonicalCorrectionApplicator.apply(replacePlan, to: factSet)
        let second = CanonicalCorrectionApplicator.apply(replacePlan, to: factSet)

        #expect(first.applied)
        #expect(first == second)
        #expect(first.originalFactSet == factSet)
        #expect(first.updatedFactSet.activeEvents[0] == replacement)
        #expect(first.updatedFactSet.activeEvents[1] == events[1])
        #expect(first.updatedFactSet.supersededEvents == [events[0]])

        let removePlan = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: events[1].eventIdentity, operation: .removeEvent, expectedOriginalEvent: events[1]), in: factSet)
        let removal = CanonicalCorrectionApplicator.apply(removePlan, to: factSet)
        #expect(removal.applied)
        #expect(removal.updatedFactSet.activeEvents == [events[0], events[2]])
        #expect(removal.updatedFactSet.supersededEvents == [events[1]])
        #expect(factSet.activeEvents == events)
    }

    @Test func rejectedCorrectionReturnsOriginalFacts() {
        let events = CorrectionTestSupport.events()
        let factSet = CorrectionTestSupport.factSet(events)
        let plan = CanonicalCorrectionPlanner.plan(CanonicalCorrectionIntent(targetGameIdentity: factSet.gameIdentity, targetEventIdentity: .valid(ReplayTestSupport.eventID(88)), operation: .removeEvent), in: factSet)
        let application = CanonicalCorrectionApplicator.apply(plan, to: factSet)

        #expect(application.applied == false)
        #expect(application.updatedFactSet == factSet)
        #expect(application.acceptedCorrectedEvent == nil)
        #expect(application.changedFacts.isEmpty)
    }
}

struct CanonicalCorrectionRecalculationStageCTests {
    @Test func replayRecalculationChangesStateAndStopsUnsafeDownstream() {
        let first = ReplayTestSupport.event(sequence: 1, raw: "Home Run", eventID: ReplayTestSupport.eventID(1), batter: ReplayTestSupport.batter(1))
        let second = ReplayTestSupport.event(sequence: 2, raw: "Ground Out", eventID: ReplayTestSupport.eventID(2), batter: ReplayTestSupport.batter(2))
        let third = ReplayTestSupport.event(sequence: 3, raw: "Ground Out", eventID: ReplayTestSupport.eventID(3), batter: ReplayTestSupport.batter(3))
        let events = [first, second, third]
        let factSet = CorrectionTestSupport.factSet(events)
        let replacement = CorrectionTestSupport.replacement(for: first, raw: "Ground Out")
        let application = CanonicalCorrectionApplicator.apply(CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: first, replacement: replacement), in: factSet), to: factSet)
        let input = ReplayTestSupport.input(lineups: [ReplayTestSupport.lineup(side: .visiting, count: 3)], pitchers: [ReplayTestSupport.pitcherInput(side: .home)], events: events, storedScore: CanonicalProjectedScore(home: 0, visiting: 1))
        let recalculation = CanonicalCorrectionRecalculator.recalculate(replayInput: input, application: application)

        #expect(recalculation.originalFinalState.score.visiting == 1)
        #expect(recalculation.correctedFinalState.score.visiting == 0)
        #expect(recalculation.changedProjections.contains(.eventResult))
        #expect(recalculation.changedProjections.contains(.outs))
        #expect(recalculation.changedProjections.contains(.inning))
        if case .differsFromStoredScore = recalculation.correctedFinalState.storedScoreComparison { #expect(true) } else { #expect(Bool(false)) }

        let bad = ReplayTestSupport.event(sequence: 2, raw: "Moon Shot", eventID: ReplayTestSupport.eventID(44))
        let unsafeFactSet = CorrectionTestSupport.factSet([first, bad])
        let unsafeApplication = CanonicalCorrectionApplicator.apply(CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: first, replacement: replacement), in: unsafeFactSet), to: unsafeFactSet)
        let unsafe = CanonicalCorrectionRecalculator.recalculate(replayInput: ReplayTestSupport.input(events: [first, bad]), application: unsafeApplication)
        #expect(unsafe.disposition == .unsafeDownstream)
        #expect(unsafe.firstDownstreamFailure == bad.eventIdentity)
        #expect(unsafeApplication.originalFactSet.activeEvents == [first, bad])
    }
}

struct CanonicalCorrectionRejectionStageDTests {
    @Test func invalidReplacementCasesProduceNoPartialMutation() {
        let events = CorrectionTestSupport.events()
        let factSet = CorrectionTestSupport.factSet(events)
        let unsupported = CorrectionTestSupport.replacement(for: events[0], raw: "Moon Shot")
        let missingBatter = CorrectionTestSupport.replacement(for: events[0], raw: "Single", batter: nil)
        let fabricatedIdentity = CanonicalScoringEventEvidence(eventIdentity: .valid(ReplayTestSupport.eventID(77)), gameIdentity: events[0].gameIdentity, orderingEvidence: events[0].orderingEvidence, inningContext: events[0].inningContext, teamSide: events[0].teamSide, participants: events[0].participants, resultEvidence: .batterReachesBase(rawValue: "Single"), source: .syntheticVerification)
        let unsafeOrder = CanonicalScoringEventEvidence(eventIdentity: events[0].eventIdentity, gameIdentity: events[0].gameIdentity, orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 4, sourceIndex: 3))], inningContext: events[0].inningContext, teamSide: events[0].teamSide, participants: events[0].participants, resultEvidence: .batterReachesBase(rawValue: "Single"), source: .syntheticVerification)
        let wrongSide = CorrectionTestSupport.replacement(for: events[0], raw: "Single", side: .home)
        let impossibleOuts = CanonicalScoringEventEvidence(eventIdentity: events[0].eventIdentity, gameIdentity: events[0].gameIdentity, orderingEvidence: events[0].orderingEvidence, inningContext: events[0].inningContext, teamSide: events[0].teamSide, participants: events[0].participants, resultEvidence: .batterOut(rawValue: "Ground Out"), outsEvidence: CanonicalOutsState(outs: .known(4), outsRecordedByEvent: 4), source: .syntheticVerification)
        let contradictoryOccupancy = CanonicalScoringEventEvidence(eventIdentity: events[0].eventIdentity, gameIdentity: events[0].gameIdentity, orderingEvidence: events[0].orderingEvidence, inningContext: events[0].inningContext, teamSide: events[0].teamSide, participants: events[0].participants, resultEvidence: .runnerAdvances(rawValue: "Safe"), runnerAdvancement: [.activeOccupant(base: .second, runner: ReplayTestSupport.runner(1)), .activeOccupant(base: .second, runner: ReplayTestSupport.runner(2))], source: .syntheticVerification)

        for replacement in [unsupported, missingBatter, fabricatedIdentity, unsafeOrder, wrongSide, impossibleOuts, contradictoryOccupancy] {
            let application = CanonicalCorrectionApplicator.apply(CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: events[0], replacement: replacement), in: factSet), to: factSet)
            #expect(application.applied == false)
            #expect(application.updatedFactSet == factSet)
        }

        let superseded = CanonicalCorrectionFactSet(gameIdentity: factSet.gameIdentity, activeEvents: Array(events.dropFirst()), supersededEvents: [events[0]])
        let alreadySuperseded = CanonicalCorrectionApplicator.apply(CanonicalCorrectionPlanner.plan(CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Double")), in: superseded), to: superseded)
        #expect(alreadySuperseded.applied == false)
        #expect(alreadySuperseded.updatedFactSet == superseded)
    }
}

struct CanonicalCorrectionIdempotencyStageETests {
    @Test func scoringAndCorrectionIdempotencyClassifyDuplicatesConflictsAndMissingIdentity() {
        let command = CorrectionTestSupport.command(raw: "Single", invocationEventID: ReplayTestSupport.eventID(1))
        let changedCommand = CorrectionTestSupport.command(raw: "Double", invocationEventID: ReplayTestSupport.eventID(2))
        let scoringRecord = CanonicalIdempotencyRecord(invocationIdentity: "score-1", intent: .scoring(command), existingFactIdentity: .valid(ReplayTestSupport.eventID(1)), wasAccepted: true)

        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "score-2", intent: .scoring(changedCommand), priorRecords: [scoringRecord]).disposition == .newInvocation)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "score-1", intent: .scoring(command), priorRecords: [scoringRecord]).mustNotCreateNewFact)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "score-1", intent: .scoring(changedCommand), priorRecords: [scoringRecord]).disposition == .conflictingDuplicateInvocation)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: nil, intent: .scoring(command), priorRecords: [scoringRecord]).disposition == .missingInvocationIdentity)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "score-3", intent: .scoring(command), priorRecords: [scoringRecord]).disposition == .semanticRepeatDifferentInvocation)

        let events = CorrectionTestSupport.events()
        let correction = CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Double"), invocation: "corr-1")
        let conflictCorrection = CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Triple"), invocation: "corr-1")
        let accepted = CanonicalIdempotencyRecord(invocationIdentity: "corr-1", intent: .correction(correction), existingFactIdentity: events[0].eventIdentity, wasAccepted: true)
        let rejected = CanonicalIdempotencyRecord(invocationIdentity: "corr-2", intent: .correction(correction), existingFactIdentity: nil, wasAccepted: false)

        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "corr-1", intent: .correction(correction), priorRecords: [accepted]).disposition == .repeatedAcceptedCorrection)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "corr-2", intent: .correction(correction), priorRecords: [rejected]).disposition == .repeatedRejectedCorrection)
        #expect(CanonicalIdempotencyAuthority.classify(invocationIdentity: "corr-1", intent: .correction(conflictCorrection), priorRecords: [accepted]).mustNotCreateNewFact)
    }
}

struct CanonicalCorrectionCombinedStageFTests {
    @Test func completeInMemoryFlowRepeatsInvocationWithoutDuplicateCorrectionOrEvent() {
        let events = CorrectionTestSupport.events()
        let factSet = CorrectionTestSupport.factSet(events)
        let intent = CorrectionTestSupport.replaceIntent(target: events[0], replacement: CorrectionTestSupport.replacement(for: events[0], raw: "Double"), invocation: "corr-flow-1")
        let idempotency = CanonicalIdempotencyAuthority.classify(invocationIdentity: intent.invocationIdentity, intent: .correction(intent), priorRecords: [])
        let plan = CanonicalCorrectionPlanner.plan(intent, in: factSet)
        let application = CanonicalCorrectionApplicator.apply(plan, to: factSet, idempotencyResult: idempotency)
        let recalculation = CanonicalCorrectionRecalculator.recalculate(replayInput: ReplayTestSupport.input(events: events), application: application)
        let record = CanonicalIdempotencyRecord(invocationIdentity: "corr-flow-1", intent: .correction(intent), existingFactIdentity: events[0].eventIdentity, wasAccepted: application.applied)
        let repeatIdempotency = CanonicalIdempotencyAuthority.classify(invocationIdentity: intent.invocationIdentity, intent: .correction(intent), priorRecords: [record])
        let repeatApplication = CanonicalCorrectionApplicator.apply(plan, to: application.updatedFactSet, idempotencyResult: repeatIdempotency)

        #expect(plan.disposition == .planned)
        #expect(application.applied)
        #expect(recalculation.disposition == .recalculatedWithWarnings || recalculation.disposition == .recalculated)
        #expect(repeatIdempotency.mustNotCreateNewFact)
        #expect(repeatApplication.applied == false)
        #expect(application.updatedFactSet.activeEvents.count == events.count)
        #expect(application.updatedFactSet.supersededEvents.count == 1)
    }
}

enum CorrectionTestSupport {
    static func events() -> [CanonicalScoringEventEvidence] {
        [
            ReplayTestSupport.event(sequence: 1, raw: "Single", eventID: ReplayTestSupport.eventID(1), batter: ReplayTestSupport.batter(1)),
            ReplayTestSupport.event(sequence: 2, raw: "Ground Out", eventID: ReplayTestSupport.eventID(2), batter: ReplayTestSupport.batter(2)),
            ReplayTestSupport.event(sequence: 3, raw: "Home Run", eventID: ReplayTestSupport.eventID(3), batter: ReplayTestSupport.batter(3))
        ]
    }

    static func factSet(_ events: [CanonicalScoringEventEvidence]) -> CanonicalCorrectionFactSet {
        CanonicalCorrectionFactSet(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), activeEvents: events)
    }

    static func replaceIntent(target: CanonicalScoringEventEvidence, replacement: CanonicalScoringEventEvidence, expectedOriginal: CanonicalScoringEventEvidence? = nil, invocation: String? = nil) -> CanonicalCorrectionIntent {
        CanonicalCorrectionIntent(invocationIdentity: invocation, targetGameIdentity: target.gameIdentity, targetEventIdentity: target.eventIdentity, operation: .replaceEvent(replacement), expectedOriginalEvent: expectedOriginal ?? target, source: .syntheticVerification)
    }

    static func replacement(for event: CanonicalScoringEventEvidence, raw: String, batter: LineupParticipantEvidence? = ReplayTestSupport.batter(1), side: TeamSideRole? = .visiting) -> CanonicalScoringEventEvidence {
        CanonicalScoringEventEvidence(eventIdentity: event.eventIdentity, gameIdentity: event.gameIdentity, orderingEvidence: event.orderingEvidence, inningContext: event.inningContext, teamSide: side, participants: ScoringEventParticipantEvidence(batter: batter), resultEvidence: ScoringEventResultEvidence(rawValue: raw), unsupportedRawLegacyEvidence: ScoringEventResultEvidence(rawValue: raw) == .unsupportedRawResult(raw) ? [raw] : [], source: .syntheticVerification)
    }

    static func command(raw: String, invocationEventID: UUID) -> CanonicalScoringCommand {
        CanonicalScoringCommandVocabulary.command(rawResult: raw, gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ReplayTestSupport.batter(1), proposedEventIdentity: .valid(invocationEventID), source: .syntheticVerification)
    }
}
