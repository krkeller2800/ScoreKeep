import Foundation

struct CanonicalScoringCommandInputState: Hashable, Sendable {
    let game: CanonicalGameIdentity
    let battingSide: TeamSideRole
    let inning: CanonicalHalfInning?
    let outs: CanonicalOutsState
    let baseOccupancy: CanonicalBaseOccupancy
    let count: BallStrikeCountEvidence
    let score: CanonicalProjectedScore
    let currentBatter: LineupParticipantEvidence?
    let lineupParticipants: [LineupParticipantEvidence]
    let pitcherResponsibility: CanonicalPitcherResponsibilityEvidence?

    init(
        game: CanonicalGameIdentity,
        battingSide: TeamSideRole,
        inning: CanonicalHalfInning?,
        outs: CanonicalOutsState,
        baseOccupancy: CanonicalBaseOccupancy = CanonicalBaseOccupancy(),
        count: BallStrikeCountEvidence = .unsupportedRepositoryEvidence,
        score: CanonicalProjectedScore = CanonicalProjectedScore(),
        currentBatter: LineupParticipantEvidence? = nil,
        lineupParticipants: [LineupParticipantEvidence] = [],
        pitcherResponsibility: CanonicalPitcherResponsibilityEvidence? = nil
    ) {
        self.game = game
        self.battingSide = battingSide
        self.inning = inning
        self.outs = outs
        self.baseOccupancy = baseOccupancy
        self.count = count
        self.score = score
        self.currentBatter = currentBatter
        self.lineupParticipants = lineupParticipants
        self.pitcherResponsibility = pitcherResponsibility
    }
}

struct CanonicalScoringCommandValidation: Hashable, Sendable {
    let result: CanonicalValidationResult
    let command: CanonicalScoringCommand
    let inputState: CanonicalScoringCommandInputState

    var mayApplyInMemory: Bool {
        switch result.disposition {
        case .valid, .validWithWarnings:
            return true
        default:
            return false
        }
    }

    var futurePersistenceWriteMustStop: Bool {
        result.futureWriteMustStop
    }

    var preservesUnsupportedLegacyEvidence: Bool {
        result.containsUnsupportedEvidence || command.rawLegacyEvidence.isEmpty == false
    }

    var requiresExplicitReviewOrRepair: Bool {
        result.explicitRepairRequired || result.disposition == .unsupported || result.disposition == .unresolved
    }

    var inputStateRemainsUnchanged: Bool { true }
}

enum CanonicalScoringCommandValidator {
    static func validate(
        _ command: CanonicalScoringCommand,
        against input: CanonicalScoringCommandInputState,
        sourceLocation: String? = nil
    ) -> CanonicalScoringCommandValidation {
        var findings: [CanonicalValidationFinding] = []
        findings += validateGame(command, input: input, sourceLocation: sourceLocation)
        findings += validateInning(input.inning, sourceLocation: sourceLocation)
        findings += validateOuts(command, input: input, sourceLocation: sourceLocation)
        findings += CanonicalDomainValidator.validateBaseOccupancy(input.baseOccupancy, sourceLocation: sourceLocation).findings
        findings += validateBatter(command, input: input, sourceLocation: sourceLocation)
        findings += validateIntent(command, input: input, sourceLocation: sourceLocation)
        findings += validateRunnerDestinations(command.runnerDestinations, input: input, sourceLocation: sourceLocation)
        findings += validatePitcher(command, input: input, sourceLocation: sourceLocation)

        return CanonicalScoringCommandValidation(
            result: CanonicalValidationResult(findings: findings),
            command: command,
            inputState: input
        )
    }

    private static func validateGame(
        _ command: CanonicalScoringCommand,
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        var findings = CanonicalDomainValidator.validateGame(input.game, sourceLocation: sourceLocation).findings
        if command.gameIdentity != input.game.identity {
            findings.append(finding("scoringCommand.gameIdentityMismatch", severity: .contradiction, disposition: .contradictory, summary: "Scoring command game identity conflicts with the input state game identity.", sourceLocation: sourceLocation))
        }
        switch input.game.lifecycle {
        case .draft, .completed, .interrupted, .incomplete, .unknown, .unresolved, .conflicting:
            findings.append(finding("scoringCommand.gameNotScorable", severity: .rejection, disposition: .rejected, summary: "Game lifecycle evidence is not accepted for safe scoring continuation.", sourceLocation: sourceLocation))
        case .ready, .inProgress, .imported:
            break
        }
        if command.teamSide != input.battingSide {
            findings.append(finding("scoringCommand.teamSideMismatch", severity: .contradiction, disposition: .contradictory, summary: "Command batting side conflicts with the input state batting side.", sourceLocation: sourceLocation))
        }
        return findings
    }

    private static func validateInning(_ inning: CanonicalHalfInning?, sourceLocation: String?) -> [CanonicalValidationFinding] {
        guard let inning else {
            return [finding("scoringCommand.inningMissing", concept: .inning, severity: .incomplete, disposition: .incomplete, summary: "Scoring command validation requires inning and half-inning evidence.", sourceLocation: sourceLocation)]
        }
        return CanonicalDomainValidator.validateInning(inning, sourceLocation: sourceLocation).findings
    }

    private static func validateOuts(
        _ command: CanonicalScoringCommand,
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        var findings = CanonicalDomainValidator.validateOuts(input.outs, sourceLocation: sourceLocation).findings
        if input.outs.outs.outValue == 3 {
            findings.append(finding("scoringCommand.thirdOutContext", concept: .outs, severity: .rejection, disposition: .rejected, summary: "A new scoring command cannot apply after an existing third-out context in this foundation.", sourceLocation: sourceLocation))
        }
        if let currentOuts = input.outs.outs.outValue, currentOuts + requestedOuts(command) > 3 {
            findings.append(finding("scoringCommand.fourthOutRequest", concept: .outs, severity: .rejection, disposition: .rejected, summary: "The command requests a fourth-or-greater out state.", sourceLocation: sourceLocation))
        }
        return findings
    }

    private static func validateBatter(
        _ command: CanonicalScoringCommand,
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        guard requiresBatter(command.intent) else { return [] }
        guard let batter = command.batter ?? input.currentBatter else {
            return [finding("scoringCommand.batterMissing", severity: .incomplete, disposition: .incomplete, summary: "Scoring command requires batter participant evidence.", sourceLocation: sourceLocation)]
        }
        if case .invalid = batter.playerIdentity {
            return [finding("scoringCommand.batterInvalid", severity: .rejection, disposition: .rejected, summary: "Scoring command batter identity is invalid.", sourceLocation: sourceLocation)]
        }
        if let side = batter.sideRole, side != command.teamSide {
            return [finding("scoringCommand.batterWrongSide", severity: .contradiction, disposition: .contradictory, summary: "Scoring command batter is on the wrong team side.", sourceLocation: sourceLocation)]
        }
        if input.lineupParticipants.isEmpty == false && input.lineupParticipants.contains(where: { $0.playerIdentity == batter.playerIdentity }) == false {
            return [finding("scoringCommand.batterNotInLineup", severity: .rejection, disposition: .rejected, summary: "Scoring command batter is not represented in the supplied lineup evidence.", sourceLocation: sourceLocation)]
        }
        return []
    }

    private static func validateIntent(
        _ command: CanonicalScoringCommand,
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        switch command.intent {
        case let .unsupportedLegacy(disposition):
            switch disposition {
            case .recognizedUnsupported, .unsupported:
                return [finding("scoringCommand.unsupportedLegacyResult", severity: .unsupported, disposition: .unsupported, summary: "Legacy scoring result is preserved but unsupported by accepted command vocabulary.", sourceLocation: sourceLocation, unsupported: true)]
            case .unknownRaw:
                return [finding("scoringCommand.unknownLegacyResult", severity: .unresolved, disposition: .unresolved, summary: "Legacy scoring result is unknown and cannot become an accepted command.", sourceLocation: sourceLocation)]
            case .ambiguous:
                return [finding("scoringCommand.ambiguousLegacyResult", severity: .unresolved, disposition: .unresolved, summary: "Legacy scoring result is ambiguous and requires review.", sourceLocation: sourceLocation)]
            case .contradictory:
                return [finding("scoringCommand.contradictoryLegacyResult", severity: .contradiction, disposition: .contradictory, summary: "Legacy scoring result evidence is contradictory.", sourceLocation: sourceLocation)]
            case .supported:
                return []
            }
        case let .batterReaches(destination, _):
            if destination == .home {
                return [finding("scoringCommand.contradictoryBatterDestination", severity: .contradiction, disposition: .contradictory, summary: "Batter reaches command cannot also use home as a base destination; use home run evidence.", sourceLocation: sourceLocation)]
            }
        case let .multipleOuts(value):
            if value < 0 || value > 3 {
                return [finding("scoringCommand.invalidMultipleOuts", concept: .outs, severity: .rejection, disposition: .rejected, summary: "Multiple-out request is outside the repository-supported range.", sourceLocation: sourceLocation)]
            }
        default:
            break
        }
        return []
    }

    private static func validateRunnerDestinations(
        _ destinations: [CanonicalRunnerDestinationIntent],
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        var referenced: Set<ImportedIdentifierEvidence> = []
        let active = activeOccupants(input.baseOccupancy)
        let activeByBase = Dictionary(uniqueKeysWithValues: active.map { ($0.base, $0.runner) })
        var requestedDestinationBases: Set<Base> = []

        for destination in destinations {
            let runner = destination.runner
            let sourceBase = destination.sourceBase
            guard activeByBase[sourceBase] == runner else {
                findings.append(finding("scoringCommand.runnerMissingFromBase", concept: .baseOccupancy, severity: .rejection, disposition: .rejected, summary: "Command references a runner absent from the stated source base.", sourceLocation: sourceLocation))
                continue
            }
            if runner.identity.validIdentifier != nil && referenced.contains(runner.identity) {
                findings.append(finding("scoringCommand.runnerDuplicateReference", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "The same runner is referenced more than once by incompatible command evidence.", sourceLocation: sourceLocation))
            }
            referenced.insert(runner.identity)

            if let destinationBase = destination.destinationBase {
                if destinationBase.rawValue <= sourceBase.rawValue {
                    findings.append(finding("scoringCommand.runnerImpossibleDestination", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "Runner destination does not advance from the stated source base.", sourceLocation: sourceLocation))
                }
                if requestedDestinationBases.contains(destinationBase) {
                    findings.append(finding("scoringCommand.destinationDuplicate", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "Multiple command outcomes target the same destination base.", sourceLocation: sourceLocation))
                }
                requestedDestinationBases.insert(destinationBase)
                if let occupyingRunner = activeByBase[destinationBase], occupyingRunner != runner {
                    findings.append(finding("scoringCommand.destinationOccupied", concept: .baseOccupancy, severity: .rejection, disposition: .rejected, summary: "Destination base is already occupied without supported displacement evidence.", sourceLocation: sourceLocation))
                }
            }
        }
        return findings
    }

    private static func validatePitcher(
        _ command: CanonicalScoringCommand,
        input: CanonicalScoringCommandInputState,
        sourceLocation: String?
    ) -> [CanonicalValidationFinding] {
        guard requiresBatter(command.intent) else { return [] }
        guard let responsibility = command.pitcherResponsibility ?? input.pitcherResponsibility else {
            return [finding("scoringCommand.pitcherMissing", concept: .pitcherResponsibility, severity: .warning, disposition: .validWithWarnings, summary: "Pitcher responsibility evidence is missing; scoring can continue with warning for this non-routed foundation.", sourceLocation: sourceLocation)]
        }
        return CanonicalDomainValidator.validatePitcherResponsibility(responsibility, sourceLocation: sourceLocation).findings.filter { finding in
            finding.disposition != .incomplete && finding.disposition != .validWithWarnings
        }
    }

    private static func requestedOuts(_ command: CanonicalScoringCommand) -> Int {
        var outs = command.outsRequested
        switch command.intent {
        case .batterOut, .runnerOut:
            outs += 1
        case let .multipleOuts(value):
            outs += value
        case .endHalfInning:
            outs = max(outs, 3)
        default:
            break
        }
        outs += command.runnerDestinations.filter { if case .out = $0 { return true }; return false }.count
        return outs
    }

    private static func requiresBatter(_ intent: CanonicalScoringCommandIntent) -> Bool {
        switch intent {
        case .runnerAdvances, .runnerScores, .runnerOut, .multipleOuts, .endHalfInning, .unsupportedLegacy:
            return false
        case .batterReaches, .homeRun, .batterOut:
            return true
        }
    }

    private static func activeOccupants(_ occupancy: CanonicalBaseOccupancy) -> [(base: Base, runner: RunnerIdentityEvidence)] {
        occupancy.runnerStates.compactMap { state in
            if case let .activeOccupant(base, runner) = state { return (base, runner) }
            return nil
        }
    }

    private static func finding(
        _ code: String,
        concept: CanonicalValidationConcept = .scoringEvent,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String,
        sourceLocation: String?,
        unsupported: Bool = false
    ) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: concept, severity: severity, disposition: disposition, summary: summary, sourceLocation: sourceLocation, unsupported: unsupported)
    }
}

extension CanonicalRunnerDestinationIntent {
    var runner: RunnerIdentityEvidence {
        switch self {
        case let .advance(runner, _, _, _), let .score(runner, _, _), let .out(runner, _, _):
            return runner
        }
    }

    var sourceBase: Base {
        switch self {
        case let .advance(_, sourceBase, _, _), let .score(_, sourceBase, _), let .out(_, sourceBase, _):
            return sourceBase
        }
    }

    var destinationBase: Base? {
        switch self {
        case let .advance(_, _, destinationBase, _):
            return destinationBase
        case .score, .out:
            return nil
        }
    }
}
