import Testing
@testable import ScoreKeep

@Suite("Task 9.3 Entitlement Classification Suite")
struct Task93EntitlementClassificationSuite {
    
    let classifier = EntitlementClassifier()

    @Test("emptyEvidenceReturnsStatusUnavailable")
    func emptyEvidenceReturnsStatusUnavailable() {
        let evidence: [EntitlementEvidence] = []
        let result = classifier.classify(evidence: evidence)
        #expect(result == .statusUnavailable)
    }

    @Test("validCurrentSeasonReturnsEntitled")
    func validCurrentSeasonReturnsEntitled() {
        let evidence = [
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .entitled)
    }

    @Test("validPriorSeasonReturnsPriorSeason")
    func validPriorSeasonReturnsPriorSeason() {
        let evidence = [
            EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .priorSeason)
    }

    @Test("validFutureSeasonReturnsFutureSeason")
    func validFutureSeasonReturnsFutureSeason() {
        let evidence = [
            EntitlementEvidence(season: .future, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .futureSeason)
    }

    @Test("wrongProductReturnsNotEntitled")
    func wrongProductReturnsNotEntitled() {
        let evidence = [
            EntitlementEvidence(season: .wrong, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .notEntitled)
    }

    @Test("missingSeasonReturnsNotEntitled")
    func missingSeasonReturnsNotEntitled() {
        let evidence = [
            EntitlementEvidence(season: .missingSeason, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .notEntitled)
    }

    @Test("unverifiedCurrentSeasonReturnsNotEntitled")
    func unverifiedCurrentSeasonReturnsNotEntitled() {
        let evidence = [
            EntitlementEvidence(season: .current, isVerified: false, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .notEntitled)
    }

    @Test("revokedCurrentSeasonReturnsNotEntitled")
    func revokedCurrentSeasonReturnsNotEntitled() {
        let evidence = [
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: true)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .notEntitled)
    }

    @Test("currentSeasonTakesPrecedenceOverPriorSeason")
    func currentSeasonTakesPrecedenceOverPriorSeason() {
        let evidence = [
            EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .entitled)
    }

    @Test("multipleEvidenceClassificationIsOrderIndependent")
    func multipleEvidenceClassificationIsOrderIndependent() {
        let evidence1 = [
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .future, isVerified: true, isRevoked: false)
        ]
        
        let evidence2 = [
            EntitlementEvidence(season: .future, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: false)
        ]
        
        let result1 = classifier.classify(evidence: evidence1)
        let result2 = classifier.classify(evidence: evidence2)
        
        #expect(result1 == .entitled)
        #expect(result2 == .entitled)
        #expect(result1 == result2)
    }

    @Test("invalidCurrentEvidenceDoesNotOverrideValidPriorSeason")
    func invalidCurrentEvidenceDoesNotOverrideValidPriorSeason() {
        let evidence = [
            EntitlementEvidence(season: .current, isVerified: true, isRevoked: true),
            EntitlementEvidence(season: .current, isVerified: false, isRevoked: false),
            EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .wrong, isVerified: true, isRevoked: false),
            EntitlementEvidence(season: .missingSeason, isVerified: true, isRevoked: false)
        ]
        let result = classifier.classify(evidence: evidence)
        #expect(result == .priorSeason)
    }
}
