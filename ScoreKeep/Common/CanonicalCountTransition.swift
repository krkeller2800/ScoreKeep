import Foundation

struct CanonicalCountTransitionRequest: Hashable, Sendable {
    let countEvidence: BallStrikeCountEvidence
    let rawEvidence: [String]

    init(countEvidence: BallStrikeCountEvidence = .unsupportedRepositoryEvidence, rawEvidence: [String] = []) {
        self.countEvidence = countEvidence
        self.rawEvidence = rawEvidence
    }
}

struct CanonicalCountTransitionResult: Hashable, Sendable {
    let inputCount: BallStrikeCountEvidence
    let resultingCount: BallStrikeCountEvidence
    let validation: CanonicalValidationResult
    let preservedRawEvidence: [String]
    let supported: Bool
    let inputRemainsUnchanged: Bool
}

enum CanonicalCountTransition {
    static func apply(_ request: CanonicalCountTransitionRequest) -> CanonicalCountTransitionResult {
        let classifications = CanonicalCountAndOutsSemanticsClassifier.classifyCount(request.countEvidence)
        let supported = classifications.isDisjoint(with: [.unsupportedRepositoryEvidence, .unsupportedCount, .invalidCount, .contradictoryCountEvidence])
        let findings: [CanonicalValidationFinding]

        if classifications.contains(.unsupportedRepositoryEvidence) {
            findings = [CanonicalDomainValidator.finding(
                "countTransition.unsupportedRepositoryEvidence",
                concept: .count,
                severity: .unsupported,
                disposition: .unsupported,
                summary: "The repository has no persisted ball-and-strike count authority for transition handling.",
                unsupported: true
            )]
        } else if classifications.contains(.invalidCount) {
            findings = [CanonicalDomainValidator.finding(
                "countTransition.invalidCount",
                concept: .count,
                severity: .rejection,
                disposition: .rejected,
                summary: "Count evidence is outside the supported ball-and-strike bounds."
            )]
        } else if classifications.contains(.contradictoryCountEvidence) {
            findings = [CanonicalDomainValidator.finding(
                "countTransition.contradictoryCount",
                concept: .count,
                severity: .contradiction,
                disposition: .contradictory,
                summary: "Count evidence is contradictory and cannot be transitioned."
            )]
        } else if classifications.contains(.unsupportedCount) {
            findings = [CanonicalDomainValidator.finding(
                "countTransition.unsupportedCountEvidence",
                concept: .count,
                severity: .unsupported,
                disposition: .unsupported,
                summary: "Raw count evidence is preserved but unsupported.",
                unsupported: true
            )]
        } else {
            findings = []
        }

        return CanonicalCountTransitionResult(
            inputCount: request.countEvidence,
            resultingCount: request.countEvidence,
            validation: CanonicalValidationResult(findings: findings),
            preservedRawEvidence: request.rawEvidence,
            supported: supported,
            inputRemainsUnchanged: true
        )
    }
}
