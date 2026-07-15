import Foundation
import Testing
@testable import ScoreKeep

struct CompatibilityGameStateEvidenceTests {
    @Test func representativeGameFixturesMapStateEvidenceWithoutMutation() throws {
        let minimal = try CanonicalGameStatePrimitivesTestSupport.fixture("MinimalValid.ScoreKeep_Games")
        let completed = try CanonicalGameStatePrimitivesTestSupport.fixture("CompletedGame.ScoreKeep_Games")
        let inProgress = try CanonicalGameStatePrimitivesTestSupport.fixture("InProgressGame.ScoreKeep_Games")
        let multiple = try CanonicalGameStatePrimitivesTestSupport.fixture("MultipleAtbats.ScoreKeep_Games")
        let lineup = try CanonicalGameStatePrimitivesTestSupport.fixture("LineupGame.ScoreKeep_Games")
        let pitcher = try CanonicalGameStatePrimitivesTestSupport.fixture("PitcherGame.ScoreKeep_Games")

        let mappedGames = [minimal, completed, inProgress, multiple, lineup, pitcher].map {
            CanonicalGameStatePrimitivesTestSupport.importedGame($0)
        }

        #expect(mappedGames.allSatisfy { $0.identity.validIdentifier != nil })
        #expect(mappedGames.contains { if case .configured(expectedInnings: .known(6), lineupMode: _) = $0.configuration { return true }; return false })
        #expect(multiple.atbats.contains { $0.inning == 1.5 })
        #expect(multiple.atbats.contains { $0.maxbase == "Second" && $0.outAt == "Safe" })
    }

    @Test func malformedAndCompatibilityFixturesClassifyStateBoundaries() throws {
        let duplicate = try CanonicalGameStatePrimitivesTestSupport.fixture("DuplicateConflict.ScoreKeep_Games")
        let missingOptional = try CanonicalGameStatePrimitivesTestSupport.fixture("MissingOptionalValues.ScoreKeep_Games")
        let brokenAtbat = try CanonicalGameStatePrimitivesTestSupport.fixture("BrokenAtbatRelationship.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let duplicateAtbat = try CanonicalGameStatePrimitivesTestSupport.fixture("DuplicateAtbatID.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let unsupportedScore = try CanonicalGameStatePrimitivesTestSupport.fixture("UnsupportedScoreValue.ScoreKeep_Games", directory: "MalformedAndUnsupported")

        let duplicateClassifications = CanonicalGameMeaningClassifier.classifyGameSet([CanonicalGameStatePrimitivesTestSupport.importedGame(duplicate)])
        let missingOptionalInning = Int(missingOptional.atbats.first?.inning ?? 0)
        let missingOptionalClassifications = CanonicalInningSemanticsClassifier.classify(
            CanonicalHalfInning(number: .invalid(missingOptionalInning), half: .missing, expectedInnings: .missing)
        )

        #expect(duplicateClassifications.contains(.oneGame))
        #expect(missingOptionalClassifications.contains(.invalidInning))
        #expect(brokenAtbat.atbats.contains { $0.team.name == "Fixture Third Team" })
        #expect(duplicateAtbat.atbats.contains { $0.outAt == "Home" && $0.outs == 1 })
        #expect(unsupportedScore.hscore < 0)
    }

    @Test func legacyFieldsRemainCompatibilityEvidenceNotCanonicalMutation() throws {
        let game = try CanonicalGameStatePrimitivesTestSupport.fixture("MultipleAtbats.ScoreKeep_Games")
        let first = try #require(game.atbats.first)
        let inning = CanonicalHalfInning(
            number: .known(Int(first.inning.rounded(.up))),
            half: .unresolved,
            expectedInnings: .known(game.numInnings)
        )
        let outs = CanonicalOutsState(
            outs: .known(first.outs),
            runnerOutEvidence: first.outAt == "Safe" ? [] : [.unknownRunnerOut(base: .first)]
        )
        let occupancy = CanonicalBaseOccupancy(runnerStates: [
            .ambiguousLegacyMaxBase(first.maxbase),
            .ambiguousLegacyOutAt(first.outAt)
        ])

        #expect(CanonicalInningSemanticsClassifier.classify(inning).contains(.unresolvedHalf))
        #expect(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(outs).contains(.zeroOuts))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(occupancy).contains(.ambiguousLegacyAdvancementEvidence))
    }
}
