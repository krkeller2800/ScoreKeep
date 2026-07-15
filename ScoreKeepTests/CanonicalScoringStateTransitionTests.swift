import Testing
@testable import ScoreKeep

struct CanonicalScoringStateTransitionTests {
    @Test func countTransitionDocumentsUnsupportedRepositoryAuthorityAndPreservesRawEvidence() {
        let result = CanonicalCountTransition.apply(CanonicalCountTransitionRequest(rawEvidence: ["balls=1", "strikes=2"]))
        let input = ScoringCommandTestSupport.state()

        #expect(result.supported == false)
        #expect(result.validation.disposition == .unsupported)
        #expect(result.preservedRawEvidence == ["balls=1", "strikes=2"])
        #expect(input.count == .unsupportedRepositoryEvidence)
    }

    @Test func outTransitionsAreBoundedAtomicAndCarryThirdOutContext() {
        let zeroToOne = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(0)), outsToAdd: 1))
        let oneToTwo = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(1)), outsToAdd: 1))
        let twoToThree = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(2)), outsToAdd: 1))
        let twoOutEvent = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(0)), outsToAdd: 2, participantOuts: [
            .runner(ScoringCommandTestSupport.runnerA, sourceBase: .first, outAt: .second),
            .runner(ScoringCommandTestSupport.runnerB, sourceBase: .second, outAt: .third)
        ]))
        let tooMany = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(2)), outsToAdd: 2))
        let negative = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(1)), outsToAdd: -1))

        #expect(zeroToOne.resultingOuts.outs == .known(1))
        #expect(oneToTwo.resultingOuts.outs == .known(2))
        #expect(twoToThree.resultingOuts.outs == .known(3))
        #expect(twoToThree.thirdOutContext)
        #expect(twoToThree.requiresEndOfHalfTransition)
        #expect(twoOutEvent.resultingOuts.runnerOutEvidence.count == 2)
        #expect(tooMany.rejected)
        #expect(tooMany.resultingOuts == CanonicalOutsState(outs: .known(2)))
        #expect(negative.rejected)
    }

    @Test func outTransitionRejectsDuplicateAndMissingParticipantEvidence() {
        let duplicate = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(0)), outsToAdd: 2, participantOuts: [
            .runner(ScoringCommandTestSupport.runnerA, sourceBase: .first, outAt: .second),
            .runner(ScoringCommandTestSupport.runnerA, sourceBase: .first, outAt: .second)
        ]))
        let missing = CanonicalOutTransition.apply(.init(inputOuts: CanonicalOutsState(outs: .known(0)), outsToAdd: 1, participantOuts: [
            .runner(.missingRelationship(PlayerDisplayEvidence()), sourceBase: .first, outAt: .second)
        ]))

        #expect(duplicate.rejected)
        #expect(missing.rejected)
        #expect(missing.inputRemainsUnchanged)
    }

    @Test func baseRunnerTransitionsApplySupportedMovementAndRejectContradictionsAtomically() {
        let occupancy = ScoringCommandTestSupport.occupancy([
            .activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA),
            .activeOccupant(base: .third, runner: ScoringCommandTestSupport.runnerB)
        ])
        let coordinated = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            batterOutcome: .reaches(.first, batterRunner()),
            runnerDestinations: [
                .advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second),
                .score(runner: ScoringCommandTestSupport.runnerB, from: .third, rbi: true)
            ]
        ))
        let occupiedConflict = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            batterOutcome: .reaches(.first, batterRunner())
        ))
        let sameRunnerTwice = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            runnerDestinations: [
                .advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second),
                .score(runner: ScoringCommandTestSupport.runnerA, from: .first)
            ]
        ))
        let sameDestination = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            runnerDestinations: [
                .advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second),
                .advance(runner: ScoringCommandTestSupport.runnerB, from: .third, to: .second)
            ]
        ))
        let backward = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            runnerDestinations: [.advance(runner: ScoringCommandTestSupport.runnerB, from: .third, to: .second)]
        ))

        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(coordinated.resultingOccupancy) == [.first, .second])
        #expect(coordinated.scoredRunners == [ScoringCommandTestSupport.runnerB])
        #expect(occupiedConflict.rejected)
        #expect(occupiedConflict.resultingOccupancy == occupancy)
        #expect(sameRunnerTwice.rejected)
        #expect(sameDestination.rejected)
        #expect(backward.rejected)
    }

    @Test func baseRunnerTransitionClassifiesMissingInvalidDisappearingAndUnrelatedRunners() {
        let invalid = RunnerIdentityEvidence.invalidIdentity(.invalid("bad-runner"), PlayerDisplayEvidence())
        let occupancy = ScoringCommandTestSupport.occupancy([
            .activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA),
            .activeOccupant(base: .second, runner: ScoringCommandTestSupport.runnerB)
        ])
        let missingIdentity = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .first, runner: .missingRelationship(PlayerDisplayEvidence()))]),
            runnerDestinations: []
        ))
        let invalidIdentity = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .first, runner: invalid)]),
            runnerDestinations: []
        ))
        let disappearing = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            expectedResultingOccupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .second, runner: ScoringCommandTestSupport.runnerB)])
        ))
        let moveOne = CanonicalBaseRunnerTransition.apply(.init(
            inputOccupancy: occupancy,
            runnerDestinations: [.advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .third)]
        ))

        #expect(missingIdentity.rejected)
        #expect(invalidIdentity.rejected)
        #expect(disappearing.rejected)
        #expect(moveOne.resultingOccupancy.runnerStates.contains(.activeOccupant(base: .second, runner: ScoringCommandTestSupport.runnerB)))
    }

    @Test func scoreCalculationDerivesRunsPreservesEvidenceAndDoesNotTrustStoredScore() {
        let noRun = CanonicalScoreCalculation.calculate(.init(inputScore: .init(home: 1, visiting: 2), battingSide: .visiting, scoredRunners: []))
        let visiting = CanonicalScoreCalculation.calculate(.init(inputScore: .init(), battingSide: .visiting, scoredRunners: [ScoringCommandTestSupport.runnerA], rbiEvidence: .count(1), earnedRunEvidence: .flag(true)))
        let home = CanonicalScoreCalculation.calculate(.init(inputScore: .init(home: 1, visiting: 2), battingSide: .home, scoredRunners: [ScoringCommandTestSupport.runnerA]))
        let duplicate = CanonicalScoreCalculation.calculate(.init(inputScore: .init(), battingSide: .home, scoredRunners: [ScoringCommandTestSupport.runnerA, ScoringCommandTestSupport.runnerA]))
        let unresolvedSide = CanonicalScoreCalculation.calculate(.init(inputScore: .init(home: 3, visiting: 4), battingSide: .unresolved, scoredRunners: [ScoringCommandTestSupport.runnerA]))
        let storedMismatch = CanonicalScoreCalculation.calculate(.init(inputScore: .init(), battingSide: .visiting, scoredRunners: [ScoringCommandTestSupport.runnerA], storedScoreEvidence: .init(home: 9, visiting: 9)))

        #expect(noRun.resultingScore == .init(home: 1, visiting: 2))
        #expect(visiting.resultingScore == .init(home: 0, visiting: 1))
        #expect(visiting.rbiEvidence == .count(1))
        #expect(visiting.earnedRunEvidence == .flag(true))
        #expect(home.resultingScore == .init(home: 2, visiting: 2))
        #expect(duplicate.resultingScore == .init(home: 1, visiting: 0))
        #expect(unresolvedSide.rejected)
        #expect(unresolvedSide.resultingScore == .init(home: 3, visiting: 4))
        #expect(storedMismatch.storedScoreMatchesProjection == false)
    }

    @Test func inningTransitionsAdvanceHalvesResetOutsClearBasesAndPreserveScore() {
        let top = CanonicalInningTransition.apply(.init(
            inning: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
            outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true),
            baseOccupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA)]),
            score: .init(home: 2, visiting: 3)
        ))
        let bottom = CanonicalInningTransition.apply(.init(
            inning: CanonicalHalfInning(number: .known(1), half: .known(.bottom), expectedInnings: .known(7)),
            outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true),
            baseOccupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .third, runner: ScoringCommandTestSupport.runnerA)]),
            score: .init(home: 2, visiting: 3)
        ))
        let extra = CanonicalInningTransition.apply(.init(
            inning: CanonicalHalfInning(number: .known(7), half: .known(.bottom), expectedInnings: .known(7)),
            outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true),
            baseOccupancy: CanonicalBaseOccupancy(),
            score: .init()
        ))

        #expect(top.resultingInning?.half == .known(.bottom))
        #expect(top.resultingInning?.number == .known(1))
        #expect(bottom.resultingInning?.half == .known(.top))
        #expect(bottom.resultingInning?.number == .known(2))
        #expect(top.resultingOuts.outs == .known(0))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(top.resultingBaseOccupancy).isEmpty)
        #expect(top.score == .init(home: 2, visiting: 3))
        #expect(extra.extraInning)
        #expect(extra.completedGameEvidence == false)
    }

    @Test func inningTransitionRejectsMissingInvalidAndContradictoryEvidenceWithoutMutation() {
        let missing = CanonicalInningTransition.apply(.init(inning: nil, outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true), baseOccupancy: CanonicalBaseOccupancy(), score: .init()))
        let invalid = CanonicalInningTransition.apply(.init(inning: CanonicalHalfInning(number: .invalid(-1), half: .known(.top)), outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true), baseOccupancy: CanonicalBaseOccupancy(), score: .init()))
        let badHalf = CanonicalInningTransition.apply(.init(inning: CanonicalHalfInning(number: .known(1), half: .missing), outs: CanonicalOutsState(outs: .known(3), thirdOutContext: true), baseOccupancy: CanonicalBaseOccupancy(), score: .init()))
        let explicit = CanonicalInningTransition.apply(.init(inning: CanonicalHalfInning(number: .known(2), half: .known(.top)), outs: CanonicalOutsState(outs: .known(0)), baseOccupancy: CanonicalBaseOccupancy(), score: .init(), explicitEndHalfCommand: true))

        #expect(missing.rejected)
        #expect(invalid.rejected)
        #expect(badHalf.rejected)
        #expect(explicit.rejected == false)
        #expect(explicit.resultingInning?.half == .known(.bottom))
    }

    @Test func composedApplicationIsAtomicDeterministicAndLeavesUnrelatedEvidenceUnchanged() {
        let input = ScoringCommandTestSupport.state(score: .init(home: 0, visiting: 0))
        let command = CanonicalScoringCommandVocabulary.command(rawResult: "Home Run", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
        let first = CanonicalScoringEventApplicator.applyComposed(command, to: input)
        let second = CanonicalScoringEventApplicator.applyComposed(command, to: input)

        #expect(first == second)
        #expect(first.event?.eventIdentity == .missing)
        #expect(first.resultingState.score == .init(home: 0, visiting: 1))
        #expect(first.resultingState.game == input.game)
        #expect(first.resultingState.currentBatter == input.currentBatter)
        #expect(first.resultingState.pitcherResponsibility == input.pitcherResponsibility)
        #expect(input.score == .init(home: 0, visiting: 0))
    }

    @Test func composedApplicationRejectsInvalidStagesWithoutPartialState() {
        let occupied = ScoringCommandTestSupport.state(occupancy: ScoringCommandTestSupport.occupancy([
            .activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA)
        ]))
        let single = CanonicalScoringCommandVocabulary.command(rawResult: "Single", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
        let failedRunner = CanonicalScoringEventApplicator.applyComposed(single, to: occupied)
        let unresolvedSide = CanonicalScoringCommand(intent: .runnerScores(runner: ScoringCommandTestSupport.runnerA, from: .first, rbi: false), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .unresolved, runnerDestinations: [.score(runner: ScoringCommandTestSupport.runnerA, from: .first)])
        let failedScore = CanonicalScoringEventApplicator.applyComposed(unresolvedSide, to: ScoringCommandTestSupport.state(side: .unresolved, occupancy: ScoringCommandTestSupport.occupancy([.activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA)]), lineup: []))
        let rejectedCommand = CanonicalScoringCommandVocabulary.command(rawResult: "Moon Shot", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
        let rejected = CanonicalScoringEventApplicator.applyComposed(rejectedCommand, to: ScoringCommandTestSupport.state())

        #expect(failedRunner.rejected)
        #expect(failedRunner.resultingState == occupied)
        #expect(failedScore.rejected)
        #expect(failedScore.resultingState.score == .init())
        #expect(rejected.event == nil)
        #expect(rejected.resultingState == ScoringCommandTestSupport.state())
    }

    @Test func fixturesRemainReadOnlyRegressionEvidenceForTransitions() throws {
        let completed = try CanonicalGameStatePrimitivesTestSupport.fixture("CompletedGame.ScoreKeep_Games")
        let inProgress = try CanonicalGameStatePrimitivesTestSupport.fixture("InProgressGame.ScoreKeep_Games")
        let multiple = try CanonicalGameStatePrimitivesTestSupport.fixture("MultipleAtbats.ScoreKeep_Games")
        let broken = try CanonicalGameStatePrimitivesTestSupport.fixture("BrokenAtbatRelationship.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let duplicate = try CanonicalGameStatePrimitivesTestSupport.fixture("DuplicateAtbatID.ScoreKeep_Games", directory: "MalformedAndUnsupported")

        #expect(completed.hscore + completed.vscore >= 0)
        #expect(inProgress.atbats.isEmpty == false)
        #expect(multiple.atbats.contains { $0.maxbase == "Home" || $0.outAt != "Safe" || $0.endOfInning })
        #expect(broken.atbats.contains { $0.team.name == "Fixture Third Team" })
        #expect(duplicate.atbats.map(\.id).count != Set(duplicate.atbats.map(\.id)).count)
    }

    private func batterRunner() -> RunnerIdentityEvidence {
        .gameParticipant(ScoringCommandTestSupport.participant(side: .visiting, id: CanonicalGameStatePrimitivesTestSupport.participantA, name: "Fixture Batter"))
    }
}
