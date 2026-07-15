import Foundation

enum CanonicalProjectionDisposition: String, Hashable, Sendable {
    case resolved
    case resolvedWithWarnings
    case incomplete
    case ambiguous
    case unsupported
    case contradictory
    case unresolved
    case rejected

    var replayMayContinue: Bool {
        switch self {
        case .resolved, .resolvedWithWarnings, .incomplete, .unsupported, .unresolved:
            return true
        case .ambiguous, .contradictory, .rejected:
            return false
        }
    }

    var futureProductionMustStop: Bool {
        switch self {
        case .resolved, .resolvedWithWarnings:
            return false
        case .incomplete, .ambiguous, .unsupported, .contradictory, .unresolved, .rejected:
            return true
        }
    }
}

struct CanonicalProjectionDiagnostic: Hashable, Sendable {
    let code: String
    let disposition: CanonicalProjectionDisposition
    let finding: CanonicalValidationFinding

    init(
        _ code: String,
        disposition: CanonicalProjectionDisposition,
        concept: CanonicalValidationConcept,
        severity: CanonicalValidationSeverity,
        validationDisposition: CanonicalValidationDisposition,
        summary: String,
        sourceLocation: String? = nil,
        unsupported: Bool = false
    ) {
        self.code = code
        self.disposition = disposition
        self.finding = CanonicalDomainValidator.finding(
            code,
            concept: concept,
            severity: severity,
            disposition: validationDisposition,
            summary: summary,
            sourceLocation: sourceLocation,
            unsupported: unsupported
        )
    }
}

struct CanonicalProjectedBatter: Hashable, Sendable {
    let participant: LineupParticipantEvidence
    let slot: Int
    let lineupEntry: CanonicalBattingOrderEntry
}

struct CanonicalBatterProjectionInput: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let battingSide: TeamSideRole
    let lineup: CanonicalBattingOrderEvidence
    let recordedEvents: [CanonicalScoringEventEvidence]
    let substitutions: [CanonicalSubstitutionEvidence]
    let validationFindings: [CanonicalValidationFinding]
    let sourceLocation: String?

    init(
        gameIdentity: ImportedIdentifierEvidence,
        battingSide: TeamSideRole,
        lineup: CanonicalBattingOrderEvidence,
        recordedEvents: [CanonicalScoringEventEvidence] = [],
        substitutions: [CanonicalSubstitutionEvidence] = [],
        validationFindings: [CanonicalValidationFinding] = [],
        sourceLocation: String? = nil
    ) {
        self.gameIdentity = gameIdentity
        self.battingSide = battingSide
        self.lineup = lineup
        self.recordedEvents = recordedEvents
        self.substitutions = substitutions
        self.validationFindings = validationFindings
        self.sourceLocation = sourceLocation
    }
}

struct CanonicalBatterProjectionResult: Hashable, Sendable {
    let disposition: CanonicalProjectionDisposition
    let currentBatter: CanonicalProjectedBatter?
    let nextBatter: CanonicalProjectedBatter?
    let currentSlot: Int?
    let nextSlot: Int?
    let wraparoundApplied: Bool
    let lineupContext: CanonicalBattingLineupContext
    let diagnostics: [CanonicalProjectionDiagnostic]
    let validation: CanonicalValidationResult
    let sourceEvidenceUsed: [String]
    let sourceEvidenceIgnored: [String]
    let replayMayContinue: Bool
    let futureProductionMustStop: Bool

    init(
        disposition: CanonicalProjectionDisposition,
        currentBatter: CanonicalProjectedBatter?,
        nextBatter: CanonicalProjectedBatter?,
        currentSlot: Int?,
        nextSlot: Int?,
        wraparoundApplied: Bool,
        lineupContext: CanonicalBattingLineupContext,
        diagnostics: [CanonicalProjectionDiagnostic],
        validationFindings: [CanonicalValidationFinding],
        sourceEvidenceUsed: [String],
        sourceEvidenceIgnored: [String]
    ) {
        self.disposition = disposition
        self.currentBatter = currentBatter
        self.nextBatter = nextBatter
        self.currentSlot = currentSlot
        self.nextSlot = nextSlot
        self.wraparoundApplied = wraparoundApplied
        self.lineupContext = lineupContext
        self.diagnostics = diagnostics
        self.validation = CanonicalValidationResult(findings: validationFindings + diagnostics.map(\.finding))
        self.sourceEvidenceUsed = sourceEvidenceUsed.sorted()
        self.sourceEvidenceIgnored = sourceEvidenceIgnored.sorted()
        self.replayMayContinue = disposition.replayMayContinue && validation.processingMayContinueReadOnly
        self.futureProductionMustStop = disposition.futureProductionMustStop || validation.futureWriteMustStop
    }
}

enum CanonicalBatterProjector {
    static func project(_ input: CanonicalBatterProjectionInput) -> CanonicalBatterProjectionResult {
        var diagnostics: [CanonicalProjectionDiagnostic] = []
        var used: Set<String> = ["lineup.entries", "lineup.mode", "recordedEvents.teamSide", "recordedEvents.batter"]
        var ignored: Set<String> = ["currentRosterOrder", "displaySortOrder", "jerseyNumberOrder", "swiftDataFetchOrder", "currentDate"]

        if input.gameIdentity != input.lineup.gameIdentity {
            diagnostics.append(diagnostic("batterProjection.gameMismatch", .contradictory, .battingOrder, .contradiction, .contradictory, "Projection game identity conflicts with lineup evidence.", input.sourceLocation))
            return result(.contradictory, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        switch input.lineup.context {
        case .traditional, .everyoneHits:
            break
        case .unknown:
            diagnostics.append(diagnostic("batterProjection.unknownLineupMode", .unresolved, .battingOrder, .unresolved, .unresolved, "Lineup mode is unknown, so batter projection is not safe.", input.sourceLocation))
            return result(.unresolved, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        case .unsupported:
            diagnostics.append(diagnostic("batterProjection.unsupportedLineupMode", .unsupported, .battingOrder, .unsupported, .unsupported, "Lineup mode is unsupported.", input.sourceLocation, unsupported: true))
            return result(.unsupported, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        case .ambiguous:
            diagnostics.append(diagnostic("batterProjection.ambiguousLineupMode", .ambiguous, .battingOrder, .repair, .repairRequired, "Lineup mode is ambiguous.", input.sourceLocation))
            return result(.ambiguous, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        var slots = orderedSlots(from: input.lineup.entries, diagnostics: &diagnostics, sourceLocation: input.sourceLocation)
        if let blockingDisposition = blockingDisposition(for: diagnostics) {
            return result(blockingDisposition, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }
        if slots.isEmpty {
            diagnostics.append(diagnostic("batterProjection.emptyLineup", .incomplete, .battingOrder, .incomplete, .incomplete, "Lineup has no resolvable batting slots.", input.sourceLocation))
            return result(.incomplete, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        applySupportedSubstitutions(input.substitutions, slots: &slots, diagnostics: &diagnostics, used: &used, sourceLocation: input.sourceLocation)
        slots.sort { $0.slot < $1.slot }

        let sideEvents = input.recordedEvents.filter { $0.teamSide == input.battingSide }
        if sideEvents.count != input.recordedEvents.count {
            ignored.insert("opposingSideEvents")
        }

        guard let orderedEvents = orderedEvents(sideEvents, diagnostics: &diagnostics, sourceLocation: input.sourceLocation) else {
            return result(.ambiguous, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        if orderedEvents.isEmpty {
            let current = projected(at: 0, in: slots)
            let next = projected(at: 1, in: slots)
            return result(disposition(for: diagnostics, resolved: current.projected != nil), input, current.projected, next.projected, current.projected?.slot, next.projected?.slot, next.wrapped, diagnostics, used, ignored)
        }

        guard let lastEvent = orderedEvents.last else {
            return result(.unresolved, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        guard let lastBatter = lastEvent.participants.batter else {
            diagnostics.append(diagnostic("batterProjection.lastEventMissingBatter", .unresolved, .scoringEvent, .unresolved, .unresolved, "The latest batting event for this side has no batter evidence.", input.sourceLocation))
            return result(.unresolved, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        guard lastBatter.playerIdentity.validIdentifier != nil else {
            diagnostics.append(diagnostic("batterProjection.lastEventUnresolvedBatter", .unresolved, .scoringEvent, .unresolved, .unresolved, "The latest batting event for this side has unresolved batter identity.", input.sourceLocation))
            return result(.unresolved, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        guard let lastSlotIndex = slots.firstIndex(where: { $0.entry.participant.playerIdentity == lastBatter.playerIdentity }) else {
            diagnostics.append(diagnostic("batterProjection.lastBatterNotInLineup", .unresolved, .battingOrder, .unresolved, .unresolved, "The latest batter does not resolve to a supplied lineup slot.", input.sourceLocation))
            return result(.unresolved, input, nil, nil, nil, nil, false, diagnostics, used, ignored)
        }

        let current = projected(at: slots.index(after: lastSlotIndex), in: slots)
        let next = projected(at: slots.index(after: lastSlotIndex) + 1, in: slots)
        return result(disposition(for: diagnostics, resolved: current.projected != nil), input, current.projected, next.projected, current.projected?.slot, next.projected?.slot, current.wrapped || next.wrapped, diagnostics, used, ignored)
    }

    private static func orderedSlots(
        from entries: [CanonicalBattingOrderEntry],
        diagnostics: inout [CanonicalProjectionDiagnostic],
        sourceLocation: String?
    ) -> [(slot: Int, entry: CanonicalBattingOrderEntry)] {
        var raw: [(Int, CanonicalBattingOrderEntry)] = []
        var slotCounts: [Int: Int] = [:]
        var playerSlots: [UUID: Set<Int>] = [:]

        for entry in entries {
            switch entry.slotEvidence {
            case let .known(slot), let .historicalSlot(slot):
                guard slot > 0 else {
                    diagnostics.append(diagnostic("batterProjection.unsupportedSlot", .unsupported, .battingOrder, .unsupported, .unsupported, "Batting slot is not a supported positive value.", sourceLocation, unsupported: true))
                    continue
                }
                if case .missingPlayerIdentity = entry.participant {
                    diagnostics.append(diagnostic("batterProjection.missingParticipant", .incomplete, .battingOrder, .incomplete, .incomplete, "A batting slot is missing participant identity.", sourceLocation))
                    continue
                } else if case .invalidPlayerIdentity = entry.participant {
                    diagnostics.append(diagnostic("batterProjection.invalidParticipant", .rejected, .battingOrder, .rejection, .rejected, "A batting slot has invalid participant identity.", sourceLocation))
                    continue
                }
                guard entry.participant.playerIdentity.validIdentifier != nil else {
                    diagnostics.append(diagnostic("batterProjection.unresolvedParticipant", .unresolved, .battingOrder, .unresolved, .unresolved, "A batting slot has unresolved participant identity.", sourceLocation))
                    continue
                }
                raw.append((slot, entry))
                slotCounts[slot, default: 0] += 1
                if let id = entry.participant.playerIdentity.validIdentifier {
                    playerSlots[id, default: []].insert(slot)
                }
            case .missing, .playerWithoutSlot:
                diagnostics.append(diagnostic("batterProjection.missingSlot", .incomplete, .battingOrder, .incomplete, .incomplete, "A lineup participant is missing batting-slot evidence.", sourceLocation))
            case .invalidRaw:
                diagnostics.append(diagnostic("batterProjection.invalidSlot", .rejected, .battingOrder, .rejection, .rejected, "A batting slot has invalid raw evidence.", sourceLocation))
            case .unsupportedRaw, .nonHittingSentinel, .sourceOrder, .progressionHint:
                diagnostics.append(diagnostic("batterProjection.unsupportedSlotEvidence", .unsupported, .battingOrder, .unsupported, .unsupported, "A lineup entry has unsupported batting-slot evidence for projection.", sourceLocation, unsupported: true))
            case .duplicate:
                diagnostics.append(diagnostic("batterProjection.duplicateSlotMarker", .ambiguous, .battingOrder, .repair, .repairRequired, "A lineup entry is explicitly marked as duplicate slot evidence.", sourceLocation))
            case .conflicting:
                diagnostics.append(diagnostic("batterProjection.conflictingSlot", .contradictory, .battingOrder, .contradiction, .contradictory, "A lineup entry has conflicting batting-slot evidence.", sourceLocation))
            case .unresolvedParticipant:
                diagnostics.append(diagnostic("batterProjection.unresolvedParticipant", .unresolved, .battingOrder, .unresolved, .unresolved, "A batting slot has unresolved participant identity.", sourceLocation))
            }
        }

        for (slot, count) in slotCounts where count > 1 {
            diagnostics.append(diagnostic("batterProjection.duplicateSlot.\(slot)", .ambiguous, .battingOrder, .repair, .repairRequired, "Multiple lineup entries claim the same batting slot.", sourceLocation))
        }
        if playerSlots.values.contains(where: { $0.count > 1 }) {
            diagnostics.append(diagnostic("batterProjection.playerMultipleSlots", .contradictory, .battingOrder, .contradiction, .contradictory, "One participant claims multiple batting slots.", sourceLocation))
        }

        let sorted = raw.sorted { $0.0 < $1.0 }
        let slotValues = sorted.map(\.0)
        if let first = slotValues.first, let last = slotValues.last {
            let expected = Set(first...last)
            let actual = Set(slotValues)
            if expected != actual {
                diagnostics.append(diagnostic("batterProjection.slotGap", .incomplete, .battingOrder, .incomplete, .incomplete, "Batting order has a gap in known slots.", sourceLocation))
            }
        }
        return sorted.map { ($0.0, $0.1) }
    }

    private static func applySupportedSubstitutions(
        _ substitutions: [CanonicalSubstitutionEvidence],
        slots: inout [(slot: Int, entry: CanonicalBattingOrderEntry)],
        diagnostics: inout [CanonicalProjectionDiagnostic],
        used: inout Set<String>,
        sourceLocation: String?
    ) {
        for substitution in substitutions.sorted(by: substitutionOrder) {
            guard substitution.teamSide == nil || substitution.teamSide == slots.first?.entry.participant.sideRole else {
                diagnostics.append(diagnostic("batterProjection.substitutionWrongSide", .contradictory, .substitution, .contradiction, .contradictory, "Substitution team side conflicts with lineup side.", sourceLocation))
                continue
            }
            guard substitution.roleEvidence.contains(.batterReplacement) || substitution.roleEvidence.contains(.lineupEntryReplacement) else {
                continue
            }
            guard let slot = substitution.battingSlotContext?.knownSlotValue else {
                diagnostics.append(diagnostic("batterProjection.substitutionMissingSlot", .unresolved, .substitution, .unresolved, .unresolved, "Substitution cannot affect batting projection without a known slot.", sourceLocation))
                continue
            }
            guard case let .participant(incoming) = substitution.incoming, incoming.playerIdentity.validIdentifier != nil else {
                diagnostics.append(diagnostic("batterProjection.substitutionMissingIncoming", .unresolved, .substitution, .unresolved, .unresolved, "Substitution has no resolvable incoming batter.", sourceLocation))
                continue
            }
            guard case let .participant(outgoing) = substitution.outgoing, outgoing.playerIdentity.validIdentifier != nil else {
                diagnostics.append(diagnostic("batterProjection.substitutionMissingOutgoing", .unresolved, .substitution, .unresolved, .unresolved, "Substitution has no resolvable outgoing batter.", sourceLocation))
                continue
            }
            guard incoming.playerIdentity != outgoing.playerIdentity else {
                diagnostics.append(diagnostic("batterProjection.substitutionSameParticipant", .contradictory, .substitution, .contradiction, .contradictory, "Substitution incoming and outgoing participants are the same.", sourceLocation))
                continue
            }
            guard let index = slots.firstIndex(where: { $0.slot == slot && $0.entry.participant.playerIdentity == outgoing.playerIdentity }) else {
                diagnostics.append(diagnostic("batterProjection.substitutionOutgoingMismatch", .unresolved, .substitution, .unresolved, .unresolved, "Substitution outgoing participant does not match the known batting slot.", sourceLocation))
                continue
            }

            let previous = slots[index].entry
            slots[index] = (
                slot,
                CanonicalBattingOrderEntry(
                    gameIdentity: previous.gameIdentity,
                    lineupIdentity: previous.lineupIdentity,
                    participant: incoming,
                    slotEvidence: .historicalSlot(slot),
                    sourceOrderEvidence: previous.sourceOrderEvidence,
                    rosterOrderEvidence: previous.rosterOrderEvidence,
                    displaySortEvidence: previous.displaySortEvidence,
                    jerseyNumberEvidence: previous.jerseyNumberEvidence,
                    source: previous.source
                )
            )
            used.insert("substitution.knownBattingSlot")
            diagnostics.append(diagnostic("batterProjection.substitutionApplied", .resolvedWithWarnings, .substitution, .warning, .validWithWarnings, "A known substitution changed a future batting-slot occupant.", sourceLocation))
        }
    }

    private static func substitutionOrder(_ lhs: CanonicalSubstitutionEvidence, _ rhs: CanonicalSubstitutionEvidence) -> Bool {
        let lhsValue = lhs.effectiveOrder?.value ?? Int.max
        let rhsValue = rhs.effectiveOrder?.value ?? Int.max
        if lhsValue != rhsValue { return lhsValue < rhsValue }
        return String(describing: lhs.substitutionIdentity) < String(describing: rhs.substitutionIdentity)
    }

    private static func orderedEvents(
        _ events: [CanonicalScoringEventEvidence],
        diagnostics: inout [CanonicalProjectionDiagnostic],
        sourceLocation: String?
    ) -> [CanonicalScoringEventEvidence]? {
        var keyed: [(Int, Int, CanonicalScoringEventEvidence)] = []
        var seen: [Int: Int] = [:]

        for (sourceIndex, event) in events.enumerated() {
            let sequences = event.orderingEvidence.compactMap { evidence -> Int? in
                if case let .knownSequence(order) = evidence { return order.value }
                return nil
            }
            if sequences.isEmpty {
                diagnostics.append(diagnostic("batterProjection.missingEventSequence", .incomplete, .scoringEvent, .incomplete, .incomplete, "A batting event is missing sequence evidence.", sourceLocation))
                keyed.append((Int.max / 2 + sourceIndex, sourceIndex, event))
            } else if Set(sequences).count > 1 {
                diagnostics.append(diagnostic("batterProjection.conflictingEventSequence", .ambiguous, .scoringEvent, .repair, .repairRequired, "A batting event has conflicting sequence evidence.", sourceLocation))
                return nil
            } else {
                let sequence = sequences[0]
                seen[sequence, default: 0] += 1
                keyed.append((sequence, sourceIndex, event))
            }
        }

        for (sequence, count) in seen where count > 1 {
            diagnostics.append(diagnostic("batterProjection.duplicateEventSequence.\(sequence)", .ambiguous, .scoringEvent, .repair, .repairRequired, "Multiple batting events claim the same sequence.", sourceLocation))
            return nil
        }

        return keyed.sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
            return lhs.1 < rhs.1
        }.map(\.2)
    }

    private static func projected(
        at index: Int,
        in slots: [(slot: Int, entry: CanonicalBattingOrderEntry)]
    ) -> (projected: CanonicalProjectedBatter?, wrapped: Bool) {
        guard slots.isEmpty == false else { return (nil, false) }
        let wrapped = index >= slots.count
        let normalized = index % slots.count
        let slot = slots[normalized]
        return (CanonicalProjectedBatter(participant: slot.entry.participant, slot: slot.slot, lineupEntry: slot.entry), wrapped)
    }

    private static func disposition(
        for diagnostics: [CanonicalProjectionDiagnostic],
        resolved: Bool
    ) -> CanonicalProjectionDisposition {
        guard resolved else { return .unresolved }
        if diagnostics.contains(where: { $0.disposition == .contradictory }) { return .contradictory }
        if diagnostics.contains(where: { $0.disposition == .rejected }) { return .rejected }
        if diagnostics.contains(where: { $0.disposition == .ambiguous }) { return .ambiguous }
        if diagnostics.contains(where: { $0.disposition == .unsupported }) { return .unsupported }
        if diagnostics.contains(where: { $0.disposition == .unresolved }) { return .unresolved }
        if diagnostics.contains(where: { $0.disposition == .incomplete || $0.disposition == .resolvedWithWarnings }) { return .resolvedWithWarnings }
        return .resolved
    }

    private static func blockingDisposition(for diagnostics: [CanonicalProjectionDiagnostic]) -> CanonicalProjectionDisposition? {
        if diagnostics.contains(where: { $0.disposition == .rejected }) { return .rejected }
        if diagnostics.contains(where: { $0.disposition == .contradictory }) { return .contradictory }
        if diagnostics.contains(where: { $0.disposition == .ambiguous }) { return .ambiguous }
        if diagnostics.contains(where: { $0.disposition == .unsupported }) { return .unsupported }
        return nil
    }

    private static func result(
        _ disposition: CanonicalProjectionDisposition,
        _ input: CanonicalBatterProjectionInput,
        _ current: CanonicalProjectedBatter?,
        _ next: CanonicalProjectedBatter?,
        _ currentSlot: Int?,
        _ nextSlot: Int?,
        _ wrapped: Bool,
        _ diagnostics: [CanonicalProjectionDiagnostic],
        _ used: Set<String>,
        _ ignored: Set<String>
    ) -> CanonicalBatterProjectionResult {
        CanonicalBatterProjectionResult(
            disposition: disposition,
            currentBatter: current,
            nextBatter: next,
            currentSlot: currentSlot,
            nextSlot: nextSlot,
            wraparoundApplied: wrapped,
            lineupContext: input.lineup.context,
            diagnostics: diagnostics,
            validationFindings: input.validationFindings,
            sourceEvidenceUsed: Array(used),
            sourceEvidenceIgnored: Array(ignored)
        )
    }

    private static func diagnostic(
        _ code: String,
        _ disposition: CanonicalProjectionDisposition,
        _ concept: CanonicalValidationConcept,
        _ severity: CanonicalValidationSeverity,
        _ validationDisposition: CanonicalValidationDisposition,
        _ summary: String,
        _ sourceLocation: String?,
        unsupported: Bool = false
    ) -> CanonicalProjectionDiagnostic {
        CanonicalProjectionDiagnostic(
            code,
            disposition: disposition,
            concept: concept,
            severity: severity,
            validationDisposition: validationDisposition,
            summary: summary,
            sourceLocation: sourceLocation,
            unsupported: unsupported
        )
    }
}
