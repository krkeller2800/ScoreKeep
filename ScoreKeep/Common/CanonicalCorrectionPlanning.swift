import Foundation

enum CanonicalCorrectionOperation: Hashable, Sendable {
    case replaceEvent(CanonicalScoringEventEvidence)
    case removeEvent
    case unsupported(String)
}

struct CanonicalCorrectionIntent: Hashable, Sendable {
    let invocationIdentity: String?
    let targetGameIdentity: ImportedIdentifierEvidence
    let targetEventIdentity: ImportedIdentifierEvidence
    let operation: CanonicalCorrectionOperation
    let expectedOriginalEvent: CanonicalScoringEventEvidence?
    let source: CanonicalScoringCommandSource

    init(
        invocationIdentity: String? = nil,
        targetGameIdentity: ImportedIdentifierEvidence,
        targetEventIdentity: ImportedIdentifierEvidence,
        operation: CanonicalCorrectionOperation,
        expectedOriginalEvent: CanonicalScoringEventEvidence? = nil,
        source: CanonicalScoringCommandSource = .unknown
    ) {
        self.invocationIdentity = invocationIdentity
        self.targetGameIdentity = targetGameIdentity
        self.targetEventIdentity = targetEventIdentity
        self.operation = operation
        self.expectedOriginalEvent = expectedOriginalEvent
        self.source = source
    }
}

struct CanonicalCorrectionFactSet: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let activeEvents: [CanonicalScoringEventEvidence]
    let supersededEvents: [CanonicalScoringEventEvidence]

    init(
        gameIdentity: ImportedIdentifierEvidence,
        activeEvents: [CanonicalScoringEventEvidence],
        supersededEvents: [CanonicalScoringEventEvidence] = []
    ) {
        self.gameIdentity = gameIdentity
        self.activeEvents = activeEvents
        self.supersededEvents = supersededEvents
    }
}

enum CanonicalCorrectionTargetResolution: Hashable, Sendable {
    case uniquelyResolved(event: CanonicalScoringEventEvidence, sourceIndex: Int, replayPosition: Int)
    case missingTarget
    case duplicateTargetIdentity
    case conflictingTargetEvidence
    case staleExpectedOriginal
    case unsupportedTarget
    case ambiguousOrdering
    case wrongGameTarget
    case alreadySupersededTarget

    var target: CanonicalScoringEventEvidence? {
        if case let .uniquelyResolved(event, _, _) = self { return event }
        return nil
    }

    var replayPosition: Int? {
        if case let .uniquelyResolved(_, _, replayPosition) = self { return replayPosition }
        return nil
    }
}

enum CanonicalCorrectionDisposition: String, Hashable, Sendable {
    case accepted
    case planned
    case warningOnly
    case unsupported
    case rejected
    case contradictory
    case unresolved
    case repairRequired

    var mayApply: Bool {
        switch self {
        case .accepted, .planned, .warningOnly:
            return true
        case .unsupported, .rejected, .contradictory, .unresolved, .repairRequired:
            return false
        }
    }
}

enum CanonicalCorrectionChangedFact: String, Hashable, Sendable {
    case eventResult
    case batterIdentity
    case runnerAdvancement
    case runnerOutEvidence
    case outs
    case inning
    case teamSide
    case rbiEvidence
    case earnedRunEvidence
    case sacrificeEvidence
    case stolenBaseEvidence
    case pitcherResponsibility
    case orderingEvidence
    case unsupportedEvidence
    case eventRemoved
    case eventSuperseded
}

struct CanonicalCorrectionPlan: Hashable, Sendable {
    let intent: CanonicalCorrectionIntent
    let resolution: CanonicalCorrectionTargetResolution
    let disposition: CanonicalCorrectionDisposition
    let findings: [CanonicalValidationFinding]
    let earliestReplayPosition: Int?
    let downstreamEventCount: Int
    let requiredValidation: Set<CanonicalCorrectionChangedFact>
    let recalculatesBatterProjection: Bool
    let recalculatesPitcherProjection: Bool
    let recalculatesScoreProjection: Bool
    let recalculatesInningProjection: Bool
    let recalculatesBaseProjection: Bool
    let replayMayContinue: Bool
    let futurePersistenceMustStop: Bool

    var inputRemainsUnchanged: Bool { true }
}

struct CanonicalCorrectionApplicationResult: Hashable, Sendable {
    let originalFactSet: CanonicalCorrectionFactSet
    let updatedFactSet: CanonicalCorrectionFactSet
    let plan: CanonicalCorrectionPlan
    let disposition: CanonicalCorrectionDisposition
    let acceptedCorrectedEvent: CanonicalScoringEventEvidence?
    let supersededOrRemovedEvent: CanonicalScoringEventEvidence?
    let changedFacts: Set<CanonicalCorrectionChangedFact>
    let findings: [CanonicalValidationFinding]
    let earliestReplayPosition: Int?
    let downstreamReplayRequired: Bool
    let idempotencyResult: CanonicalIdempotencyResult?

    var applied: Bool { disposition == .accepted }
    var originalInputRemainsAvailable: Bool { true }
}

struct CanonicalCorrectionProjectedStateSummary: Hashable, Sendable {
    let score: CanonicalProjectedScore
    let battingSide: TeamSideRole
    let inning: CanonicalHalfInning?
    let outs: CanonicalOutsState
    let occupiedBases: Set<Base>
    let appliedEventCount: Int
    let batterProjectionWarnings: [String]
    let pitcherProjectionWarnings: [String]
    let storedScoreComparison: CanonicalStoredScoreComparison
}

enum CanonicalCorrectionRecalculationDisposition: String, Hashable, Sendable {
    case recalculated
    case recalculatedWithWarnings
    case unsafeDownstream
    case rejectedCorrection
}

struct CanonicalCorrectionRecalculationResult: Hashable, Sendable {
    let originalFinalState: CanonicalCorrectionProjectedStateSummary
    let correctedFinalState: CanonicalCorrectionProjectedStateSummary
    let changedProjections: Set<CanonicalCorrectionChangedFact>
    let earliestChangedEventPosition: Int?
    let appliedDownstreamEventCount: Int
    let firstDownstreamFailure: ImportedIdentifierEvidence?
    let disposition: CanonicalCorrectionRecalculationDisposition
    let warningCodes: [String]
}

enum CanonicalIdempotencyIntent: Hashable, Sendable {
    case scoring(CanonicalScoringCommand)
    case correction(CanonicalCorrectionIntent)
}

struct CanonicalIdempotencyRecord: Hashable, Sendable {
    let invocationIdentity: String
    let intent: CanonicalIdempotencyIntent
    let existingFactIdentity: ImportedIdentifierEvidence?
    let wasAccepted: Bool
}

enum CanonicalIdempotencyDisposition: String, Hashable, Sendable {
    case newInvocation
    case exactDuplicateInvocation
    case matchingDuplicateInvocation
    case conflictingDuplicateInvocation
    case semanticRepeatDifferentInvocation
    case repeatedAcceptedCorrection
    case repeatedRejectedCorrection
    case missingInvocationIdentity
    case duplicateCreationRisk
    case unsupported
    case unresolved
}

struct CanonicalIdempotencyResult: Hashable, Sendable {
    let disposition: CanonicalIdempotencyDisposition
    let existingFactIdentity: ImportedIdentifierEvidence?
    let mayReturnExistingResult: Bool
    let mustNotCreateNewFact: Bool
    let futurePersistenceMayContinue: Bool
    let findings: [CanonicalValidationFinding]
}

enum CanonicalCorrectionPlanner {
    static func plan(_ intent: CanonicalCorrectionIntent, in factSet: CanonicalCorrectionFactSet) -> CanonicalCorrectionPlan {
        var findings: [CanonicalValidationFinding] = []
        let resolution = resolve(intent, in: factSet, findings: &findings)
        let changedFacts = requiredValidation(for: intent, target: resolution.target)

        findings += validateOperation(intent, target: resolution.target)
        let validation = CanonicalValidationResult(findings: findings)
        let disposition = disposition(for: validation, resolution: resolution, operation: intent.operation)
        let earliest = resolution.replayPosition
        let downstream = earliest.map { max(0, orderedEvents(factSet.activeEvents).count - $0 - 1) } ?? 0

        return CanonicalCorrectionPlan(
            intent: intent,
            resolution: resolution,
            disposition: disposition,
            findings: validation.findings,
            earliestReplayPosition: earliest,
            downstreamEventCount: downstream,
            requiredValidation: changedFacts,
            recalculatesBatterProjection: changedFacts.intersection([.eventResult, .batterIdentity, .teamSide, .orderingEvidence, .eventRemoved]).isEmpty == false,
            recalculatesPitcherProjection: changedFacts.intersection([.pitcherResponsibility, .earnedRunEvidence, .eventResult, .orderingEvidence, .eventRemoved]).isEmpty == false,
            recalculatesScoreProjection: changedFacts.intersection([.eventResult, .runnerAdvancement, .outs, .rbiEvidence, .eventRemoved]).isEmpty == false,
            recalculatesInningProjection: changedFacts.intersection([.outs, .inning, .orderingEvidence, .eventRemoved]).isEmpty == false,
            recalculatesBaseProjection: changedFacts.intersection([.eventResult, .runnerAdvancement, .runnerOutEvidence, .eventRemoved]).isEmpty == false,
            replayMayContinue: validation.processingMayContinueReadOnly,
            futurePersistenceMustStop: validation.futureWriteMustStop || disposition.mayApply == false
        )
    }

    private static func resolve(
        _ intent: CanonicalCorrectionIntent,
        in factSet: CanonicalCorrectionFactSet,
        findings: inout [CanonicalValidationFinding]
    ) -> CanonicalCorrectionTargetResolution {
        guard intent.targetGameIdentity == factSet.gameIdentity else {
            findings.append(finding("correction.targetWrongGame", .game, .contradiction, .contradictory, "Correction target game identity does not match the supplied fact set."))
            return .wrongGameTarget
        }
        guard intent.targetEventIdentity.validIdentifier != nil else {
            findings.append(finding("correction.targetUnsupportedIdentity", .stableIdentity, .unresolved, .unresolved, "Correction target requires stable event identity."))
            return .unsupportedTarget
        }
        if factSet.supersededEvents.contains(where: { $0.eventIdentity == intent.targetEventIdentity }) {
            findings.append(finding("correction.targetAlreadySuperseded", .scoringEvent, .rejection, .rejected, "Correction target was already superseded or removed."))
            return .alreadySupersededTarget
        }

        let matches = factSet.activeEvents.enumerated().filter { $0.element.eventIdentity == intent.targetEventIdentity }
        guard matches.isEmpty == false else {
            findings.append(finding("correction.targetMissing", .scoringEvent, .unresolved, .unresolved, "Correction target event is not present in the active fact set."))
            return .missingTarget
        }
        guard matches.count == 1, let match = matches.first else {
            findings.append(finding("correction.targetDuplicateIdentity", .stableIdentity, .contradiction, .contradictory, "Correction target identity resolves to multiple active events."))
            return .duplicateTargetIdentity
        }
        guard match.element.gameIdentity == factSet.gameIdentity else {
            findings.append(finding("correction.targetEventWrongGame", .game, .contradiction, .contradictory, "Resolved target event belongs to another game."))
            return .wrongGameTarget
        }
        if let expected = intent.expectedOriginalEvent, expected != match.element {
            findings.append(finding("correction.targetStaleExpectedOriginal", .scoringEvent, .rejection, .rejected, "Expected original event evidence is stale."))
            return .staleExpectedOriginal
        }

        guard let replayPosition = orderedEvents(factSet.activeEvents).firstIndex(where: { $0.event == match.element }) else {
            findings.append(finding("correction.targetAmbiguousOrdering", .ordering, .repair, .repairRequired, "Correction target ordering is not safe enough to identify downstream replay."))
            return .ambiguousOrdering
        }
        if eventSequence(from: match.element.orderingEvidence) == nil && sourceOrder(from: match.element.orderingEvidence) == nil {
            findings.append(finding("correction.targetAmbiguousOrdering", .ordering, .repair, .repairRequired, "Correction target lacks explicit ordering evidence."))
            return .ambiguousOrdering
        }

        return .uniquelyResolved(event: match.element, sourceIndex: match.offset, replayPosition: replayPosition)
    }

    private static func validateOperation(
        _ intent: CanonicalCorrectionIntent,
        target: CanonicalScoringEventEvidence?
    ) -> [CanonicalValidationFinding] {
        guard let target else { return [] }
        switch intent.operation {
        case let .replaceEvent(replacement):
            return validateReplacement(replacement, target: target, intent: intent)
        case .removeEvent:
            return []
        case .unsupported:
            return [finding("correction.operationUnsupported", .scoringEvent, .unsupported, .unsupported, "Correction operation is unsupported by the non-routed foundation.", unsupported: true)]
        }
    }

    private static func validateReplacement(
        _ replacement: CanonicalScoringEventEvidence,
        target: CanonicalScoringEventEvidence,
        intent: CanonicalCorrectionIntent
    ) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        if replacement.gameIdentity != intent.targetGameIdentity {
            findings.append(finding("correction.replacementWrongGame", .game, .contradiction, .contradictory, "Replacement event belongs to the wrong game."))
        }
        if replacement.eventIdentity != target.eventIdentity {
            findings.append(finding("correction.replacementFabricatesIdentity", .stableIdentity, .rejection, .rejected, "Replacement event must preserve the target event identity."))
        }
        if replacement.orderingEvidence != target.orderingEvidence {
            findings.append(finding("correction.replacementUnsafeOrdering", .ordering, .repair, .repairRequired, "Replacement event must preserve ordering evidence in this foundation."))
        }
        if replacement.teamSide != nil, target.teamSide != nil, replacement.teamSide != target.teamSide {
            findings.append(finding("correction.replacementWrongSide", .gameSide, .contradiction, .contradictory, "Replacement event changes batting side, which is not safe in this foundation."))
        }
        if replacement.participants.batter == nil && requiresBatter(replacement.resultEvidence) {
            findings.append(finding("correction.replacementMissingBatter", .player, .rejection, .rejected, "Replacement event is missing required batter evidence."))
        }
        if case .unsupportedRawResult = replacement.resultEvidence {
            findings.append(finding("correction.replacementUnsupportedResult", .scoringEvent, .unsupported, .unsupported, "Replacement result is unsupported.", unsupported: true))
        }
        if case .unknownRawResult = replacement.resultEvidence {
            findings.append(finding("correction.replacementUnknownResult", .scoringEvent, .unresolved, .unresolved, "Replacement result is unknown."))
        }
        if let outs = replacement.outsEvidence?.outsRecordedByEvent, outs < 0 || outs > 3 {
            findings.append(finding("correction.replacementImpossibleOuts", .outs, .rejection, .rejected, "Replacement event records an impossible out count."))
        }
        if hasContradictoryOccupancy(replacement.runnerAdvancement) {
            findings.append(finding("correction.replacementContradictoryOccupancy", .baseOccupancy, .contradiction, .contradictory, "Replacement runner evidence creates contradictory base occupancy."))
        }
        return findings
    }

    private static func requiredValidation(
        for intent: CanonicalCorrectionIntent,
        target: CanonicalScoringEventEvidence?
    ) -> Set<CanonicalCorrectionChangedFact> {
        guard let target else { return [] }
        switch intent.operation {
        case .removeEvent:
            return [.eventRemoved, .eventSuperseded, .eventResult, .outs, .runnerAdvancement]
        case let .replaceEvent(replacement):
            var changed: Set<CanonicalCorrectionChangedFact> = []
            if replacement.resultEvidence != target.resultEvidence { changed.insert(.eventResult) }
            if replacement.participants.batter != target.participants.batter { changed.insert(.batterIdentity) }
            if replacement.runnerAdvancement != target.runnerAdvancement || replacement.batterAdvancement != target.batterAdvancement { changed.insert(.runnerAdvancement) }
            if replacement.outsEvidence != target.outsEvidence { changed.insert(.outs) }
            if replacement.inningContext != target.inningContext { changed.insert(.inning) }
            if replacement.teamSide != target.teamSide { changed.insert(.teamSide) }
            if replacement.rbiEvidence != target.rbiEvidence { changed.insert(.rbiEvidence) }
            if replacement.earnedRunEvidence != target.earnedRunEvidence { changed.insert(.earnedRunEvidence) }
            if replacement.sacrificeEvidence != target.sacrificeEvidence { changed.insert(.sacrificeEvidence) }
            if replacement.stolenBaseEvidence != target.stolenBaseEvidence { changed.insert(.stolenBaseEvidence) }
            if replacement.orderingEvidence != target.orderingEvidence { changed.insert(.orderingEvidence) }
            if replacement.unsupportedRawLegacyEvidence != target.unsupportedRawLegacyEvidence { changed.insert(.unsupportedEvidence) }
            return changed
        case .unsupported:
            return [.unsupportedEvidence]
        }
    }

    private static func disposition(
        for validation: CanonicalValidationResult,
        resolution: CanonicalCorrectionTargetResolution,
        operation: CanonicalCorrectionOperation
    ) -> CanonicalCorrectionDisposition {
        if case .unsupported = operation { return .unsupported }
        switch resolution {
        case .uniquelyResolved:
            break
        case .duplicateTargetIdentity, .conflictingTargetEvidence, .wrongGameTarget:
            return .contradictory
        case .ambiguousOrdering:
            return .repairRequired
        case .missingTarget, .unsupportedTarget:
            return .unresolved
        case .staleExpectedOriginal, .alreadySupersededTarget:
            return .rejected
        }
        switch validation.disposition {
        case .valid:
            return .planned
        case .validWithWarnings, .incomplete, .repairRecommended:
            return .warningOnly
        case .unsupported:
            return .unsupported
        case .rejected:
            return .rejected
        case .contradictory:
            return .contradictory
        case .unresolved:
            return .unresolved
        case .repairRequired:
            return .repairRequired
        }
    }
}

enum CanonicalCorrectionApplicator {
    static func apply(
        _ plan: CanonicalCorrectionPlan,
        to factSet: CanonicalCorrectionFactSet,
        idempotencyResult: CanonicalIdempotencyResult? = nil
    ) -> CanonicalCorrectionApplicationResult {
        guard plan.disposition.mayApply,
              case let .uniquelyResolved(target, sourceIndex, _) = plan.resolution else {
            return rejected(plan: plan, factSet: factSet, idempotencyResult: idempotencyResult)
        }
        if idempotencyResult?.mustNotCreateNewFact == true {
            return rejected(plan: plan, factSet: factSet, idempotencyResult: idempotencyResult)
        }

        var active = factSet.activeEvents
        var superseded = factSet.supersededEvents + [target]
        let corrected: CanonicalScoringEventEvidence?
        let changedFacts: Set<CanonicalCorrectionChangedFact>

        switch plan.intent.operation {
        case let .replaceEvent(replacement):
            active[sourceIndex] = replacement
            corrected = replacement
            changedFacts = plan.requiredValidation.union([.eventSuperseded])
        case .removeEvent:
            active.remove(at: sourceIndex)
            corrected = nil
            changedFacts = plan.requiredValidation.union([.eventRemoved, .eventSuperseded])
        case .unsupported:
            superseded = factSet.supersededEvents
            return rejected(plan: plan, factSet: factSet, idempotencyResult: idempotencyResult)
        }

        let updated = CanonicalCorrectionFactSet(gameIdentity: factSet.gameIdentity, activeEvents: active, supersededEvents: superseded)
        return CanonicalCorrectionApplicationResult(
            originalFactSet: factSet,
            updatedFactSet: updated,
            plan: plan,
            disposition: .accepted,
            acceptedCorrectedEvent: corrected,
            supersededOrRemovedEvent: target,
            changedFacts: changedFacts,
            findings: plan.findings,
            earliestReplayPosition: plan.earliestReplayPosition,
            downstreamReplayRequired: plan.downstreamEventCount > 0 || changedFacts.isEmpty == false,
            idempotencyResult: idempotencyResult
        )
    }

    private static func rejected(
        plan: CanonicalCorrectionPlan,
        factSet: CanonicalCorrectionFactSet,
        idempotencyResult: CanonicalIdempotencyResult?
    ) -> CanonicalCorrectionApplicationResult {
        CanonicalCorrectionApplicationResult(
            originalFactSet: factSet,
            updatedFactSet: factSet,
            plan: plan,
            disposition: plan.disposition,
            acceptedCorrectedEvent: nil,
            supersededOrRemovedEvent: nil,
            changedFacts: [],
            findings: plan.findings,
            earliestReplayPosition: plan.earliestReplayPosition,
            downstreamReplayRequired: false,
            idempotencyResult: idempotencyResult
        )
    }
}

enum CanonicalCorrectionRecalculator {
    static func recalculate(
        replayInput: CanonicalReplayInput,
        application: CanonicalCorrectionApplicationResult
    ) -> CanonicalCorrectionRecalculationResult {
        let originalReplay = CanonicalGameReplay.replay(replayInput)
        guard application.applied else {
            let summary = summarize(originalReplay)
            return CanonicalCorrectionRecalculationResult(
                originalFinalState: summary,
                correctedFinalState: summary,
                changedProjections: [],
                earliestChangedEventPosition: application.earliestReplayPosition,
                appliedDownstreamEventCount: 0,
                firstDownstreamFailure: nil,
                disposition: .rejectedCorrection,
                warningCodes: application.findings.map(\.code)
            )
        }

        let correctedInput = CanonicalReplayInput(
            game: replayInput.game,
            homeTeamIdentity: replayInput.homeTeamIdentity,
            visitingTeamIdentity: replayInput.visitingTeamIdentity,
            initialBattingSide: replayInput.initialBattingSide,
            initialInning: replayInput.initialInning,
            initialOuts: replayInput.initialOuts,
            initialBaseOccupancy: replayInput.initialBaseOccupancy,
            initialScore: replayInput.initialScore,
            lineups: replayInput.lineups,
            initialPitcherResponsibility: replayInput.initialPitcherResponsibility,
            pitchers: replayInput.pitchers,
            recordedEvents: application.updatedFactSet.activeEvents,
            validationFindings: replayInput.validationFindings + application.findings,
            storedScore: replayInput.storedScore,
            startPosition: replayInput.startPosition
        )
        let correctedReplay = CanonicalGameReplay.replay(correctedInput)
        let originalSummary = summarize(originalReplay)
        let correctedSummary = summarize(correctedReplay)
        let changed = changedProjections(original: originalSummary, corrected: correctedSummary)
        let downstreamCount = application.earliestReplayPosition.map { max(0, correctedInput.recordedEvents.count - $0) } ?? 0
        let unsafe = correctedReplay.futureRoutingOrPersistenceMustStop || correctedReplay.disposition == .partial

        return CanonicalCorrectionRecalculationResult(
            originalFinalState: originalSummary,
            correctedFinalState: correctedSummary,
            changedProjections: changed,
            earliestChangedEventPosition: application.earliestReplayPosition,
            appliedDownstreamEventCount: downstreamCount,
            firstDownstreamFailure: correctedReplay.firstProblematicEventIdentity,
            disposition: unsafe ? .unsafeDownstream : (correctedReplay.validationFindings.isEmpty ? .recalculated : .recalculatedWithWarnings),
            warningCodes: (application.findings + correctedReplay.validationFindings).map(\.code).sorted()
        )
    }

    private static func summarize(_ replay: CanonicalReplayResult) -> CanonicalCorrectionProjectedStateSummary {
        CanonicalCorrectionProjectedStateSummary(
            score: replay.finalState.score,
            battingSide: replay.finalState.battingSide,
            inning: replay.finalState.inning,
            outs: replay.finalState.outs,
            occupiedBases: CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(replay.finalState.baseOccupancy),
            appliedEventCount: replay.appliedEventCount,
            batterProjectionWarnings: replay.finalState.projectedBatters.flatMap(\.warningCodes).sorted(),
            pitcherProjectionWarnings: replay.finalState.projectedPitchers.flatMap(\.warningCodes).sorted(),
            storedScoreComparison: replay.storedScoreComparison
        )
    }

    private static func changedProjections(
        original: CanonicalCorrectionProjectedStateSummary,
        corrected: CanonicalCorrectionProjectedStateSummary
    ) -> Set<CanonicalCorrectionChangedFact> {
        var changed: Set<CanonicalCorrectionChangedFact> = []
        if original.score != corrected.score { changed.insert(.eventResult) }
        if original.outs != corrected.outs { changed.insert(.outs) }
        if original.occupiedBases != corrected.occupiedBases { changed.insert(.runnerAdvancement) }
        if original.inning != corrected.inning || original.battingSide != corrected.battingSide { changed.insert(.inning) }
        if original.batterProjectionWarnings != corrected.batterProjectionWarnings { changed.insert(.batterIdentity) }
        if original.pitcherProjectionWarnings != corrected.pitcherProjectionWarnings { changed.insert(.pitcherResponsibility) }
        return changed
    }
}

enum CanonicalIdempotencyAuthority {
    static func classify(
        invocationIdentity: String?,
        intent: CanonicalIdempotencyIntent,
        priorRecords: [CanonicalIdempotencyRecord]
    ) -> CanonicalIdempotencyResult {
        guard let invocationIdentity, invocationIdentity.isEmpty == false else {
            return result(.missingInvocationIdentity, existing: nil, mayReturnExisting: false, mustNotCreate: false, mayPersist: false, code: "idempotency.invocationMissing")
        }
        let sameInvocation = priorRecords.filter { $0.invocationIdentity == invocationIdentity }
        if let exact = sameInvocation.first(where: { $0.intent == intent }) {
            let disposition: CanonicalIdempotencyDisposition
            switch intent {
            case .scoring:
                disposition = .exactDuplicateInvocation
            case .correction:
                disposition = exact.wasAccepted ? .repeatedAcceptedCorrection : .repeatedRejectedCorrection
            }
            return CanonicalIdempotencyResult(
                disposition: disposition,
                existingFactIdentity: exact.existingFactIdentity,
                mayReturnExistingResult: exact.wasAccepted,
                mustNotCreateNewFact: true,
                futurePersistenceMayContinue: exact.wasAccepted,
                findings: [finding("idempotency.exactDuplicate", .scoringEvent, .warning, .validWithWarnings, "Invocation exactly repeats a known intent.")]
            )
        }
        if sameInvocation.isEmpty == false {
            return result(.conflictingDuplicateInvocation, existing: sameInvocation.first?.existingFactIdentity, mayReturnExisting: false, mustNotCreate: true, mayPersist: false, code: "idempotency.conflictingReuse")
        }
        if let semantic = priorRecords.first(where: { $0.intent == intent }) {
            return CanonicalIdempotencyResult(
                disposition: .semanticRepeatDifferentInvocation,
                existingFactIdentity: semantic.existingFactIdentity,
                mayReturnExistingResult: semantic.wasAccepted,
                mustNotCreateNewFact: true,
                futurePersistenceMayContinue: semantic.wasAccepted,
                findings: [finding("idempotency.semanticRepeat", .scoringEvent, .warning, .validWithWarnings, "Intent semantically repeats a prior invocation with different identity.")]
            )
        }
        return result(.newInvocation, existing: nil, mayReturnExisting: false, mustNotCreate: false, mayPersist: true, code: "idempotency.newInvocation")
    }

    private static func result(
        _ disposition: CanonicalIdempotencyDisposition,
        existing: ImportedIdentifierEvidence?,
        mayReturnExisting: Bool,
        mustNotCreate: Bool,
        mayPersist: Bool,
        code: String
    ) -> CanonicalIdempotencyResult {
        CanonicalIdempotencyResult(
            disposition: disposition,
            existingFactIdentity: existing,
            mayReturnExistingResult: mayReturnExisting,
            mustNotCreateNewFact: mustNotCreate,
            futurePersistenceMayContinue: mayPersist,
            findings: [finding(code, .scoringEvent, mayPersist ? .information : .rejection, mayPersist ? .valid : .rejected, "Idempotency classification completed.")]
        )
    }
}

private func orderedEvents(_ events: [CanonicalScoringEventEvidence]) -> [(event: CanonicalScoringEventEvidence, originalIndex: Int)] {
    events.enumerated().sorted { lhs, rhs in
        let lhsSequence = eventSequence(from: lhs.element.orderingEvidence)
        let rhsSequence = eventSequence(from: rhs.element.orderingEvidence)
        if lhsSequence != rhsSequence { return (lhsSequence ?? Int.max) < (rhsSequence ?? Int.max) }
        let lhsSource = sourceOrder(from: lhs.element.orderingEvidence)
        let rhsSource = sourceOrder(from: rhs.element.orderingEvidence)
        if lhsSource != rhsSource { return (lhsSource ?? lhs.offset) < (rhsSource ?? rhs.offset) }
        return lhs.offset < rhs.offset
    }.map { ($0.element, $0.offset) }
}

private func eventSequence(from evidence: [ScoringEventOrderingEvidence]) -> Int? {
    evidence.compactMap { item in
        if case let .knownSequence(order) = item { return order.value }
        return nil
    }.first
}

private func sourceOrder(from evidence: [ScoringEventOrderingEvidence]) -> Int? {
    evidence.compactMap { item in
        switch item {
        case let .sourceFileOrder(order), let .stableTieEvidence(order):
            return order.sourceIndex ?? order.value
        default:
            return nil
        }
    }.first
}

private func requiresBatter(_ result: ScoringEventResultEvidence) -> Bool {
    switch result {
    case .batterReachesBase, .batterOut:
        return true
    case .runnerAdvances, .runnerScores, .runnerOut, .placeholder, .unknownRawResult, .unsupportedRawResult, .conflicting:
        return false
    }
}

private func hasContradictoryOccupancy(_ advancement: [RunnerStateEvidence]) -> Bool {
    var bases: Set<Base> = []
    for state in advancement {
        if case let .activeOccupant(base, _) = state {
            if bases.contains(base) { return true }
            bases.insert(base)
        }
    }
    return false
}

private func finding(
    _ code: String,
    _ concept: CanonicalValidationConcept,
    _ severity: CanonicalValidationSeverity,
    _ disposition: CanonicalValidationDisposition,
    _ summary: String,
    unsupported: Bool = false
) -> CanonicalValidationFinding {
    CanonicalDomainValidator.finding(code, concept: concept, severity: severity, disposition: disposition, summary: summary, sourceLocation: "CanonicalCorrection", unsupported: unsupported)
}
