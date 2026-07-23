import Testing
@testable import ScoreKeep

@Suite("Task 9.2 Season Classification Suite")
struct Task92SeasonClassificationSuite {
    let classifier = SeasonClassifier()
    let currentYear = 2026
    
    @Test("Exact current-season classification")
    func currentSeason() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2026", currentYear: currentYear) == .current)
    }
    
    @Test("Prior-season classification")
    func priorSeason() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2025", currentYear: currentYear) == .prior)
    }
    
    @Test("Future-season classification")
    func futureSeason() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2027", currentYear: currentYear) == .future)
    }
    
    @Test("Unrelated identifier classification")
    func unrelatedIdentifier() {
        #expect(classifier.classify(identifier: "com.other.app.product", currentYear: currentYear) == .wrong)
    }
    
    @Test("Empty identifier classification")
    func emptyIdentifier() {
        #expect(classifier.classify(identifier: "", currentYear: currentYear) == .wrong)
    }
    
    @Test("Exact prefix with no suffix")
    func exactPrefixNoSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Too-short suffix")
    func tooShortSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass202", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Too-long suffix")
    func tooLongSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass20260", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Nonnumeric suffix")
    func nonnumericSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPassABCD", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Partially numeric suffix")
    func partiallyNumericSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass20A6", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Extra trailing character")
    func extraTrailingCharacter() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2026X", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Negative-looking suffix")
    func negativeLookingSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass-202", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("Leading-zero suffix")
    func leadingZeroSuffix() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass0026", currentYear: currentYear) == .missingSeason)
    }
    
    @Test("A large valid four-digit future season")
    func largeFutureSeason() {
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass9999", currentYear: currentYear) == .future)
    }
    
    @Test("The supplied currentYear controls the result deterministically")
    func deterministicControl() {
        // 2026 is current if year is 2026
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2026", currentYear: 2026) == .current)
        // 2026 is prior if year is 2027
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2026", currentYear: 2027) == .prior)
        // 2026 is future if year is 2025
        #expect(classifier.classify(identifier: "com.komakode.ScoreKeep.SeasonPass2026", currentYear: 2025) == .future)
    }
}
