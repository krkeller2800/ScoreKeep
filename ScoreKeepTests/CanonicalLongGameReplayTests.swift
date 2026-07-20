import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalLongGameReplayStageATests {
    @Test func ordinaryMultiInningReplayProducesCoherentShallowState() {
        let scenario = LongGameReplayTestSupport.multiInningScenario()
        let original = scenario.input
        let result = CanonicalGameReplay.replay(scenario.input)
        let repeated = CanonicalGameReplay.replay(scenario.input)

        #expect(scenario.input == original)
        #expect(result.disposition == .complete || result.disposition == .completeWithWarnings)
        #expect(result.appliedEventCount == scenario.input.recordedEvents.count)
        #expect(result.unappliedEventCount == 0)
        #expect(result.eventSummaries.count == scenario.input.recordedEvents.count)
        #expect(result.finalState.inning?.number == .known(3))
        #expect(result.finalState.inning?.half == .known(.top))
        #expect(result.finalState.battingSide == .visiting)
        #expect(result.finalState.outs.outs == .known(0))
        #expect(result.finalState.baseOccupancy.runnerStates.isEmpty)
        #expect(result.finalState.score == CanonicalProjectedScore(home: 1, visiting: 2))
        #expect(result.storedScoreComparison == .matchesStoredScore)
        #expect(result.finalState == repeated.finalState)
        #expect(result.eventSummaries == repeated.eventSummaries)
    }
}

struct CanonicalLongGameReplayStageBTests {
    @Test func extraInningWraparoundAndPitcherChangeRemainDeterministic() {
        let scenario = LongGameReplayTestSupport.extraInningScenario()
        let first = CanonicalGameReplay.replay(scenario.input)
        let second = CanonicalGameReplay.replay(scenario.input)

        #expect(first.disposition == .complete || first.disposition == .completeWithWarnings)
        #expect(first.finalState.inning?.number == .known(3))
        #expect(first.finalState.inning?.half == .known(.bottom))
        #expect(first.finalState.score == CanonicalProjectedScore(home: 0, visiting: 1))
        let visitingProjection = CanonicalBatterProjector.project(CanonicalBatterProjectionInput(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), battingSide: .visiting, lineup: LongGameReplayTestSupport.lineup(side: .visiting, count: 3).lineup, recordedEvents: scenario.events))
        let homeProjection = CanonicalBatterProjector.project(CanonicalBatterProjectionInput(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), battingSide: .home, lineup: LongGameReplayTestSupport.lineup(side: .home, count: 3).lineup, recordedEvents: scenario.events))

        #expect(visitingProjection.currentSlot == 2)
        #expect(homeProjection.currentSlot == 1)
        #expect(first.finalState.projectedPitchers.first { $0.defensiveSide == .home }?.activeAppearanceOrder == 13)
        #expect(first.finalState == second.finalState)
        #expect(first.eventSummaries == second.eventSummaries)
    }

    @Test func checkpointIndependenceHoldsAtSeveralLongReplayPositions() {
        let scenario = LongGameReplayTestSupport.longStressScenario(repetitions: 5)
        let full = CanonicalGameReplay.replay(scenario.input)

        for checkpoint in [4, 18, 36, scenario.input.recordedEvents.count - 3] {
            let prefixEvents = Array(scenario.input.recordedEvents.prefix(checkpoint))
            let suffixEvents = Array(scenario.input.recordedEvents.dropFirst(checkpoint))
            let prefix = CanonicalGameReplay.replay(scenario.input(replacingEvents: prefixEvents, storedScore: nil))
            let suffixInput = scenario.input(
                initialBattingSide: prefix.finalState.battingSide,
                initialInning: prefix.finalState.inning,
                initialOuts: prefix.finalState.outs,
                initialBaseOccupancy: prefix.finalState.baseOccupancy,
                initialScore: prefix.finalState.score,
                events: suffixEvents,
                storedScore: scenario.input.storedScore,
                startPosition: CanonicalReplayStartPosition(
                    nextEventSequence: prefix.finalState.nextEventSequence,
                    appliedEventCount: prefix.appliedEventCount
                )
            )
            let suffix = CanonicalGameReplay.replay(suffixInput)

            #expect(prefix.disposition == .complete || prefix.disposition == .completeWithWarnings)
            #expect(suffix.disposition == .complete || suffix.disposition == .completeWithWarnings)
            #expect(suffix.finalState.score == full.finalState.score)
            #expect(suffix.finalState.outs == full.finalState.outs)
            #expect(suffix.finalState.inning == full.finalState.inning)
            #expect(suffix.finalState.baseOccupancy == full.finalState.baseOccupancy)
            #expect(suffix.finalState.battingSide == full.finalState.battingSide)
            #expect(suffix.appliedEventCount == full.appliedEventCount)
        }
    }
}

struct CanonicalLongGameReplayStageCTests {
    @Test func substitutionAndCorrectionRemainStableWithoutDuplicateCorrectedFacts() {
        let scenario = LongGameReplayTestSupport.substitutionScenario()
        let original = CanonicalGameReplay.replay(scenario.input)
        let replacement = LongGameReplayTestSupport.event(sequence: 2, side: .visiting, raw: "Ground Out", eventID: scenario.events[1].eventIdentity.validIdentifier ?? LongGameReplayTestSupport.eventID(2), batterSlot: 7)
        let factSet = CanonicalCorrectionFactSet(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), activeEvents: scenario.events)
        let intent = CanonicalCorrectionIntent(
            invocationIdentity: "long-correction-1",
            targetGameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            targetEventIdentity: scenario.events[1].eventIdentity,
            operation: .replaceEvent(replacement),
            expectedOriginalEvent: scenario.events[1],
            source: .syntheticVerification
        )
        let idempotency = CanonicalIdempotencyAuthority.classify(invocationIdentity: intent.invocationIdentity, intent: .correction(intent), priorRecords: [])
        let plan = CanonicalCorrectionPlanner.plan(intent, in: factSet)
        let application = CanonicalCorrectionApplicator.apply(plan, to: factSet, idempotencyResult: idempotency)
        let recalculation = CanonicalCorrectionRecalculator.recalculate(replayInput: scenario.input, application: application)
        let record = CanonicalIdempotencyRecord(invocationIdentity: "long-correction-1", intent: .correction(intent), existingFactIdentity: scenario.events[1].eventIdentity, wasAccepted: application.applied)
        let repeatedIdempotency = CanonicalIdempotencyAuthority.classify(invocationIdentity: intent.invocationIdentity, intent: .correction(intent), priorRecords: [record])
        let repeatedApplication = CanonicalCorrectionApplicator.apply(plan, to: application.updatedFactSet, idempotencyResult: repeatedIdempotency)

        let substitutionProjection = CanonicalBatterProjector.project(CanonicalBatterProjectionInput(
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            battingSide: .visiting,
            lineup: LongGameReplayTestSupport.lineup(side: .visiting, count: 6, substitutions: [LongGameReplayTestSupport.supportedSubstitution(side: .visiting, outgoingSlot: 2, incomingSlot: 7, effectiveOrder: 2)]).lineup,
            recordedEvents: scenario.events,
            substitutions: [LongGameReplayTestSupport.supportedSubstitution(side: .visiting, outgoingSlot: 2, incomingSlot: 7, effectiveOrder: 2)]
        ))

        let substitutionClassifications = CanonicalSubstitutionMeaningClassifier.classify(LongGameReplayTestSupport.supportedSubstitution(side: .visiting, outgoingSlot: 2, incomingSlot: 7, effectiveOrder: 2))

        #expect(original.finalState.score.visiting == 1)
        #expect(substitutionClassifications.contains(.incomingParticipantKnown))
        #expect(substitutionClassifications.contains(.outgoingParticipantKnown))
        #expect(substitutionClassifications.contains(.effectiveOrderKnown))
        #expect(substitutionProjection.currentSlot == 4)
        #expect(plan.disposition == .planned)
        #expect(application.applied)
        #expect(recalculation.correctedFinalState.score.visiting == 0)
        #expect(recalculation.changedProjections.contains(.eventResult))
        #expect(repeatedIdempotency.mustNotCreateNewFact)
        #expect(repeatedApplication.applied == false)
        #expect(application.updatedFactSet.activeEvents.count == scenario.events.count)
        #expect(application.updatedFactSet.supersededEvents.count == 1)
    }
}

struct CanonicalLongGameReplayStageDTests {
    @Test func longStressReplayRemainsPracticalDeterministicAndShallow() {
        let scenario = LongGameReplayTestSupport.longStressScenario(repetitions: 8)
        let result = CanonicalGameReplay.replay(scenario.input)
        let repeated = CanonicalGameReplay.replay(scenario.input)

        #expect(result.disposition == .complete || result.disposition == .completeWithWarnings)
        #expect(result.appliedEventCount == scenario.input.recordedEvents.count)
        #expect(result.eventSummaries.count == scenario.input.recordedEvents.count)
        #expect(result.eventSummaries.count < scenario.input.recordedEvents.count * 2)
        #expect(result.finalState.projectedBatters.isEmpty)
        #expect(result.finalState.projectedPitchers.count == 2)
        #expect(result.finalState == repeated.finalState)
        #expect(result.eventSummaries == repeated.eventSummaries)
    }

    @Test func longReplayFailureCasesStopWithoutPartialMutation() {
        let base = LongGameReplayTestSupport.multiInningScenario()
        let duplicateSequence = CanonicalGameReplay.replay(base.input(replacingEvents: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Single", eventID: LongGameReplayTestSupport.eventID(201), batterSlot: 1),
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Ground Out", eventID: LongGameReplayTestSupport.eventID(202), batterSlot: 2)
        ], storedScore: nil))
        let missingBatter = CanonicalGameReplay.replay(base.input(replacingEvents: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Single", eventID: LongGameReplayTestSupport.eventID(203), batterSlot: nil)
        ], storedScore: nil))
        let invalidRunner = CanonicalGameReplay.replay(base.input(replacingEvents: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Home", eventID: LongGameReplayTestSupport.eventID(204), resultEvidence: .runnerScores(rawValue: "Home"), batterSlot: nil, runnerAdvancement: [.scored(runner: .invalidIdentity(.invalid("bad-runner"), PlayerDisplayEvidence()), sourceBase: .first)])
        ], storedScore: nil))
        let impossibleOuts = CanonicalGameReplay.replay(base.input(initialOuts: CanonicalOutsState(outs: .known(4)), events: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Ground Out", eventID: LongGameReplayTestSupport.eventID(205), batterSlot: 1)
        ], storedScore: nil))
        let contradictoryOccupancy = CanonicalGameReplay.replay(base.input(initialBaseOccupancy: CanonicalBaseOccupancy(runnerStates: [
            .activeOccupant(base: .first, runner: LongGameReplayTestSupport.runner(side: .visiting, slot: 1)),
            .activeOccupant(base: .first, runner: LongGameReplayTestSupport.runner(side: .visiting, slot: 2))
        ]), events: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Single", eventID: LongGameReplayTestSupport.eventID(206), batterSlot: 3)
        ], storedScore: nil))
        let unsupported = CanonicalGameReplay.replay(base.input(replacingEvents: [
            LongGameReplayTestSupport.event(sequence: 1, side: .visiting, raw: "Moon Shot", eventID: LongGameReplayTestSupport.eventID(207), batterSlot: 1)
        ], storedScore: nil))
        let ambiguousSubstitution = CanonicalSubstitutionMeaningClassifier.classify(LongGameReplayTestSupport.ambiguousSubstitution())

        #expect(duplicateSequence.disposition == .contradictory)
        #expect(duplicateSequence.appliedEventCount == 0)
        #expect(missingBatter.disposition == .incomplete)
        #expect(missingBatter.appliedEventCount == 0)
        #expect(invalidRunner.disposition == .rejected)
        #expect(invalidRunner.appliedEventCount == 0)
        #expect(impossibleOuts.disposition == .rejected)
        #expect(impossibleOuts.appliedEventCount == 0)
        #expect(contradictoryOccupancy.disposition == .contradictory)
        #expect(contradictoryOccupancy.appliedEventCount == 0)
        #expect(unsupported.disposition == .unsupported)
        #expect(unsupported.eventSummaries.first?.unsupportedRawClassification.contains("Moon Shot") == true)
        #expect(ambiguousSubstitution.contains(.missingOutgoingParticipant))
        #expect(ambiguousSubstitution.contains(.ambiguousSubstitutionPairing))
    }
}

struct CanonicalLongGameReplayStageETests {
    @Test func seededLegacyFixtureContradictionVerification() throws {
        let url = try StableIdentityAndOrderingTestSupport.repositoryURL("ScoreKeep/Seed/seededGame.ScoreKeep_Games")
        let data = try Data(contentsOf: url)
        let game = try JSONDecoder().decode(ShareGame.self, from: data)
        let result = LegacyCanonicalScoringComparisonSupport.compare(game: game, scenarioIdentity: "seededGame")
        let repeated = LegacyCanonicalScoringComparisonSupport.compare(game: game, scenarioIdentity: "seededGame")

        #expect(result.overallOutcome == .contradictoryComparison || result.overallOutcome == .requiresReview || result.overallOutcome == .unsafeComparison)

        let duplicateSequenceDifference = result.differences.first { $0.code == "comparison.duplicateSequence" }
        #expect(duplicateSequenceDifference != nil)

        let mapping = LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: "seededGame")
        let events = game.atbats.enumerated().map { index, atbat in
            let snapshot = LegacyAtbatEvidenceSnapshot(atbat: atbat, fallbackGameIdentity: .valid(game.id), sourceIndex: index, sourceLocation: "seededGame.atbat")
            let mapped = LegacyCanonicalVerificationMapper.mapScoringEvent(snapshot, source: .compatibilityTransport)
            let base = mapped.canonicalValue
            return CanonicalScoringEventEvidence(
                eventIdentity: base?.eventIdentity ?? .valid(atbat.id),
                gameIdentity: .valid(game.id),
                orderingEvidence: base?.orderingEvidence ?? [.knownSequence(OrderEvidence(kind: .eventSequence, value: atbat.seq, sourceIndex: index))],
                inningContext: base?.inningContext,
                teamSide: atbat.team.id == game.vteam.id ? .visiting : .home,
                participants: base?.participants ?? ScoringEventParticipantEvidence(batter: nil, unresolvedRelationships: ["batter"]),
                resultEvidence: base?.resultEvidence ?? ScoringEventResultEvidence(rawValue: atbat.result),
                outsEvidence: base?.outsEvidence,
                batterAdvancement: base?.batterAdvancement,
                runnerAdvancement: base?.runnerAdvancement ?? [],
                rbiEvidence: base?.rbiEvidence ?? .count(atbat.rbis),
                earnedRunEvidence: base?.earnedRunEvidence ?? .flag(atbat.earnedRun),
                sacrificeEvidence: base?.sacrificeEvidence ?? .count(atbat.sacFly + atbat.sacBunt),
                stolenBaseEvidence: base?.stolenBaseEvidence ?? .count(atbat.stolenBases),
                endOfHalfEvidence: base?.endOfHalfEvidence ?? atbat.endOfInning,
                historicalDisplayEvidence: base?.historicalDisplayEvidence ?? [atbat.result],
                unsupportedRawLegacyEvidence: mapped.unsupportedRawEvidence,
                source: .compatibilityTransport
            )
        }

        let replayInput = CanonicalReplayInput(
            game: mapping.game.canonicalValue ?? CanonicalGameStatePrimitivesTestSupport.importedGame(game),
            homeTeamIdentity: .valid(game.hteam.id),
            visitingTeamIdentity: .valid(game.vteam.id),
            initialBattingSide: .visiting,
            initialInning: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(game.numInnings)),
            initialOuts: CanonicalOutsState(outs: .known(0)),
            pitchers: [],
            recordedEvents: events,
            validationFindings: mapping.validation.findings.filter { $0.futureWriteMustStop == false },
            storedScore: CanonicalProjectedScore(home: game.hscore, visiting: game.vscore)
        )

        let replay = CanonicalGameReplay.replay(replayInput)
        let repeatedReplay = CanonicalGameReplay.replay(replayInput)

        let sequenceCounts = Dictionary(grouping: events.compactMap { ev -> Int? in
            if case let .knownSequence(order) = ev.orderingEvidence.first { return order.value }
            return nil
        }, by: { $0 }).mapValues { $0.count }

        #expect(sequenceCounts.values.contains { $0 > 1 })
        #expect(replay.disposition == .contradictory)
        #expect(replay.finalState.score.home != 4 || replay.finalState.score.visiting != 3 || replay.disposition != .complete)
        #expect(replay.disposition == repeatedReplay.disposition)
        #expect(replay.finalState == repeatedReplay.finalState)
        #expect(result == repeated)
    }
}

struct LongGameReplayScenario: Hashable, Sendable {
    let input: CanonicalReplayInput
    let events: [CanonicalScoringEventEvidence]

    func input(
        initialBattingSide: TeamSideRole? = nil,
        initialInning: CanonicalHalfInning? = nil,
        initialOuts: CanonicalOutsState? = nil,
        initialBaseOccupancy: CanonicalBaseOccupancy? = nil,
        initialScore: CanonicalProjectedScore? = nil,
        events replacementEvents: [CanonicalScoringEventEvidence],
        storedScore: CanonicalProjectedScore?,
        startPosition: CanonicalReplayStartPosition = CanonicalReplayStartPosition()
    ) -> CanonicalReplayInput {
        CanonicalReplayInput(
            game: input.game,
            homeTeamIdentity: input.homeTeamIdentity,
            visitingTeamIdentity: input.visitingTeamIdentity,
            initialBattingSide: initialBattingSide ?? input.initialBattingSide,
            initialInning: initialInning ?? input.initialInning,
            initialOuts: initialOuts ?? input.initialOuts,
            initialBaseOccupancy: initialBaseOccupancy ?? input.initialBaseOccupancy,
            initialScore: initialScore ?? input.initialScore,
            lineups: input.lineups,
            initialPitcherResponsibility: input.initialPitcherResponsibility,
            pitchers: input.pitchers,
            recordedEvents: replacementEvents,
            validationFindings: input.validationFindings,
            storedScore: storedScore,
            startPosition: startPosition
        )
    }

    func input(replacingEvents replacementEvents: [CanonicalScoringEventEvidence], storedScore: CanonicalProjectedScore?) -> CanonicalReplayInput {
        input(events: replacementEvents, storedScore: storedScore)
    }
}

enum LongGameReplayTestSupport {
    static func multiInningScenario() -> LongGameReplayScenario {
        let events = [
            event(sequence: 1, side: .visiting, raw: "Single", eventID: eventID(1), batterSlot: 1),
            event(sequence: 2, side: .visiting, raw: "Home Run", eventID: eventID(2), batterSlot: 2, runnerAdvancement: [.scored(runner: runner(side: .visiting, slot: 1), sourceBase: .first)]),
            event(sequence: 3, side: .visiting, raw: "Ground Out", eventID: eventID(3), batterSlot: 3),
            event(sequence: 4, side: .visiting, raw: "Fly Out", eventID: eventID(4), batterSlot: 4),
            event(sequence: 5, side: .visiting, raw: "Strikeout", eventID: eventID(5), batterSlot: 5),
            event(sequence: 6, side: .home, raw: "Double", eventID: eventID(6), batterSlot: 1),
            event(sequence: 7, side: .home, raw: "Home", eventID: eventID(7), resultEvidence: .runnerScores(rawValue: "Home"), batterSlot: nil, runnerAdvancement: [.scored(runner: runner(side: .home, slot: 1), sourceBase: .second)]),
            event(sequence: 8, side: .home, raw: "Ground Out", eventID: eventID(8), batterSlot: 2),
            event(sequence: 9, side: .home, raw: "Fly Out", eventID: eventID(9), batterSlot: 3),
            event(sequence: 10, side: .home, raw: "Strikeout", eventID: eventID(10), batterSlot: 4),
            event(sequence: 11, side: .visiting, raw: "Ground Out", eventID: eventID(11), batterSlot: 6),
            event(sequence: 12, side: .visiting, raw: "Fly Out", eventID: eventID(12), batterSlot: 7),
            event(sequence: 13, side: .visiting, raw: "Strikeout", eventID: eventID(13), batterSlot: 8),
            event(sequence: 14, side: .home, raw: "Single", eventID: eventID(14), batterSlot: 5),
            event(sequence: 15, side: .home, raw: "Out", eventID: eventID(15), resultEvidence: .runnerOut(rawValue: "Out"), batterSlot: nil, runnerAdvancement: [.out(runner: runner(side: .home, slot: 5), sourceBase: .first)]),
            event(sequence: 16, side: .home, raw: "Ground Out", eventID: eventID(16), batterSlot: 6),
            event(sequence: 17, side: .home, raw: "Strikeout", eventID: eventID(17), batterSlot: 7)
        ]
        return scenario(events: events, storedScore: CanonicalProjectedScore(home: 1, visiting: 2))
    }

    static func extraInningScenario() -> LongGameReplayScenario {
        var events: [CanonicalScoringEventEvidence] = []
        var sequence = 1
        for half in 0..<4 {
            let side: TeamSideRole = half.isMultiple(of: 2) ? .visiting : .home
            for outNumber in 0..<3 {
                events.append(event(sequence: sequence, side: side, raw: outNumber == 2 ? "Strikeout" : "Ground Out", eventID: eventID(sequence), batterSlot: ((half / 2) * 3 + outNumber) % 3 + 1))
                sequence += 1
            }
        }
        events.append(event(sequence: sequence, side: .visiting, raw: "Home Run", eventID: eventID(sequence), batterSlot: 1))
        sequence += 1
        events.append(event(sequence: sequence, side: .visiting, raw: "Ground Out", eventID: eventID(sequence), batterSlot: 2))
        sequence += 1
        events.append(event(sequence: sequence, side: .visiting, raw: "Fly Out", eventID: eventID(sequence), batterSlot: 3))
        sequence += 1
        events.append(event(sequence: sequence, side: .visiting, raw: "Strikeout", eventID: eventID(sequence), batterSlot: 1))

        return scenario(
            events: events,
            lineups: [],
            pitchers: [pitcherInput(side: .home, includeRelief: true), pitcherInput(side: .visiting, includeRelief: false)],
            storedScore: CanonicalProjectedScore(home: 0, visiting: 1),
            expectedInnings: 2
        )
    }

    static func substitutionScenario() -> LongGameReplayScenario {
        let substitution = supportedSubstitution(side: .visiting, outgoingSlot: 2, incomingSlot: 7, effectiveOrder: 2)
        let events = [
            event(sequence: 1, side: .visiting, raw: "Ground Out", eventID: eventID(101), batterSlot: 1),
            event(sequence: 2, side: .visiting, raw: "Home Run", eventID: eventID(102), batterSlot: 7),
            event(sequence: 3, side: .visiting, raw: "Ground Out", eventID: eventID(103), batterSlot: 3)
        ]
        _ = substitution
        return scenario(
            events: events,
            lineups: [],
            storedScore: CanonicalProjectedScore(home: 0, visiting: 1)
        )
    }

    static func longStressScenario(repetitions: Int) -> LongGameReplayScenario {
        var events: [CanonicalScoringEventEvidence] = []
        var sequence = 1
        for cycle in 0..<repetitions {
            let visitingSlot = cycle % 6 + 1
            let homeSlot = cycle % 6 + 1
            events.append(event(sequence: sequence, side: .visiting, raw: "Single", eventID: eventID(300 + sequence), batterSlot: visitingSlot)); sequence += 1
            events.append(event(sequence: sequence, side: .visiting, raw: "Home", eventID: eventID(300 + sequence), resultEvidence: .runnerScores(rawValue: "Home"), batterSlot: nil, runnerAdvancement: [.scored(runner: runner(side: .visiting, slot: visitingSlot), sourceBase: .first)])); sequence += 1
            events.append(event(sequence: sequence, side: .visiting, raw: "Ground Out", eventID: eventID(300 + sequence), batterSlot: (visitingSlot % 6) + 1)); sequence += 1
            events.append(event(sequence: sequence, side: .visiting, raw: "Fly Out", eventID: eventID(300 + sequence), batterSlot: ((visitingSlot + 1) % 6) + 1)); sequence += 1
            events.append(event(sequence: sequence, side: .visiting, raw: "Strikeout", eventID: eventID(300 + sequence), batterSlot: ((visitingSlot + 2) % 6) + 1)); sequence += 1
            events.append(event(sequence: sequence, side: .home, raw: "Ground Out", eventID: eventID(300 + sequence), batterSlot: homeSlot)); sequence += 1
            events.append(event(sequence: sequence, side: .home, raw: "Fly Out", eventID: eventID(300 + sequence), batterSlot: (homeSlot % 6) + 1)); sequence += 1
            events.append(event(sequence: sequence, side: .home, raw: "Strikeout", eventID: eventID(300 + sequence), batterSlot: ((homeSlot + 1) % 6) + 1)); sequence += 1
        }
        return scenario(events: events, storedScore: CanonicalProjectedScore(home: 0, visiting: repetitions))
    }

    static func scenario(
        events: [CanonicalScoringEventEvidence],
        lineups: [CanonicalReplayLineupInput] = [],
        pitchers: [CanonicalReplayPitcherInput] = [pitcherInput(side: .home, includeRelief: false), pitcherInput(side: .visiting, includeRelief: false)],
        storedScore: CanonicalProjectedScore?,
        expectedInnings: Int = 7
    ) -> LongGameReplayScenario {
        let game = CanonicalGameStatePrimitivesTestSupport.game(expectedInnings: .known(expectedInnings), lifecycle: .inProgress)
        let input = CanonicalReplayInput(
            game: game,
            homeTeamIdentity: .valid(ReplayTestSupport.homeTeamID),
            visitingTeamIdentity: .valid(ReplayTestSupport.visitingTeamID),
            initialBattingSide: .visiting,
            initialInning: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(expectedInnings)),
            initialOuts: CanonicalOutsState(outs: .known(0)),
            lineups: lineups,
            initialPitcherResponsibility: nil,
            pitchers: pitchers,
            recordedEvents: events,
            storedScore: storedScore
        )
        return LongGameReplayScenario(input: input, events: events)
    }

    static func event(
        sequence: Int,
        side: TeamSideRole,
        raw: String,
        eventID: UUID,
        resultEvidence: ScoringEventResultEvidence? = nil,
        batterSlot: Int?,
        runnerAdvancement: [RunnerStateEvidence] = []
    ) -> CanonicalScoringEventEvidence {
        CanonicalScoringEventEvidence(
            eventIdentity: .valid(eventID),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: sequence, sourceIndex: sequence - 1))],
            inningContext: CanonicalHalfInning(number: .known(1), half: side == .visiting ? .known(.top) : .known(.bottom), expectedInnings: .known(7)),
            teamSide: side,
            participants: ScoringEventParticipantEvidence(batter: batterSlot.map { batter(side: side, slot: $0) }),
            resultEvidence: resultEvidence ?? ScoringEventResultEvidence(rawValue: raw),
            runnerAdvancement: runnerAdvancement,
            unsupportedRawLegacyEvidence: ScoringEventResultEvidence(rawValue: raw) == .unsupportedRawResult(raw) ? [raw] : [],
            source: .syntheticVerification
        )
    }

    static func lineup(side: TeamSideRole, count: Int, substitutions: [CanonicalSubstitutionEvidence] = [], context: CanonicalBattingLineupContext = .traditional) -> CanonicalReplayLineupInput {
        let lineupID = StableIdentityAndOrderingTestSupport.fixedUUID(side == .visiting ? "97000000-0000-0000-0000-000000000101" : "97000000-0000-0000-0000-000000000102")
        let entries = (1...count).map { slot in
            CanonicalBattingOrderEntry(
                gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
                lineupIdentity: .valid(lineupID),
                participant: batter(side: side, slot: slot),
                slotEvidence: .known(slot),
                sourceOrderEvidence: OrderEvidence(kind: .sourceFile, value: slot - 1, sourceIndex: slot - 1),
                source: .syntheticVerification
            )
        }
        let evidence = CanonicalBattingOrderEvidence(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), lineupIdentity: .valid(lineupID), context: context, entries: entries)
        return CanonicalReplayLineupInput(side: side, lineup: evidence, substitutions: substitutions)
    }

    static func pitcherInput(side: TeamSideRole, includeRelief: Bool) -> CanonicalReplayPitcherInput {
        let starter = pitcherAppearance(side: side, order: 1, roleEvidence: [.startingPitcher, .activePitcher])
        guard includeRelief else { return CanonicalReplayPitcherInput(defensiveSide: side, appearances: [starter]) }
        let relief = pitcherAppearance(side: side, order: 2, roleEvidence: [.reliefPitcher])
        let change = CanonicalPitcherChangeEvidence(CanonicalSubstitutionEvidence(
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: side,
            incoming: .participant(batter(side: side, slot: 20)),
            outgoing: .participant(batter(side: side, slot: 19)),
            effectiveOrder: OrderEvidence(kind: .substitution, value: 13, sourceIndex: 13),
            pitcherChangeContext: true,
            roleEvidence: [.pitcherChange],
            source: .syntheticVerification
        ))
        return CanonicalReplayPitcherInput(defensiveSide: side, appearances: [starter, relief], pitcherChanges: [change])
    }

    static func pitcherAppearance(side: TeamSideRole, order: Int, roleEvidence: Set<PitcherAppearanceRoleEvidence>) -> CanonicalPitcherAppearanceEvidence {
        CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "98000000-0000-0000-0000-%012d", (side == .home ? 100 : 200) + order))),
            reusablePitcherIdentity: playerIdentity(side: side, slot: 30 + order),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: side,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: order, sourceIndex: order - 1),
            roleEvidence: roleEvidence,
            source: .syntheticVerification
        )
    }

    static func supportedSubstitution(side: TeamSideRole, outgoingSlot: Int, incomingSlot: Int, effectiveOrder: Int) -> CanonicalSubstitutionEvidence {
        CanonicalSubstitutionEvidence(
            substitutionIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("97000000-0000-0000-0000-000000000555")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: side,
            incoming: .participant(batter(side: side, slot: incomingSlot)),
            outgoing: .participant(batter(side: side, slot: outgoingSlot)),
            effectiveOrder: OrderEvidence(kind: .substitution, value: effectiveOrder, sourceIndex: effectiveOrder),
            battingSlotContext: .known(outgoingSlot),
            roleEvidence: [.batterReplacement, .lineupEntryReplacement],
            source: .syntheticVerification
        )
    }

    static func ambiguousSubstitution() -> CanonicalSubstitutionEvidence {
        CanonicalSubstitutionEvidence(
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            incoming: .participant(batter(side: .visiting, slot: 7)),
            outgoing: .missing,
            legacyArrayEvidence: .ambiguousOrdering,
            source: .syntheticVerification
        )
    }

    static func batter(side: TeamSideRole, slot: Int) -> LineupParticipantEvidence {
        ScoringCommandTestSupport.batter(side: side, id: playerID(side: side, slot: slot))
    }

    static func runner(side: TeamSideRole, slot: Int) -> RunnerIdentityEvidence {
        .gameParticipant(ScoringCommandTestSupport.participant(side: side, id: playerID(side: side, slot: slot), name: "Fixture Batter"))
    }

    static func playerIdentity(side: TeamSideRole, slot: Int) -> ImportedIdentifierEvidence {
        .valid(playerID(side: side, slot: slot))
    }

    static func playerID(side: TeamSideRole, slot: Int) -> UUID {
        let sideOffset = side == .visiting ? 1000 : 2000
        return StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "99000000-0000-0000-0000-%012d", sideOffset + slot))
    }

    static func eventID(_ value: Int) -> UUID {
        StableIdentityAndOrderingTestSupport.fixedUUID(String(format: "95000000-0000-0000-0000-%012d", value))
    }
}
