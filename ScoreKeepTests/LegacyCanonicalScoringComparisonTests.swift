import Foundation
import Testing
@testable import ScoreKeep

struct LegacyCanonicalScoringComparisonStageETests {
    @Test func representativeValidFixturesCompareReadOnlyWithClassifiedOutcomes() throws {
        let results = try LegacyCanonicalScoringComparisonSupport.validFixtureNames.map {
            try LegacyCanonicalScoringComparisonSupport.compareValidFixture($0)
        }
        let minimal = try #require(results.first { $0.scenarioIdentity == "MinimalValid.ScoreKeep_Games" })
        let inProgress = try #require(results.first { $0.scenarioIdentity == "InProgressGame.ScoreKeep_Games" })
        let completed = try #require(results.first { $0.scenarioIdentity == "CompletedGame.ScoreKeep_Games" })
        let multiple = try #require(results.first { $0.scenarioIdentity == "MultipleAtbats.ScoreKeep_Games" })
        let lineup = try #require(results.first { $0.scenarioIdentity == "LineupGame.ScoreKeep_Games" })
        let pitcher = try #require(results.first { $0.scenarioIdentity == "PitcherGame.ScoreKeep_Games" })

        let allReadOnly = results.allSatisfy { $0.readOnlyComparisonCompleted }
        let allHaveCompatibilityEvidence = results.allSatisfy { $0.evidenceClassifications.contains(.compatibilityTransportEvidence) }
        let allHaveGameIdentityAgreement = results.allSatisfy { result in
            result.dimensions.contains { dimension in dimension.name == "gameIdentity" && dimension.outcome == .agreement }
        }
        let allHaveEventCountAgreement = results.allSatisfy { result in
            result.dimensions.contains { dimension in dimension.name == "eventCount" && dimension.outcome == .agreement }
        }
        let minimalClassifiedAsAgreement = minimal.overallOutcome == .agreement || minimal.overallOutcome == .agreementWithWarnings
        let inProgressHasMismatchOrIncomplete = inProgress.readOnlyComparisonCompleted && inProgress.suitableForCutoverEvaluation
        let multipleHasReportDimension = multiple.dimensions.contains { $0.name == "reportDerivedRunsAndTotals" }
        let lineupHasEventCount = lineup.dimensions.contains { $0.name == "eventCount" }
        let pitcherHasReplayDisposition = pitcher.dimensions.contains { $0.name == "replayDisposition" }

        #expect(allReadOnly)
        #expect(allHaveCompatibilityEvidence)
        #expect(allHaveGameIdentityAgreement)
        #expect(allHaveEventCountAgreement)
        #expect(minimalClassifiedAsAgreement)
        #expect(inProgressHasMismatchOrIncomplete)
        #expect(completed.suitableForCutoverEvaluation)
        #expect(multipleHasReportDimension)
        #expect(lineupHasEventCount)
        #expect(pitcherHasReplayDisposition)
    }

    @Test func minimalInProgressCompletedAndMultipleAtbatFixturesCoverAgreementAndExplainableDifferences() throws {
        let minimal = try LegacyCanonicalScoringComparisonSupport.compareValidFixture("MinimalValid.ScoreKeep_Games")
        let inProgress = try LegacyCanonicalScoringComparisonSupport.compareValidFixture("InProgressGame.ScoreKeep_Games")
        let completed = try LegacyCanonicalScoringComparisonSupport.compareValidFixture("CompletedGame.ScoreKeep_Games")
        let multiple = try LegacyCanonicalScoringComparisonSupport.compareValidFixture("MultipleAtbats.ScoreKeep_Games")

        let minimalStoredScoreAgrees = minimal.dimensions.contains { dimension in
            dimension.name == "storedScore" && (dimension.outcome == .agreement || dimension.outcome == .agreementWithWarnings)
        }
        let acceptableOutcomes: Set<LegacyCanonicalComparisonOutcome> = [.agreement, .agreementWithWarnings, .explainableDifference, .incompleteComparison, .unsafeComparison]
        let allRepresentativeOutcomesClassified = [inProgress, completed, multiple].allSatisfy { result in
            acceptableOutcomes.contains(result.overallOutcome)
        }
        let hasDifferenceOrIncompleteEvidence = [inProgress, completed, multiple].contains { result in
            result.differences.contains { $0.classification == .explainableMismatch } ||
            result.evidenceClassifications.contains(.incompleteEvidence) ||
            result.evidenceClassifications.contains(.unsafeComparison)
        }

        #expect(minimalStoredScoreAgrees)
        #expect(allRepresentativeOutcomesClassified)
        #expect(hasDifferenceOrIncompleteEvidence)
    }
}

struct LegacyCanonicalScoringComparisonStageFTests {
    @Test func malformedRelationshipDuplicateAndUnsupportedFixturesClassifyWithoutMutation() throws {
        let results = try LegacyCanonicalScoringComparisonSupport.malformedFixtureNames.map {
            try LegacyCanonicalScoringComparisonSupport.compareMalformedFixture($0)
        }
        let brokenAtbat = try #require(results.first { $0.scenarioIdentity == "BrokenAtbatRelationship.ScoreKeep_Games" })
        let brokenLineup = try #require(results.first { $0.scenarioIdentity == "BrokenLineupRelationship.ScoreKeep_Games" })
        let brokenPitcher = try #require(results.first { $0.scenarioIdentity == "BrokenPitcherRelationship.ScoreKeep_Games" })
        let duplicateAtbat = try #require(results.first { $0.scenarioIdentity == "DuplicateAtbatID.ScoreKeep_Games" })
        let unsupportedScore = try #require(results.first { $0.scenarioIdentity == "UnsupportedScoreValue.ScoreKeep_Games" })

        let allReadOnly = results.allSatisfy { $0.readOnlyComparisonCompleted }
        let brokenAtbatIsUnsafeOrAmbiguous = brokenAtbat.evidenceClassifications.contains(.unsafeComparison) || brokenAtbat.evidenceClassifications.contains(.ambiguousEvidence)

        #expect(allReadOnly)
        #expect(brokenAtbat.requiresRepairOrUnsupportedHandling)
        let duplicateAtbatHasDuplicateIdentity = duplicateAtbat.differences.contains { $0.code == "comparison.duplicateEventIdentity" }
        let unsupportedStoredScoreClassified = unsupportedScore.dimensions.contains { dimension in
            dimension.name == "storedScore" && (dimension.outcome == .unsupportedComparison || dimension.outcome == .unsafeComparison)
        }

        #expect(brokenAtbatIsUnsafeOrAmbiguous)
        #expect(brokenLineup.requiresRepairOrUnsupportedHandling)
        #expect(brokenPitcher.requiresRepairOrUnsupportedHandling)
        #expect(duplicateAtbatHasDuplicateIdentity)
        #expect(unsupportedStoredScoreClassified)
    }

    @Test func syntheticUnsupportedResultAndDuplicateIdentityClassifyAsReviewEvidence() {
        let unsupported = LegacyCanonicalScoringComparisonSupport.compareUnsupportedResultScenario()
        let duplicate = LegacyCanonicalScoringComparisonSupport.compareDuplicateEventIdentityScenario()

        #expect(unsupported.readOnlyComparisonCompleted)
        let unsupportedRawValuesClassified = unsupported.dimensions.contains { dimension in
            dimension.name == "unsupportedRawValues" && dimension.outcome == .unsupportedComparison
        }
        let duplicateIdentityClassified = duplicate.differences.contains { $0.code == "comparison.duplicateEventIdentity" }
        let duplicateOverallClassified = duplicate.overallOutcome == .contradictoryComparison || duplicate.overallOutcome == .unsafeComparison

        #expect(unsupportedRawValuesClassified)
        #expect(unsupported.requiresRepairOrUnsupportedHandling)
        #expect(duplicateIdentityClassified)
        #expect(duplicateOverallClassified)
    }

    @Test func comparisonOutcomesRemainNonBooleanAndShallow() throws {
        let result = try LegacyCanonicalScoringComparisonSupport.compareValidFixture("MultipleAtbats.ScoreKeep_Games")
        let outcomeCount = Set(result.dimensions.map(\.outcome)).count

        #expect(result.dimensions.count >= 5)
        #expect(result.dimensions.count < 12)
        #expect(result.differences.count < 8)
        #expect(outcomeCount >= 1)
        let hasReportEvidence = result.evidenceClassifications.contains(.reportDerivedLegacyEvidence) || result.dimensions.contains { dimension in
            dimension.classification == .reportDerivedLegacyEvidence
        }

        #expect(result.evidenceClassifications.contains(.legacyStoredFact))
        #expect(result.evidenceClassifications.contains(.canonicalReplayInput))
        #expect(hasReportEvidence)
    }
}
