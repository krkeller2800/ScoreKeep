import Testing
@testable import ScoreKeep

struct CanonicalCountAndOutsSemanticsTests {
    @Test func repositoryCountBoundaryAndOptionalCountClassify() {
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.unsupportedRepositoryEvidence).contains(.unsupportedRepositoryEvidence))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.missing).contains(.missingCount))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.invalid(balls: 4, strikes: 2)).contains(.invalidCount))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.unsupported("pitch-by-pitch")).contains(.unsupportedCount))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.known(balls: 3, strikes: 2)).contains(.fullCount))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyCount(.resetBoundary).contains(.countResetBoundary))
    }

    @Test func zeroOneTwoThirdAndInvalidOutStatesClassify() {
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(0))).contains(.zeroOuts))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(1))).contains(.oneOut))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(2))).contains(.twoOuts))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(3))).contains(.thirdOutContext))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(4))).contains(.impossibleFourthOrGreaterOutState))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .known(-1))).contains(.invalidNegativeOuts))
    }

    @Test func missingConflictingRunnerOutAndEndOfHalfEvidenceRemainSeparate() {
        let runner = CanonicalGameStatePrimitivesTestSupport.runner()
        let state = CanonicalOutsState(
            outs: .missing,
            outsRecordedByEvent: 1,
            runnerOutEvidence: [.runnerOut(runner, base: .second)],
            endOfHalfEvidence: true,
            thirdOutContext: true
        )
        let classifications = CanonicalCountAndOutsSemanticsClassifier.classifyOuts(state)

        #expect(classifications.contains(.missingOuts))
        #expect(classifications.contains(.outsRecordedByEvent(1)))
        #expect(classifications.contains(.runnerOutContext))
        #expect(classifications.contains(.endOfHalfEvidence))
        #expect(classifications.contains(.thirdOutContext))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(CanonicalOutsState(outs: .conflicting([1, 2]))).contains(.conflictingOutsEvidence))
    }

    @Test func thirdOutContextDoesNotMutateInningStateAndEvaluationIsDeterministic() {
        let inning = CanonicalHalfInning(number: .known(3), half: .known(.top), expectedInnings: .known(7))
        let outs = CanonicalOutsState(outs: .known(3), thirdOutContext: true)

        #expect(CanonicalInningSemanticsClassifier.classify(inning).contains(.endOfHalfEvidence) == false)
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(outs) == CanonicalCountAndOutsSemanticsClassifier.classifyOuts(outs))
    }
}
