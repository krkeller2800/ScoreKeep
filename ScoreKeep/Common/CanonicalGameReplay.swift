import Foundation

struct CanonicalReplayStartPosition: Hashable, Sendable {
    let nextEventSequence: Int?
    let appliedEventCount: Int

    init(nextEventSequence: Int? = nil, appliedEventCount: Int = 0) {
        self.nextEventSequence = nextEventSequence
        self.appliedEventCount = appliedEventCount
    }
}

struct CanonicalReplayLineupInput: Hashable, Sendable {
    let side: TeamSideRole
    let lineup: CanonicalBattingOrderEvidence
    let substitutions: [CanonicalSubstitutionEvidence]

    init(side: TeamSideRole, lineup: CanonicalBattingOrderEvidence, substitutions: [CanonicalSubstitutionEvidence] = []) {
        self.side = side
        self.lineup = lineup
        self.substitutions = substitutions
    }
}

struct CanonicalReplayPitcherInput: Hashable, Sendable {
    let defensiveSide: TeamSideRole
    let appearances: [CanonicalPitcherAppearanceEvidence]
    let pitcherChanges: [CanonicalPitcherChangeEvidence]
    let eventResponsibilities: [CanonicalPitcherResponsibilityEvidence]

    init(
        defensiveSide: TeamSideRole,
        appearances: [CanonicalPitcherAppearanceEvidence],
        pitcherChanges: [CanonicalPitcherChangeEvidence] = [],
        eventResponsibilities: [CanonicalPitcherResponsibilityEvidence] = []
    ) {
        self.defensiveSide = defensiveSide
        self.appearances = appearances
        self.pitcherChanges = pitcherChanges
        self.eventResponsibilities = eventResponsibilities
    }
}

struct CanonicalReplayInput: Hashable, Sendable {
    let game: CanonicalGameIdentity
    let homeTeamIdentity: ImportedIdentifierEvidence
    let visitingTeamIdentity: ImportedIdentifierEvidence
    let initialBattingSide: TeamSideRole
    let initialInning: CanonicalHalfInning?
    let initialOuts: CanonicalOutsState
    let initialBaseOccupancy: CanonicalBaseOccupancy
    let initialScore: CanonicalProjectedScore
    let lineups: [CanonicalReplayLineupInput]
    let initialPitcherResponsibility: CanonicalPitcherResponsibilityEvidence?
    let pitchers: [CanonicalReplayPitcherInput]
    let recordedEvents: [CanonicalScoringEventEvidence]
    let validationFindings: [CanonicalValidationFinding]
    let storedScore: CanonicalProjectedScore?
    let startPosition: CanonicalReplayStartPosition

    init(
        game: CanonicalGameIdentity,
        homeTeamIdentity: ImportedIdentifierEvidence,
        visitingTeamIdentity: ImportedIdentifierEvidence,
        initialBattingSide: TeamSideRole,
        initialInning: CanonicalHalfInning?,
        initialOuts: CanonicalOutsState,
        initialBaseOccupancy: CanonicalBaseOccupancy = CanonicalBaseOccupancy(),
        initialScore: CanonicalProjectedScore = CanonicalProjectedScore(),
        lineups: [CanonicalReplayLineupInput] = [],
        initialPitcherResponsibility: CanonicalPitcherResponsibilityEvidence? = nil,
        pitchers: [CanonicalReplayPitcherInput] = [],
        recordedEvents: [CanonicalScoringEventEvidence] = [],
        validationFindings: [CanonicalValidationFinding] = [],
        storedScore: CanonicalProjectedScore? = nil,
        startPosition: CanonicalReplayStartPosition = CanonicalReplayStartPosition()
    ) {
        self.game = game
        self.homeTeamIdentity = homeTeamIdentity
        self.visitingTeamIdentity = visitingTeamIdentity
        self.initialBattingSide = initialBattingSide
        self.initialInning = initialInning
        self.initialOuts = initialOuts
        self.initialBaseOccupancy = initialBaseOccupancy
        self.initialScore = initialScore
        self.lineups = lineups
        self.initialPitcherResponsibility = initialPitcherResponsibility
        self.pitchers = pitchers
        self.recordedEvents = recordedEvents
        self.validationFindings = validationFindings
        self.storedScore = storedScore
        self.startPosition = startPosition
    }
}

enum CanonicalReplayDisposition: String, Hashable, Sendable {
    case complete
    case completeWithWarnings
    case partial
    case incomplete
    case unsupported
    case rejected
    case contradictory
    case unresolved

    var readOnlyComparisonMayContinue: Bool {
        switch self {
        case .complete, .completeWithWarnings, .partial, .incomplete, .unsupported, .unresolved:
            return true
        case .rejected, .contradictory:
            return false
        }
    }

    var futureRoutingOrPersistenceMustStop: Bool {
        switch self {
        case .complete, .completeWithWarnings:
            return false
        case .partial, .incomplete, .unsupported, .rejected, .contradictory, .unresolved:
            return true
        }
    }
}

enum CanonicalReplayEventOrderingDisposition: String, Hashable, Sendable {
    case explicitValidOrder
    case explicitSourceOrder
    case missingSequence
    case duplicateSequence
    case conflictingSequenceAndScorecardColumn
    case unsafeUnresolvedOrder
}

enum CanonicalStoredScoreComparison: Hashable, Sendable {
    case notSupplied
    case matchesStoredScore
    case differsFromStoredScore(projected: CanonicalProjectedScore, stored: CanonicalProjectedScore)
    case storedScoreUnsupported
    case replayCannotEstablishScoreSafely
    case reviewRequired
}

struct CanonicalReplayProjectedBatterSummary: Hashable, Sendable {
    let side: TeamSideRole
    let disposition: CanonicalProjectionDisposition
    let currentPlayerIdentity: ImportedIdentifierEvidence?
    let currentSlot: Int?
    let nextPlayerIdentity: ImportedIdentifierEvidence?
    let nextSlot: Int?
    let warningCodes: [String]
}

struct CanonicalReplayProjectedPitcherSummary: Hashable, Sendable {
    let defensiveSide: TeamSideRole
    let disposition: CanonicalProjectionDisposition
    let activePitcherIdentity: ImportedIdentifierEvidence?
    let activeAppearanceOrder: Int?
    let warningCodes: [String]
}

struct CanonicalReplayProjectedState: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let battingSide: TeamSideRole
    let inning: CanonicalHalfInning?
    let outs: CanonicalOutsState
    let baseOccupancy: CanonicalBaseOccupancy
    let score: CanonicalProjectedScore
    let appliedEventCount: Int
    let nextEventSequence: Int?
    let projectedBatters: [CanonicalReplayProjectedBatterSummary]
    let projectedPitchers: [CanonicalReplayProjectedPitcherSummary]
}

struct CanonicalReplayEventSummary: Hashable, Sendable {
    let eventIdentity: ImportedIdentifierEvidence
    let sourceSequence: Int?
    let sourceIndex: Int?
    let orderingDisposition: CanonicalReplayEventOrderingDisposition
    let outcomeDisposition: CanonicalReplayDisposition
    let applied: Bool
    let changedFacts: Set<CanonicalScoringEventApplicationFact>
    let diagnosticCodes: [String]
    let resultingInning: CanonicalHalfInning?
    let resultingOuts: Int?
    let resultingOccupiedBases: Set<Base>
    let resultingScore: CanonicalProjectedScore
    let batterIdentity: ImportedIdentifierEvidence?
    let pitcherIdentity: ImportedIdentifierEvidence?
    let unsupportedRawClassification: [String]
}

struct CanonicalReplayResult: Hashable, Sendable {
    let finalState: CanonicalReplayProjectedState
    let eventSummaries: [CanonicalReplayEventSummary]
    let appliedEventCount: Int
    let unappliedEventCount: Int
    let firstProblematicEventIdentity: ImportedIdentifierEvidence?
    let firstProblematicEventIndex: Int?
    let disposition: CanonicalReplayDisposition
    let validationFindings: [CanonicalValidationFinding]
    let storedScoreComparison: CanonicalStoredScoreComparison
    let readOnlyComparisonMayContinue: Bool
    let futureRoutingOrPersistenceMustStop: Bool
}

enum CanonicalGameReplay {
    static func replay(_ input: CanonicalReplayInput) -> CanonicalReplayResult {
        let initialFindings = input.validationFindings + validateInitialInput(input)
        if initialFindings.contains(where: { $0.futureWriteMustStop }) {
            let disposition = disposition(for: CanonicalValidationResult(findings: initialFindings), appliedAny: false, stopped: true)
            let finalState = projectedState(from: commandState(from: input), input: input, appliedEvents: [], appliedCount: input.startPosition.appliedEventCount, nextSequence: input.startPosition.nextEventSequence)
            return result(finalState: finalState, summaries: [], input: input, findings: initialFindings, disposition: disposition, firstProblemIdentity: nil, firstProblemIndex: nil)
        }

        let ordering = order(input.recordedEvents, startPosition: input.startPosition)
        if ordering.validation.futureWriteMustStop || ordering.disposition != .explicitValidOrder && ordering.disposition != .explicitSourceOrder {
            let finalState = projectedState(from: commandState(from: input), input: input, appliedEvents: [], appliedCount: input.startPosition.appliedEventCount, nextSequence: input.startPosition.nextEventSequence)
            let first = ordering.problemIndex.flatMap { input.recordedEvents.indices.contains($0) ? input.recordedEvents[$0] : nil }
            let disposition = disposition(for: ordering.validation, appliedAny: false, stopped: true)
            return result(finalState: finalState, summaries: [], input: input, findings: initialFindings + ordering.validation.findings, disposition: disposition, firstProblemIdentity: first?.eventIdentity, firstProblemIndex: ordering.problemIndex)
        }

        var current = commandState(from: input)
        var summaries: [CanonicalReplayEventSummary] = []
        var findings = initialFindings + ordering.validation.findings
        var appliedEvents: [CanonicalScoringEventEvidence] = []
        var appliedCount = input.startPosition.appliedEventCount
        var nextSequence = input.startPosition.nextEventSequence
        var stoppedDisposition: CanonicalReplayDisposition?
        var firstProblemIdentity: ImportedIdentifierEvidence?
        var firstProblemIndex: Int?

        for ordered in ordering.events {
            let adaptation = command(for: ordered.event, current: current)
            guard let command = adaptation.command else {
                findings += adaptation.findings
                let eventDisposition = disposition(for: CanonicalValidationResult(findings: adaptation.findings), appliedAny: false, stopped: true)
                summaries.append(summary(
                    for: ordered,
                    orderingDisposition: ordering.disposition,
                    outcomeDisposition: eventDisposition,
                    applied: false,
                    changedFacts: [],
                    diagnosticCodes: adaptation.findings.map(\.code),
                    state: current,
                    batterIdentity: ordered.event.participants.batter?.playerIdentity,
                    pitcherIdentity: pitcherIdentity(from: ordered.event),
                    unsupportedRaw: ordered.event.unsupportedRawLegacyEvidence
                ))
                stoppedDisposition = appliedCount > input.startPosition.appliedEventCount ? .partial : eventDisposition
                firstProblemIdentity = ordered.event.eventIdentity
                firstProblemIndex = ordered.originalIndex
                break
            }

            let application = CanonicalScoringEventApplicator.applyComposed(command, to: current, sourceLocation: "CanonicalGameReplay")
            let applicationFindings = applicationFindings(from: application)
            findings += applicationFindings

            if application.rejected || application.event == nil {
                let eventDisposition = disposition(for: CanonicalValidationResult(findings: applicationFindings), appliedAny: false, stopped: true)
                summaries.append(summary(
                    for: ordered,
                    orderingDisposition: ordering.disposition,
                    outcomeDisposition: eventDisposition,
                    applied: false,
                    changedFacts: [],
                    diagnosticCodes: applicationFindings.map(\.code),
                    state: current,
                    batterIdentity: ordered.event.participants.batter?.playerIdentity,
                    pitcherIdentity: pitcherIdentity(from: ordered.event),
                    unsupportedRaw: application.baseApplication.preservedUnsupportedEvidence
                ))
                stoppedDisposition = appliedCount > input.startPosition.appliedEventCount ? .partial : eventDisposition
                firstProblemIdentity = ordered.event.eventIdentity
                firstProblemIndex = ordered.originalIndex
                break
            }

            current = application.resultingState
            appliedCount += 1
            appliedEvents.append(application.event ?? ordered.event)
            nextSequence = ordered.sequence.map { $0 + 1 }
            summaries.append(summary(
                for: ordered,
                orderingDisposition: ordering.disposition,
                outcomeDisposition: applicationFindings.isEmpty ? .complete : .completeWithWarnings,
                applied: true,
                changedFacts: application.baseApplication.changedFacts
                    .union(application.baseRunnerTransition?.changedFacts ?? [])
                    .union(application.outTransition?.rejected == false ? [.outs] : []),
                diagnosticCodes: applicationFindings.map(\.code),
                state: current,
                batterIdentity: ordered.event.participants.batter?.playerIdentity,
                pitcherIdentity: pitcherIdentity(from: ordered.event),
                unsupportedRaw: ordered.event.unsupportedRawLegacyEvidence
            ))
        }

        let finalState = projectedState(from: current, input: input, appliedEvents: appliedEvents, appliedCount: appliedCount, nextSequence: nextSequence)
        let finalDisposition = stoppedDisposition ?? finalDisposition(findings: findings, summaries: summaries)
        return result(finalState: finalState, summaries: summaries, input: input, findings: findings, disposition: finalDisposition, firstProblemIdentity: firstProblemIdentity, firstProblemIndex: firstProblemIndex)
    }

    private struct OrderedEvent: Hashable, Sendable {
        let event: CanonicalScoringEventEvidence
        let originalIndex: Int
        let sequence: Int?
        let sourceIndex: Int?
    }

    private struct OrderingResult: Hashable, Sendable {
        let disposition: CanonicalReplayEventOrderingDisposition
        let events: [OrderedEvent]
        let validation: CanonicalValidationResult
        let problemIndex: Int?
    }

    private struct CommandAdaptation: Hashable, Sendable {
        let command: CanonicalScoringCommand?
        let findings: [CanonicalValidationFinding]
    }

    private static func commandState(from input: CanonicalReplayInput) -> CanonicalScoringCommandInputState {
        CanonicalScoringCommandInputState(
            game: input.game,
            battingSide: input.initialBattingSide,
            inning: input.initialInning,
            outs: input.initialOuts,
            baseOccupancy: input.initialBaseOccupancy,
            count: .unsupportedRepositoryEvidence,
            score: input.initialScore,
            currentBatter: nil,
            lineupParticipants: lineupParticipants(for: input.initialBattingSide, in: input.lineups),
            pitcherResponsibility: input.initialPitcherResponsibility
        )
    }

    private static func validateInitialInput(_ input: CanonicalReplayInput) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        findings += CanonicalDomainValidator.validateGame(input.game, sourceLocation: "CanonicalGameReplay.initial.game").findings
        if let inning = input.initialInning {
            findings += CanonicalDomainValidator.validateInning(inning, sourceLocation: "CanonicalGameReplay.initial.inning").findings
        } else {
            findings.append(finding("replay.initialInningMissing", concept: .inning, severity: .incomplete, disposition: .incomplete, summary: "Replay requires explicit initial inning evidence."))
        }
        findings += CanonicalDomainValidator.validateOuts(input.initialOuts, sourceLocation: "CanonicalGameReplay.initial.outs").findings
        findings += CanonicalDomainValidator.validateBaseOccupancy(input.initialBaseOccupancy, sourceLocation: "CanonicalGameReplay.initial.baseOccupancy").findings
        if input.initialScore.home < 0 || input.initialScore.visiting < 0 {
            findings.append(finding("replay.initialScoreNegative", concept: .scoringEvent, severity: .rejection, disposition: .rejected, summary: "Replay requires nonnegative initial score evidence."))
        }
        if input.initialBattingSide == .unresolved {
            findings.append(finding("replay.initialBattingSideUnresolved", concept: .gameSide, severity: .unresolved, disposition: .unresolved, summary: "Replay requires explicit initial batting side evidence."))
        }
        if input.startPosition.appliedEventCount < 0 {
            findings.append(finding("replay.invalidStartAppliedCount", concept: .scoringEvent, severity: .rejection, disposition: .rejected, summary: "Replay start applied-event count cannot be negative."))
        }
        return findings
    }

    private static func order(_ events: [CanonicalScoringEventEvidence], startPosition: CanonicalReplayStartPosition) -> OrderingResult {
        guard events.isEmpty == false else {
            return OrderingResult(disposition: .explicitValidOrder, events: [], validation: .valid, problemIndex: nil)
        }

        var ordered: [OrderedEvent] = []
        var findings: [CanonicalValidationFinding] = []
        var seenSequences: [Int: Int] = [:]
        var seenSourceIndexes: [Int: Int] = [:]
        var hasKnownSequence = false
        var hasMissingSequence = false
        var hasConflict = false
        var hasUnresolved = false
        var hasDuplicate = false

        for (index, event) in events.enumerated() {
            let sequence = eventSequence(from: event.orderingEvidence)
            let sourceIndex = sourceOrder(from: event.orderingEvidence)
            ordered.append(OrderedEvent(event: event, originalIndex: index, sequence: sequence, sourceIndex: sourceIndex))

            for evidence in event.orderingEvidence {
                switch evidence {
                case .knownSequence:
                    hasKnownSequence = true
                case .missingSequence:
                    hasMissingSequence = true
                case .duplicateSequence:
                    hasDuplicate = true
                case .conflictingSequenceAndScorecardColumn:
                    hasConflict = true
                case .sourceFileOrder, .stableTieEvidence:
                    break
                case .unresolved:
                    hasUnresolved = true
                }
            }
            if event.orderingEvidence.isEmpty { hasMissingSequence = true }

            if let sequence {
                seenSequences[sequence, default: 0] += 1
                if let next = startPosition.nextEventSequence, sequence < next {
                    findings.append(finding("replay.repeatedAlreadyAppliedEvent", concept: .ordering, severity: .rejection, disposition: .rejected, summary: "Replay suffix repeats an event before the requested start position."))
                }
            }
            if let sourceIndex {
                seenSourceIndexes[sourceIndex, default: 0] += 1
            }
        }

        if let expected = startPosition.nextEventSequence, let first = ordered.compactMap(\.sequence).min(), first != expected {
            findings.append(finding("replay.wrongNextEventPosition", concept: .ordering, severity: .rejection, disposition: .rejected, summary: "Replay suffix does not begin at the requested next event position."))
        }

        if hasConflict {
            findings.append(finding("replay.orderConflictingSequenceAndScorecardColumn", concept: .ordering, severity: .contradiction, disposition: .contradictory, summary: "Recorded event order has conflicting sequence and scorecard-column evidence."))
            return OrderingResult(disposition: .conflictingSequenceAndScorecardColumn, events: ordered, validation: CanonicalValidationResult(findings: findings), problemIndex: ordered.firstIndex { event in event.event.orderingEvidence.contains { if case .conflictingSequenceAndScorecardColumn = $0 { return true }; return false } })
        }
        if hasUnresolved {
            findings.append(finding("replay.orderUnresolved", concept: .ordering, severity: .unresolved, disposition: .unresolved, summary: "Recorded event order is unresolved."))
            return OrderingResult(disposition: .unsafeUnresolvedOrder, events: ordered, validation: CanonicalValidationResult(findings: findings), problemIndex: ordered.firstIndex { event in event.event.orderingEvidence.contains(.unresolved) })
        }
        if hasDuplicate || seenSequences.values.contains(where: { $0 > 1 }) {
            findings.append(finding("replay.orderDuplicateSequence", concept: .ordering, severity: .repair, disposition: .repairRequired, summary: "Recorded event order contains duplicate sequence evidence."))
            return OrderingResult(disposition: .duplicateSequence, events: ordered, validation: CanonicalValidationResult(findings: findings), problemIndex: duplicateProblemIndex(ordered))
        }

        if hasKnownSequence && hasMissingSequence == false && ordered.allSatisfy({ $0.sequence != nil }) {
            return OrderingResult(disposition: .explicitValidOrder, events: ordered.sorted(by: orderedBefore), validation: CanonicalValidationResult(findings: findings), problemIndex: nil)
        }

        if hasKnownSequence == false && ordered.allSatisfy({ $0.sourceIndex != nil }) && seenSourceIndexes.values.allSatisfy({ $0 == 1 }) {
            findings.append(finding("replay.orderUsesExplicitSourceOrder", concept: .ordering, severity: .warning, disposition: .validWithWarnings, summary: "Replay uses explicit source-order evidence because event sequence is missing."))
            return OrderingResult(disposition: .explicitSourceOrder, events: ordered.sorted(by: orderedBefore), validation: CanonicalValidationResult(findings: findings), problemIndex: nil)
        }

        findings.append(finding("replay.orderMissingSequence", concept: .ordering, severity: .incomplete, disposition: .incomplete, summary: "Recorded event sequence evidence is missing."))
        return OrderingResult(disposition: .missingSequence, events: ordered, validation: CanonicalValidationResult(findings: findings), problemIndex: ordered.firstIndex { $0.sequence == nil })
    }

    private static func command(for event: CanonicalScoringEventEvidence, current: CanonicalScoringCommandInputState) -> CommandAdaptation {
        var findings: [CanonicalValidationFinding] = []
        guard event.gameIdentity == current.game.identity else {
            return CommandAdaptation(command: nil, findings: [finding("replay.eventGameMismatch", concept: .game, severity: .contradiction, disposition: .contradictory, summary: "Recorded event game identity conflicts with replay state.")])
        }
        guard let teamSide = event.teamSide else {
            return CommandAdaptation(command: nil, findings: [finding("replay.eventTeamSideMissing", concept: .gameSide, severity: .unresolved, disposition: .unresolved, summary: "Recorded event is missing batting-side evidence.")])
        }

        let runnerDestinations = destinations(from: event.runnerAdvancement, current: current, findings: &findings)
        if findings.contains(where: { $0.futureWriteMustStop }) {
            return CommandAdaptation(command: nil, findings: findings)
        }

        let intent: CanonicalScoringCommandIntent
        var rawLegacy = event.unsupportedRawLegacyEvidence
        switch event.resultEvidence {
        case let .batterReachesBase(rawValue):
            let disposition = CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: rawValue)
            if case let .supported(supported) = disposition {
                intent = supported
            } else {
                intent = .unsupportedLegacy(disposition)
                rawLegacy.append(rawValue)
            }
        case let .batterOut(rawValue):
            let disposition = CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: rawValue)
            if case let .supported(supported) = disposition {
                intent = supported
            } else {
                intent = .unsupportedLegacy(disposition)
                rawLegacy.append(rawValue)
            }
        case .runnerAdvances:
            guard let first = runnerDestinations.first else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerAdvanceMissingDestination", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner-advance event has no supported destination evidence.")])
            }
            if case let .advance(runner, from, to, stolenBase) = first {
                intent = .runnerAdvances(runner: runner, from: from, to: to, stolenBase: stolenBase)
            } else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerAdvanceContradictoryDestination", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "Runner-advance event has contradictory destination evidence.")])
            }
        case .runnerScores:
            guard let first = runnerDestinations.first else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerScoreMissingDestination", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner-score event has no supported destination evidence.")])
            }
            if case let .score(runner, from, rbi) = first {
                intent = .runnerScores(runner: runner, from: from, rbi: rbi)
            } else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerScoreContradictoryDestination", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "Runner-score event has contradictory destination evidence.")])
            }
        case .runnerOut:
            guard let first = runnerDestinations.first else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerOutMissingDestination", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner-out event has no supported destination evidence.")])
            }
            if case let .out(runner, from, outAt) = first {
                intent = .runnerOut(runner: runner, from: from, outAt: outAt)
            } else {
                return CommandAdaptation(command: nil, findings: [finding("replay.runnerOutContradictoryDestination", concept: .baseOccupancy, severity: .contradiction, disposition: .contradictory, summary: "Runner-out event has contradictory destination evidence.")])
            }
        case let .unknownRawResult(rawValue), let .placeholder(rawValue):
            intent = .unsupportedLegacy(.unknownRaw(rawValue: rawValue))
            rawLegacy.append(rawValue)
        case let .unsupportedRawResult(rawValue):
            intent = .unsupportedLegacy(.unsupported(rawValue: rawValue))
        case let .conflicting(values):
            let rawValues = Set(values.map { String(describing: $0) })
            intent = .unsupportedLegacy(.contradictory(rawValues: rawValues))
            rawLegacy += rawValues.sorted()
        }

        return CommandAdaptation(command: CanonicalScoringCommand(
            intent: intent,
            gameIdentity: event.gameIdentity,
            teamSide: teamSide,
            batter: event.participants.batter,
            runnerDestinations: runnerDestinations,
            rbiEvidence: event.rbiEvidence,
            sacrificeEvidence: event.sacrificeEvidence,
            stolenBaseEvidence: event.stolenBaseEvidence,
            earnedRunEvidence: event.earnedRunEvidence,
            pitcherResponsibility: pitcherResponsibility(from: event),
            proposedEventIdentity: event.eventIdentity,
            orderingEvidence: event.orderingEvidence,
            rawLegacyEvidence: rawLegacy,
            source: .compatibilityLegacyResult
        ), findings: findings)
    }

    private static func destinations(from evidence: [RunnerStateEvidence], current: CanonicalScoringCommandInputState, findings: inout [CanonicalValidationFinding]) -> [CanonicalRunnerDestinationIntent] {
        evidence.compactMap { state in
            switch state {
            case let .activeOccupant(base, runner):
                guard let from = activeBase(for: runner, in: current.baseOccupancy) else {
                    findings.append(finding("replay.runnerAdvanceSourceMissing", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner advancement lacks resolvable source-base evidence."))
                    return nil
                }
                return .advance(runner: runner, from: from, to: base)
            case let .scored(runner, sourceBase):
                guard let from = sourceBase ?? activeBase(for: runner, in: current.baseOccupancy) else {
                    findings.append(finding("replay.runnerScoreSourceMissing", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner score lacks resolvable source-base evidence."))
                    return nil
                }
                return .score(runner: runner, from: from, rbi: false)
            case let .out(runner, sourceBase):
                guard let from = sourceBase ?? activeBase(for: runner, in: current.baseOccupancy) else {
                    findings.append(finding("replay.runnerOutSourceMissing", concept: .baseOccupancy, severity: .unresolved, disposition: .unresolved, summary: "Runner out lacks resolvable source-base evidence."))
                    return nil
                }
                return .out(runner: runner, from: from, outAt: from)
            case .batterRunner, .historicalRunner, .ambiguousLegacyMaxBase, .ambiguousLegacyOutAt, .unsupportedLegacyValue, .contradictory:
                findings.append(finding("replay.unsupportedRunnerStateEvidence", concept: .baseOccupancy, severity: .unsupported, disposition: .unsupported, summary: "Runner state evidence is preserved but unsupported by lean replay.", unsupported: true))
                return nil
            }
        }
    }

    private static func projectedState(
        from state: CanonicalScoringCommandInputState,
        input: CanonicalReplayInput,
        appliedEvents: [CanonicalScoringEventEvidence],
        appliedCount: Int,
        nextSequence: Int?
    ) -> CanonicalReplayProjectedState {
        CanonicalReplayProjectedState(
            gameIdentity: state.game.identity,
            battingSide: state.battingSide,
            inning: state.inning,
            outs: state.outs,
            baseOccupancy: state.baseOccupancy,
            score: state.score,
            appliedEventCount: appliedCount,
            nextEventSequence: nextSequence,
            projectedBatters: input.lineups.map { lineup in
                let projection = CanonicalBatterProjector.project(CanonicalBatterProjectionInput(
                    gameIdentity: input.game.identity,
                    battingSide: lineup.side,
                    lineup: lineup.lineup,
                    recordedEvents: appliedEvents,
                    substitutions: lineup.substitutions,
                    validationFindings: input.validationFindings,
                    sourceLocation: "CanonicalGameReplay.finalBatterProjection"
                ))
                return CanonicalReplayProjectedBatterSummary(
                    side: lineup.side,
                    disposition: projection.disposition,
                    currentPlayerIdentity: projection.currentBatter?.participant.playerIdentity,
                    currentSlot: projection.currentSlot,
                    nextPlayerIdentity: projection.nextBatter?.participant.playerIdentity,
                    nextSlot: projection.nextSlot,
                    warningCodes: projection.validation.findings.map(\.code)
                )
            },
            projectedPitchers: input.pitchers.map { pitcher in
                let projection = CanonicalPitcherProjector.project(CanonicalPitcherProjectionInput(
                    gameIdentity: input.game.identity,
                    defensiveSide: pitcher.defensiveSide,
                    appearances: pitcher.appearances,
                    pitcherChanges: pitcher.pitcherChanges,
                    eventResponsibilities: pitcher.eventResponsibilities,
                    validationFindings: input.validationFindings,
                    sourceLocation: "CanonicalGameReplay.finalPitcherProjection"
                ))
                return CanonicalReplayProjectedPitcherSummary(
                    defensiveSide: pitcher.defensiveSide,
                    disposition: projection.disposition,
                    activePitcherIdentity: projection.activePitcher?.appearance.reusablePitcherIdentity,
                    activeAppearanceOrder: projection.activePitcher?.appearanceOrder,
                    warningCodes: projection.validation.findings.map(\.code)
                )
            }
        )
    }

    private static func result(
        finalState: CanonicalReplayProjectedState,
        summaries: [CanonicalReplayEventSummary],
        input: CanonicalReplayInput,
        findings: [CanonicalValidationFinding],
        disposition: CanonicalReplayDisposition,
        firstProblemIdentity: ImportedIdentifierEvidence?,
        firstProblemIndex: Int?
    ) -> CanonicalReplayResult {
        let unapplied = max(0, input.recordedEvents.count - summaries.filter(\.applied).count)
        let comparison = storedScoreComparison(stored: input.storedScore, finalState: finalState, disposition: disposition)
        return CanonicalReplayResult(
            finalState: finalState,
            eventSummaries: summaries,
            appliedEventCount: summaries.filter(\.applied).count + input.startPosition.appliedEventCount,
            unappliedEventCount: unapplied,
            firstProblematicEventIdentity: firstProblemIdentity,
            firstProblematicEventIndex: firstProblemIndex,
            disposition: disposition,
            validationFindings: findings,
            storedScoreComparison: comparison,
            readOnlyComparisonMayContinue: disposition.readOnlyComparisonMayContinue,
            futureRoutingOrPersistenceMustStop: disposition.futureRoutingOrPersistenceMustStop
        )
    }

    private static func summary(
        for ordered: OrderedEvent,
        orderingDisposition: CanonicalReplayEventOrderingDisposition,
        outcomeDisposition: CanonicalReplayDisposition,
        applied: Bool,
        changedFacts: Set<CanonicalScoringEventApplicationFact>,
        diagnosticCodes: [String],
        state: CanonicalScoringCommandInputState,
        batterIdentity: ImportedIdentifierEvidence?,
        pitcherIdentity: ImportedIdentifierEvidence?,
        unsupportedRaw: [String]
    ) -> CanonicalReplayEventSummary {
        CanonicalReplayEventSummary(
            eventIdentity: ordered.event.eventIdentity,
            sourceSequence: ordered.sequence,
            sourceIndex: ordered.sourceIndex,
            orderingDisposition: orderingDisposition,
            outcomeDisposition: outcomeDisposition,
            applied: applied,
            changedFacts: changedFacts,
            diagnosticCodes: diagnosticCodes.sorted(),
            resultingInning: state.inning,
            resultingOuts: state.outs.outs.outValue,
            resultingOccupiedBases: CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(state.baseOccupancy),
            resultingScore: state.score,
            batterIdentity: batterIdentity,
            pitcherIdentity: pitcherIdentity,
            unsupportedRawClassification: unsupportedRaw.sorted()
        )
    }

    private static func applicationFindings(from application: CanonicalScoringStateTransitionApplicationResult) -> [CanonicalValidationFinding] {
        var findings = application.baseApplication.validation.result.findings
        findings += application.baseRunnerTransition?.validation.findings ?? []
        findings += application.outTransition?.validation.findings ?? []
        findings += application.scoreCalculation?.validation.findings ?? []
        findings += application.inningTransition?.validation.findings ?? []
        return CanonicalValidationResult(findings: findings).findings
    }

    private static func storedScoreComparison(stored: CanonicalProjectedScore?, finalState: CanonicalReplayProjectedState, disposition: CanonicalReplayDisposition) -> CanonicalStoredScoreComparison {
        guard let stored else { return .notSupplied }
        if stored.home < 0 || stored.visiting < 0 { return .storedScoreUnsupported }
        if disposition.futureRoutingOrPersistenceMustStop { return .replayCannotEstablishScoreSafely }
        return stored == finalState.score ? .matchesStoredScore : .differsFromStoredScore(projected: finalState.score, stored: stored)
    }

    private static func finalDisposition(findings: [CanonicalValidationFinding], summaries: [CanonicalReplayEventSummary]) -> CanonicalReplayDisposition {
        if summaries.contains(where: { $0.outcomeDisposition == .completeWithWarnings }) { return .completeWithWarnings }
        let validation = CanonicalValidationResult(findings: findings)
        if validation.findings.isEmpty { return .complete }
        return disposition(for: validation, appliedAny: summaries.contains(where: \.applied), stopped: false)
    }

    private static func disposition(for validation: CanonicalValidationResult, appliedAny: Bool, stopped: Bool) -> CanonicalReplayDisposition {
        switch validation.disposition {
        case .valid:
            return stopped && appliedAny ? .partial : .complete
        case .validWithWarnings, .repairRecommended:
            return stopped && appliedAny ? .partial : .completeWithWarnings
        case .incomplete:
            return stopped && appliedAny ? .partial : .incomplete
        case .unsupported:
            return stopped && appliedAny ? .partial : .unsupported
        case .rejected:
            return stopped && appliedAny ? .partial : .rejected
        case .contradictory, .repairRequired:
            return stopped && appliedAny ? .partial : .contradictory
        case .unresolved:
            return stopped && appliedAny ? .partial : .unresolved
        }
    }

    private static func eventSequence(from evidence: [ScoringEventOrderingEvidence]) -> Int? {
        for item in evidence {
            if case let .knownSequence(order) = item { return order.value }
        }
        return nil
    }

    private static func sourceOrder(from evidence: [ScoringEventOrderingEvidence]) -> Int? {
        for item in evidence {
            switch item {
            case let .sourceFileOrder(order), let .stableTieEvidence(order):
                return order.sourceIndex ?? order.value
            default:
                continue
            }
        }
        return nil
    }

    private static func orderedBefore(_ lhs: OrderedEvent, _ rhs: OrderedEvent) -> Bool {
        switch (lhs.sequence, rhs.sequence) {
        case let (lhs?, rhs?) where lhs != rhs:
            return lhs < rhs
        default:
            switch (lhs.sourceIndex, rhs.sourceIndex) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            default:
                return lhs.originalIndex < rhs.originalIndex
            }
        }
    }

    private static func duplicateProblemIndex(_ events: [OrderedEvent]) -> Int? {
        var seen: Set<Int> = []
        for event in events {
            if let sequence = event.sequence {
                if seen.contains(sequence) { return event.originalIndex }
                seen.insert(sequence)
            }
        }
        return nil
    }

    private static func activeBase(for runner: RunnerIdentityEvidence, in occupancy: CanonicalBaseOccupancy) -> Base? {
        for state in occupancy.runnerStates {
            if case let .activeOccupant(base, activeRunner) = state, activeRunner == runner {
                return base
            }
        }
        return nil
    }

    private static func lineupParticipants(for side: TeamSideRole, in lineups: [CanonicalReplayLineupInput]) -> [LineupParticipantEvidence] {
        lineups.first(where: { $0.side == side })?.lineup.entries.map(\.participant) ?? []
    }

    private static func pitcherResponsibility(from event: CanonicalScoringEventEvidence) -> CanonicalPitcherResponsibilityEvidence? {
        event.unsupportedRawLegacyEvidence.isEmpty
            ? nil
            : CanonicalPitcherResponsibilityEvidence(eventIdentity: event.eventIdentity, gameIdentity: event.gameIdentity, teamSide: nil, responsibility: .unresolved, source: .compatibilityTransport)
    }

    private static func pitcherIdentity(from event: CanonicalScoringEventEvidence) -> ImportedIdentifierEvidence? {
        if case let .explicitPitcher(appearance) = pitcherResponsibility(from: event)?.responsibility {
            return appearance.reusablePitcherIdentity
        }
        return nil
    }

    private static func finding(
        _ code: String,
        concept: CanonicalValidationConcept,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String,
        unsupported: Bool = false
    ) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: concept, severity: severity, disposition: disposition, summary: summary, sourceLocation: "CanonicalGameReplay", unsupported: unsupported)
    }
}
