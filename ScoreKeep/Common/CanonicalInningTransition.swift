import Foundation

struct CanonicalInningTransitionRequest: Hashable, Sendable {
    let inning: CanonicalHalfInning?
    let outs: CanonicalOutsState
    let baseOccupancy: CanonicalBaseOccupancy
    let score: CanonicalProjectedScore
    let explicitEndHalfCommand: Bool

    init(inning: CanonicalHalfInning?, outs: CanonicalOutsState, baseOccupancy: CanonicalBaseOccupancy, score: CanonicalProjectedScore, explicitEndHalfCommand: Bool = false) {
        self.inning = inning
        self.outs = outs
        self.baseOccupancy = baseOccupancy
        self.score = score
        self.explicitEndHalfCommand = explicitEndHalfCommand
    }
}

struct CanonicalInningTransitionResult: Hashable, Sendable {
    let inputInning: CanonicalHalfInning?
    let resultingInning: CanonicalHalfInning?
    let resultingOuts: CanonicalOutsState
    let resultingBaseOccupancy: CanonicalBaseOccupancy
    let score: CanonicalProjectedScore
    let validation: CanonicalValidationResult
    let expectedInnings: ExpectedInningCountEvidence
    let extraInning: Bool
    let completedGameEvidence: Bool
    let rejected: Bool
    let inputRemainsUnchanged: Bool
}

enum CanonicalInningTransition {
    static func apply(_ request: CanonicalInningTransitionRequest) -> CanonicalInningTransitionResult {
        var findings: [CanonicalValidationFinding] = []
        guard let inning = request.inning else {
            findings.append(finding("inningTransition.missingInning", .incomplete, .incomplete, "Inning evidence is missing."))
            return rejected(request, validation: CanonicalValidationResult(findings: findings), expected: .missing)
        }

        let classifications = CanonicalInningSemanticsClassifier.classify(inning)
        if classifications.contains(.missingInning) || classifications.contains(.invalidInning) {
            findings.append(finding("inningTransition.invalidInning", .rejection, .rejected, "Inning number cannot be transitioned."))
        }
        if classifications.contains(.missingHalf) || classifications.contains(.unresolvedHalf) || classifications.contains(.contradictoryHalf) {
            findings.append(finding("inningTransition.invalidHalf", .rejection, .rejected, "Half-inning evidence cannot be transitioned."))
        }
        if request.outs.thirdOutContext == false && request.outs.outs.outValue != 3 && request.explicitEndHalfCommand == false {
            findings.append(finding("inningTransition.thirdOutRequired", .incomplete, .incomplete, "End-half transition requires third-out context or explicit end-half command."))
        }
        if inning.endOfHalfEvidence && request.explicitEndHalfCommand == false && request.outs.thirdOutContext == false {
            findings.append(finding("inningTransition.contradictoryEndHalfEvidence", .contradiction, .contradictory, "End-of-half evidence conflicts with outs context."))
        }

        let validation = CanonicalValidationResult(findings: findings)
        guard validation.futureWriteMustStop == false, let number = inning.number.inningNumber, case let .known(half) = inning.half else {
            return rejected(request, validation: validation, expected: inning.expectedInnings)
        }

        let nextNumber = half == .top ? number : number + 1
        let nextHalf: InningHalf = half == .top ? .bottom : .top
        let resultingInning = CanonicalHalfInning(number: .known(nextNumber), half: .known(nextHalf), expectedInnings: inning.expectedInnings, source: inning.source)
        let extra = inning.expectedInnings.count.map { nextNumber > $0 } ?? false

        return CanonicalInningTransitionResult(
            inputInning: request.inning,
            resultingInning: resultingInning,
            resultingOuts: CanonicalOutsState(outs: .known(0), source: request.outs.source),
            resultingBaseOccupancy: CanonicalBaseOccupancy(source: request.baseOccupancy.source),
            score: request.score,
            validation: validation,
            expectedInnings: inning.expectedInnings,
            extraInning: extra,
            completedGameEvidence: false,
            rejected: false,
            inputRemainsUnchanged: true
        )
    }

    private static func rejected(_ request: CanonicalInningTransitionRequest, validation: CanonicalValidationResult, expected: ExpectedInningCountEvidence) -> CanonicalInningTransitionResult {
        CanonicalInningTransitionResult(
            inputInning: request.inning,
            resultingInning: request.inning,
            resultingOuts: request.outs,
            resultingBaseOccupancy: request.baseOccupancy,
            score: request.score,
            validation: validation,
            expectedInnings: expected,
            extraInning: false,
            completedGameEvidence: false,
            rejected: true,
            inputRemainsUnchanged: true
        )
    }

    private static func finding(_ code: String, _ severity: CanonicalValidationSeverity, _ disposition: CanonicalValidationDisposition, _ summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: .inning, severity: severity, disposition: disposition, summary: summary)
    }
}
