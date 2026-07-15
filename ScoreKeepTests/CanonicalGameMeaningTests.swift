import Testing
@testable import ScoreKeep

struct CanonicalGameMeaningTests {
    @Test func sameValidGameIDWithMatchingAndConflictingEvidenceClassifies() {
        let base = CanonicalGameStatePrimitivesTestSupport.game()
        let matching = CanonicalGameStatePrimitivesTestSupport.game(location: "Different Display Field")
        let conflicting = CanonicalGameStatePrimitivesTestSupport.game(lifecycle: .completed)

        #expect(base == matching)
        #expect(CanonicalGameMeaningClassifier.compareIdentity(base, matching) == .sameIdentityConflictingEvidence(["location"]))
        #expect(CanonicalGameMeaningClassifier.compareIdentity(base, conflicting) == .sameIdentityConflictingEvidence(["lifecycle"]))
    }

    @Test func differentGameIDsWithSameTeamsDateAndDoubleheaderRemainDistinct() {
        let first = CanonicalGameStatePrimitivesTestSupport.game(id: CanonicalGameStatePrimitivesTestSupport.gameA, doubleheaderDesignator: "1")
        let second = CanonicalGameStatePrimitivesTestSupport.game(id: CanonicalGameStatePrimitivesTestSupport.gameB, doubleheaderDesignator: "2")
        let classifications = CanonicalGameMeaningClassifier.classifyGameSet([first, second])

        #expect(first != second)
        #expect(CanonicalGameMeaningClassifier.compareIdentity(first, second) == .distinctIdentitiesDifferentDisplay)
        #expect(classifications.contains(.sameTeamsAndDateDistinctGames))
        #expect(classifications.contains(.doubleheaderDistinctGames))
    }

    @Test func missingInvalidDuplicateAndConflictingGameIdentityClassify() {
        let missing = CanonicalGameStatePrimitivesTestSupport.game(id: nil)
        let invalid = CanonicalGameStatePrimitivesTestSupport.game(rawID: "not-a-game-uuid")
        let duplicate = CanonicalGameStatePrimitivesTestSupport.game()
        let conflictingDuplicate = CanonicalGameStatePrimitivesTestSupport.game(lifecycle: .interrupted)

        #expect(CanonicalGameMeaningClassifier.compareIdentity(missing, duplicate) == .missingIdentity)
        #expect(CanonicalGameMeaningClassifier.compareIdentity(invalid, duplicate) == .invalidIdentity)
        #expect(CanonicalGameMeaningClassifier.classifyGameSet([duplicate, duplicate]).contains(.duplicateGame))
        #expect(CanonicalGameMeaningClassifier.classifyGameSet([duplicate, conflictingDuplicate]).contains(.duplicateConflictingGame(["lifecycle"])))
    }

    @Test func lifecycleAndOriginEvidenceClassifyWithoutRedefiningIdentity() {
        let statuses: [GameLifecycleEvidence: GameLifecycleClassification] = [
            .draft: .draft,
            .ready: .ready,
            .inProgress: .inProgress,
            .completed: .completed,
            .interrupted: .interrupted,
            .incomplete: .incomplete,
            .imported: .imported,
            .unknown: .unknown,
            .unresolved: .unresolved
        ]

        for (status, classification) in statuses {
            #expect(CanonicalGameMeaningClassifier.classifyLifecycle(status) == classification)
        }
        #expect(CanonicalGameMeaningClassifier.classifyOrigin(.imported) == .imported)
        #expect(CanonicalGameMeaningClassifier.classifyOrigin(.seeded) == .seeded)
        #expect(CanonicalGameMeaningClassifier.classifyOrigin(.sample) == .sample)

        let imported = CanonicalGameStatePrimitivesTestSupport.game(origin: .imported, lifecycle: .imported)
        let completed = CanonicalGameStatePrimitivesTestSupport.game(origin: .userCreated, lifecycle: .completed)
        #expect(imported == completed)
    }

    @Test func storedScoreDoesNotDefineGameIdentityAndRepeatedEvaluationIsDeterministic() {
        let zeroScore = CanonicalGameStatePrimitivesTestSupport.game(homeScore: 0, visitingScore: 0)
        let changedScore = CanonicalGameStatePrimitivesTestSupport.game(homeScore: 12, visitingScore: 9)
        let first = CanonicalGameMeaningClassifier.classifyGameSet([zeroScore, changedScore])
        let second = CanonicalGameMeaningClassifier.classifyGameSet([zeroScore, changedScore])

        #expect(zeroScore == changedScore)
        #expect(CanonicalGameMeaningClassifier.compareIdentity(zeroScore, changedScore) == .sameIdentityMatchingEvidence)
        #expect(first == second)
    }
}
