import Foundation

/// Non-routed Phase 2 command vocabulary for scoring intent.
/// Commands describe requested scorer intent before any `Atbat`, SwiftData write, score update, or UI mutation.
enum CanonicalScoringCommandSource: String, Hashable, Sendable {
    case scoringView
    case compatibilityLegacyResult
    case syntheticVerification
    case unknown
}

indirect enum CanonicalScoringCommandLegacyDisposition: Hashable, Sendable {
    case supported(CanonicalScoringCommandIntent)
    case recognizedUnsupported(rawValue: String)
    case unknownRaw(rawValue: String)
    case unsupported(rawValue: String)
    case ambiguous(rawValue: String, candidates: Set<CanonicalScoringCommandIntent>)
    case contradictory(rawValues: Set<String>)

    var rawValue: String? {
        switch self {
        case .supported:
            return nil
        case let .recognizedUnsupported(rawValue),
             let .unknownRaw(rawValue),
             let .unsupported(rawValue),
             let .ambiguous(rawValue, _):
            return rawValue
        case let .contradictory(rawValues):
            return rawValues.sorted().joined(separator: "|")
        }
    }
}

indirect enum CanonicalScoringCommandIntent: Hashable, Sendable {
    case batterReaches(destination: Base, result: ScoringEventResultEvidence)
    case homeRun
    case batterOut(result: ScoringEventResultEvidence)
    case runnerAdvances(runner: RunnerIdentityEvidence, from: Base, to: Base, stolenBase: Bool)
    case runnerScores(runner: RunnerIdentityEvidence, from: Base, rbi: Bool)
    case runnerOut(runner: RunnerIdentityEvidence, from: Base, outAt: Base)
    case multipleOuts(Int)
    case endHalfInning
    case unsupportedLegacy(CanonicalScoringCommandLegacyDisposition)
}

struct CanonicalScoringCommand: Hashable, Sendable {
    let intent: CanonicalScoringCommandIntent
    let gameIdentity: ImportedIdentifierEvidence
    let teamSide: TeamSideRole
    let batter: LineupParticipantEvidence?
    let runnerDestinations: [CanonicalRunnerDestinationIntent]
    let outsRequested: Int
    let rbiEvidence: ScoringEventMarkerEvidence
    let sacrificeEvidence: ScoringEventMarkerEvidence
    let stolenBaseEvidence: ScoringEventMarkerEvidence
    let earnedRunEvidence: ScoringEventMarkerEvidence
    let pitcherResponsibility: CanonicalPitcherResponsibilityEvidence?
    let proposedEventIdentity: ImportedIdentifierEvidence
    let orderingEvidence: [ScoringEventOrderingEvidence]
    let rawLegacyEvidence: [String]
    let source: CanonicalScoringCommandSource

    init(
        intent: CanonicalScoringCommandIntent,
        gameIdentity: ImportedIdentifierEvidence,
        teamSide: TeamSideRole,
        batter: LineupParticipantEvidence? = nil,
        runnerDestinations: [CanonicalRunnerDestinationIntent] = [],
        outsRequested: Int = 0,
        rbiEvidence: ScoringEventMarkerEvidence = .notRepresented,
        sacrificeEvidence: ScoringEventMarkerEvidence = .notRepresented,
        stolenBaseEvidence: ScoringEventMarkerEvidence = .notRepresented,
        earnedRunEvidence: ScoringEventMarkerEvidence = .notRepresented,
        pitcherResponsibility: CanonicalPitcherResponsibilityEvidence? = nil,
        proposedEventIdentity: ImportedIdentifierEvidence = .missing,
        orderingEvidence: [ScoringEventOrderingEvidence] = [],
        rawLegacyEvidence: [String] = [],
        source: CanonicalScoringCommandSource = .unknown
    ) {
        self.intent = intent
        self.gameIdentity = gameIdentity
        self.teamSide = teamSide
        self.batter = batter
        self.runnerDestinations = runnerDestinations
        self.outsRequested = outsRequested
        self.rbiEvidence = rbiEvidence
        self.sacrificeEvidence = sacrificeEvidence
        self.stolenBaseEvidence = stolenBaseEvidence
        self.earnedRunEvidence = earnedRunEvidence
        self.pitcherResponsibility = pitcherResponsibility
        self.proposedEventIdentity = proposedEventIdentity
        self.orderingEvidence = orderingEvidence
        self.rawLegacyEvidence = rawLegacyEvidence
        self.source = source
    }
}

enum CanonicalRunnerDestinationIntent: Hashable, Sendable {
    case advance(runner: RunnerIdentityEvidence, from: Base, to: Base, stolenBase: Bool = false)
    case score(runner: RunnerIdentityEvidence, from: Base, rbi: Bool = false)
    case out(runner: RunnerIdentityEvidence, from: Base, outAt: Base)
}

enum CanonicalScoringCommandVocabulary {
    static let supportedReachResults: Set<String> = [
        "Single", "Double", "Triple", "Walk", "Hit By Pitch", "Dropped 3rd Strike", "Catcher Interference", "Fielder's Choice", "Error"
    ]

    static let supportedOutResults: Set<String> = [
        "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout", "Strikeout Looking", "Sacrifice Fly", "Sacrifice Bunt"
    ]

    static func legacyResultDisposition(rawValue: String) -> CanonicalScoringCommandLegacyDisposition {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "Single":
            return .supported(.batterReaches(destination: .first, result: .batterReachesBase(rawValue: trimmed)))
        case "Double":
            return .supported(.batterReaches(destination: .second, result: .batterReachesBase(rawValue: trimmed)))
        case "Triple":
            return .supported(.batterReaches(destination: .third, result: .batterReachesBase(rawValue: trimmed)))
        case "Home Run":
            return .supported(.homeRun)
        case "Walk", "Hit By Pitch", "Dropped 3rd Strike", "Catcher Interference", "Fielder's Choice", "Error":
            return .supported(.batterReaches(destination: .first, result: .batterReachesBase(rawValue: trimmed)))
        case "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout", "Strikeout Looking", "Sacrifice Fly", "Sacrifice Bunt":
            return .supported(.batterOut(result: .batterOut(rawValue: trimmed)))
        case "Sacrifise Fly", "Sacrifise Bunt":
            return .recognizedUnsupported(rawValue: trimmed)
        case "", "Result", "??":
            return .unknownRaw(rawValue: trimmed)
        default:
            return .unsupported(rawValue: trimmed)
        }
    }

    static func command(
        rawResult: String,
        gameIdentity: ImportedIdentifierEvidence,
        teamSide: TeamSideRole,
        batter: LineupParticipantEvidence?,
        proposedEventIdentity: ImportedIdentifierEvidence = .missing,
        source: CanonicalScoringCommandSource = .compatibilityLegacyResult
    ) -> CanonicalScoringCommand {
        let disposition = legacyResultDisposition(rawValue: rawResult)
        let intent: CanonicalScoringCommandIntent
        switch disposition {
        case let .supported(supportedIntent):
            intent = supportedIntent
        default:
            intent = .unsupportedLegacy(disposition)
        }
        return CanonicalScoringCommand(
            intent: intent,
            gameIdentity: gameIdentity,
            teamSide: teamSide,
            batter: batter,
            proposedEventIdentity: proposedEventIdentity,
            rawLegacyEvidence: [rawResult],
            source: source
        )
    }
}
