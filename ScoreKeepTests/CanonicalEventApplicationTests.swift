import Testing
@testable import ScoreKeep

struct CanonicalEventApplicationTests {
    @Test func batterReachesFirstAndLaterBaseWithEmptyBases() {
        let first = CanonicalScoringEventApplicator.apply(command(raw: "Single"), to: ScoringCommandTestSupport.state())
        let second = CanonicalScoringEventApplicator.apply(command(raw: "Double"), to: ScoringCommandTestSupport.state())

        #expect(first.applied)
        #expect(first.event?.resultEvidence == .batterReachesBase(rawValue: "Single"))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(first.resultingState.baseOccupancy) == [.first])
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(second.resultingState.baseOccupancy) == [.second])
    }

    @Test func batterOutWithFewerThanTwoPriorOutsAddsOneOut() {
        let result = CanonicalScoringEventApplicator.apply(command(raw: "Ground Out"), to: ScoringCommandTestSupport.state(outs: 1))

        #expect(result.applied)
        #expect(result.resultingState.outs.outs == .known(2))
        #expect(result.event?.outsEvidence?.outsRecordedByEvent == 1)
    }

    @Test func runnerAdvancesScoresAndIsOut() {
        let occupancy = ScoringCommandTestSupport.occupancy([.activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA)])
        let advance = CanonicalScoringCommand(intent: .runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second, stolenBase: true), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second, stolenBase: true)], stolenBaseEvidence: .count(1))
        let score = CanonicalScoringCommand(intent: .runnerScores(runner: ScoringCommandTestSupport.runnerA, from: .first, rbi: true), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.score(runner: ScoringCommandTestSupport.runnerA, from: .first, rbi: true)], rbiEvidence: .count(1))
        let out = CanonicalScoringCommand(intent: .runnerOut(runner: ScoringCommandTestSupport.runnerA, from: .first, outAt: .second), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.out(runner: ScoringCommandTestSupport.runnerA, from: .first, outAt: .second)])

        let advanced = CanonicalScoringEventApplicator.apply(advance, to: ScoringCommandTestSupport.state(occupancy: occupancy))
        let scored = CanonicalScoringEventApplicator.apply(score, to: ScoringCommandTestSupport.state(occupancy: occupancy))
        let runnerOut = CanonicalScoringEventApplicator.apply(out, to: ScoringCommandTestSupport.state(occupancy: occupancy))

        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(advanced.resultingState.baseOccupancy) == [.second])
        #expect(scored.event?.runsScored == .count(1))
        #expect(scored.event?.rbiEvidence == .count(1))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(scored.resultingState.baseOccupancy).isEmpty)
        #expect(runnerOut.resultingState.outs.outs == .known(1))
        #expect(runnerOut.event?.runnerAdvancement.contains { if case .out = $0 { return true }; return false } == true)
    }

    @Test func rbiSacrificeStolenOrderingAndEarnedRunEvidenceCarryIntoEvent() {
        let command = CanonicalScoringCommand(
            intent: .batterOut(result: .batterOut(rawValue: "Sacrifice Fly")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            rbiEvidence: .count(1),
            sacrificeEvidence: .count(1),
            stolenBaseEvidence: .count(1),
            earnedRunEvidence: .flag(false),
            proposedEventIdentity: .valid(ScoringCommandTestSupport.eventID),
            orderingEvidence: [.knownSequence(.init(kind: .eventSequence, value: 4))]
        )
        let result = CanonicalScoringEventApplicator.apply(command, to: ScoringCommandTestSupport.state())

        #expect(result.event?.eventIdentity == .valid(ScoringCommandTestSupport.eventID))
        #expect(result.event?.orderingEvidence == [.knownSequence(.init(kind: .eventSequence, value: 4))])
        #expect(result.event?.rbiEvidence == .count(1))
        #expect(result.event?.sacrificeEvidence == .count(1))
        #expect(result.event?.stolenBaseEvidence == .count(1))
        #expect(result.event?.earnedRunEvidence == .flag(false))
    }

    @Test func unsupportedAndRejectedCommandsProduceNoEventAndLeaveInputUnchanged() {
        let input = ScoringCommandTestSupport.state()
        let unsupported = CanonicalScoringCommandVocabulary.command(rawResult: "Moon Shot", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
        let rejected = CanonicalScoringCommand(intent: .batterOut(result: .batterOut(rawValue: "Ground Out")), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter(), outsRequested: 1)

        let unsupportedResult = CanonicalScoringEventApplicator.apply(unsupported, to: input)
        let rejectedResult = CanonicalScoringEventApplicator.apply(rejected, to: ScoringCommandTestSupport.state(outs: 2))

        #expect(unsupportedResult.event == nil)
        #expect(unsupportedResult.resultingState == input)
        #expect(unsupportedResult.preservedUnsupportedEvidence == ["Moon Shot"])
        #expect(rejectedResult.event == nil)
        #expect(rejectedResult.resultingState == ScoringCommandTestSupport.state(outs: 2))
    }

    @Test func inputUnrelatedRunnerAndParticipantEvidenceRemainUnchanged() {
        let occupancy = ScoringCommandTestSupport.occupancy([
            .activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA),
            .activeOccupant(base: .third, runner: ScoringCommandTestSupport.runnerB)
        ])
        let command = CanonicalScoringCommand(intent: .runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second, stolenBase: false), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second)])
        let input = ScoringCommandTestSupport.state(occupancy: occupancy)
        let result = CanonicalScoringEventApplicator.apply(command, to: input)

        #expect(result.inputState == input)
        #expect(result.inputStateRemainsUnchanged)
        #expect(result.resultingState.baseOccupancy.runnerStates.contains(.activeOccupant(base: .third, runner: ScoringCommandTestSupport.runnerB)))
        #expect(result.resultingState.currentBatter == input.currentBatter)
    }

    @Test func sameInputAndCommandProduceIdenticalOutputAndNoRandomEventIdentity() {
        let input = ScoringCommandTestSupport.state()
        let command = command(raw: "Triple")
        let first = CanonicalScoringEventApplicator.apply(command, to: input)
        let second = CanonicalScoringEventApplicator.apply(command, to: input)

        #expect(first == second)
        #expect(first.event?.eventIdentity == .missing)
    }

    private func command(raw: String) -> CanonicalScoringCommand {
        CanonicalScoringCommandVocabulary.command(
            rawResult: raw,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter()
        )
    }
}
