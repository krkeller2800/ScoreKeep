import Testing
@testable import ScoreKeep

struct CanonicalInningSemanticsTests {
    @Test func topAndBottomOfSameInningRemainDistinct() {
        let top = CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7))
        let bottom = CanonicalHalfInning(number: .known(1), half: .known(.bottom), expectedInnings: .known(7))

        #expect(top != bottom)
        #expect(CanonicalInningSemanticsClassifier.sameInningDifferentHalf(top, bottom))
    }

    @Test func firstLaterRegulationAndExtraInningsClassify() {
        let first = CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)))
        let later = CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .known(5), half: .known(.bottom), expectedInnings: .known(7)))
        let extra = CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .known(8), half: .known(.top), expectedInnings: .known(7)))

        #expect(first.contains(.firstInning))
        #expect(first.contains(.regulationInning))
        #expect(later.contains(.regulationInning))
        #expect(extra.contains(.extraInning))
    }

    @Test func missingInvalidAndContradictoryInningEvidenceClassifies() {
        #expect(CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .missing, half: .known(.top))).contains(.missingInning))
        #expect(CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .invalid(0), half: .known(.top))).contains(.invalidInning))
        #expect(CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .invalid(-1), half: .known(.top))).contains(.invalidInning))
        #expect(CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .known(1), half: .missing)).contains(.missingHalf))
        #expect(CanonicalInningSemanticsClassifier.classify(CanonicalHalfInning(number: .known(1), half: .contradictory([.top, .bottom]))).contains(.contradictoryHalf))
    }

    @Test func expectedEndShortenedAndInterruptedEvidenceStaySeparate() {
        let inning = CanonicalHalfInning(
            number: .known(5),
            half: .known(.bottom),
            expectedInnings: .known(7),
            endOfHalfEvidence: true,
            interruptedEvidence: true,
            shortenedGameEvidence: true
        )
        let classifications = CanonicalInningSemanticsClassifier.classify(inning)

        #expect(classifications.contains(.regulationInning))
        #expect(classifications.contains(.endOfHalfEvidence))
        #expect(classifications.contains(.interruptedInningEvidence))
        #expect(classifications.contains(.shortenedGameEvidence))
    }

    @Test func repeatedEvaluationIsDeterministic() {
        let inning = CanonicalHalfInning(number: .known(10), half: .known(.top), expectedInnings: .known(9))

        #expect(CanonicalInningSemanticsClassifier.classify(inning) == CanonicalInningSemanticsClassifier.classify(inning))
    }
}
