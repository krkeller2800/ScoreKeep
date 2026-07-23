import Testing
@testable import ScoreKeep

@Suite("Task 9.4 Transaction Evidence Normalizer Suite")
struct Task94TransactionEvidenceNormalizerSuite {
    let normalizer = TransactionEvidenceNormalizer()
    let currentYear = 2026
    
    @Test("normalizesVerifiedCurrentSeason")
    func normalizesVerifiedCurrentSeason() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2026",
            isVerified: true,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .current,
            isVerified: true,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesVerifiedPriorSeason")
    func normalizesVerifiedPriorSeason() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2025",
            isVerified: true,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .prior,
            isVerified: true,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesVerifiedFutureSeason")
    func normalizesVerifiedFutureSeason() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2027",
            isVerified: true,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .future,
            isVerified: true,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesWrongProduct")
    func normalizesWrongProduct() {
        let input = TransactionEvidenceInput(
            productID: "com.other.product",
            isVerified: true,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .wrong,
            isVerified: true,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesMissingSeason")
    func normalizesMissingSeason() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass",
            isVerified: true,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .missingSeason,
            isVerified: true,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesUnverified")
    func normalizesUnverified() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2026",
            isVerified: false,
            isRevoked: false
        )
        let expected = EntitlementEvidence(
            season: .current,
            isVerified: false,
            isRevoked: false
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesRevoked")
    func normalizesRevoked() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2026",
            isVerified: true,
            isRevoked: true
        )
        let expected = EntitlementEvidence(
            season: .current,
            isVerified: true,
            isRevoked: true
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
    
    @Test("normalizesUnverifiedAndRevoked")
    func normalizesUnverifiedAndRevoked() {
        let input = TransactionEvidenceInput(
            productID: "com.komakode.ScoreKeep.SeasonPass2026",
            isVerified: false,
            isRevoked: true
        )
        let expected = EntitlementEvidence(
            season: .current,
            isVerified: false,
            isRevoked: true
        )
        #expect(normalizer.normalize(input: input, currentYear: currentYear) == expected)
    }
}
