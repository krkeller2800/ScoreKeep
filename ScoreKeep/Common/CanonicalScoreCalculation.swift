import Foundation

struct CanonicalProjectedScore: Hashable, Sendable {
    let home: Int
    let visiting: Int

    init(home: Int = 0, visiting: Int = 0) {
        self.home = home
        self.visiting = visiting
    }
}

enum CanonicalRunValidity: Hashable, Sendable {
    case counts
    case invalidated
    case reviewRequired
    case unresolved
}

struct CanonicalScoreCalculationRequest: Hashable, Sendable {
    let inputScore: CanonicalProjectedScore
    let battingSide: TeamSideRole
    let scoredRunners: [RunnerIdentityEvidence]
    let rbiEvidence: ScoringEventMarkerEvidence
    let earnedRunEvidence: ScoringEventMarkerEvidence
    let thirdOutContext: Bool
    let storedScoreEvidence: CanonicalProjectedScore?

    init(inputScore: CanonicalProjectedScore, battingSide: TeamSideRole, scoredRunners: [RunnerIdentityEvidence], rbiEvidence: ScoringEventMarkerEvidence = .notRepresented, earnedRunEvidence: ScoringEventMarkerEvidence = .notRepresented, thirdOutContext: Bool = false, storedScoreEvidence: CanonicalProjectedScore? = nil) {
        self.inputScore = inputScore
        self.battingSide = battingSide
        self.scoredRunners = scoredRunners
        self.rbiEvidence = rbiEvidence
        self.earnedRunEvidence = earnedRunEvidence
        self.thirdOutContext = thirdOutContext
        self.storedScoreEvidence = storedScoreEvidence
    }
}

struct CanonicalScoreCalculationResult: Hashable, Sendable {
    let inputScore: CanonicalProjectedScore
    let resultingScore: CanonicalProjectedScore
    let scoreChange: CanonicalProjectedScore
    let scoredRunners: [RunnerIdentityEvidence]
    let rbiEvidence: ScoringEventMarkerEvidence
    let earnedRunEvidence: ScoringEventMarkerEvidence
    let runValidity: CanonicalRunValidity
    let storedScoreMatchesProjection: Bool?
    let validation: CanonicalValidationResult
    let rejected: Bool
    let inputRemainsUnchanged: Bool
}

enum CanonicalScoreCalculation {
    static func calculate(_ request: CanonicalScoreCalculationRequest) -> CanonicalScoreCalculationResult {
        var findings: [CanonicalValidationFinding] = []
        if request.inputScore.home < 0 || request.inputScore.visiting < 0 {
            findings.append(finding("scoreCalculation.negativeInputScore", .rejection, .rejected, "Input score cannot be negative."))
        }
        if request.battingSide == .unresolved {
            findings.append(finding("scoreCalculation.missingTeamSide", .unresolved, .unresolved, "Batting team side is unresolved; score cannot be changed."))
        }

        let uniqueRunners = unique(request.scoredRunners)
        if uniqueRunners.count != request.scoredRunners.count {
            findings.append(finding("scoreCalculation.duplicateScoredRunner", .warning, .validWithWarnings, "Duplicate scored-runner evidence was counted once."))
        }
        if request.thirdOutContext && uniqueRunners.isEmpty == false {
            findings.append(finding("scoreCalculation.thirdOutRunReview", .warning, .validWithWarnings, "Third-out context requires run-validity review."))
        }

        let validation = CanonicalValidationResult(findings: findings)
        let rejected = validation.futureWriteMustStop
        let runCount = rejected ? 0 : uniqueRunners.count
        let change: CanonicalProjectedScore
        let resulting: CanonicalProjectedScore

        switch request.battingSide {
        case .home where rejected == false:
            change = CanonicalProjectedScore(home: runCount, visiting: 0)
            resulting = CanonicalProjectedScore(home: request.inputScore.home + runCount, visiting: request.inputScore.visiting)
        case .visiting where rejected == false:
            change = CanonicalProjectedScore(home: 0, visiting: runCount)
            resulting = CanonicalProjectedScore(home: request.inputScore.home, visiting: request.inputScore.visiting + runCount)
        default:
            change = CanonicalProjectedScore()
            resulting = request.inputScore
        }

        return CanonicalScoreCalculationResult(
            inputScore: request.inputScore,
            resultingScore: resulting,
            scoreChange: change,
            scoredRunners: rejected ? [] : uniqueRunners,
            rbiEvidence: request.rbiEvidence,
            earnedRunEvidence: request.earnedRunEvidence,
            runValidity: rejected ? .unresolved : (request.thirdOutContext && uniqueRunners.isEmpty == false ? .reviewRequired : .counts),
            storedScoreMatchesProjection: request.storedScoreEvidence.map { $0 == resulting },
            validation: validation,
            rejected: rejected,
            inputRemainsUnchanged: true
        )
    }

    private static func unique(_ runners: [RunnerIdentityEvidence]) -> [RunnerIdentityEvidence] {
        var seen: Set<ImportedIdentifierEvidence> = []
        var output: [RunnerIdentityEvidence] = []
        for runner in runners where seen.contains(runner.identity) == false {
            seen.insert(runner.identity)
            output.append(runner)
        }
        return output
    }

    private static func finding(_ code: String, _ severity: CanonicalValidationSeverity, _ disposition: CanonicalValidationDisposition, _ summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: .scoringEvent, severity: severity, disposition: disposition, summary: summary)
    }
}
