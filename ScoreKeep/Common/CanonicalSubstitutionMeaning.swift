import Foundation

/// Non-routed Phase 1 foundation for substitution relationship evidence.
/// These values classify evidence only and do not apply substitutions or validate legality.
enum SubstitutionEvidenceSource: String, Hashable, Sendable {
    case currentGameReplacedArray
    case currentGameIncomingsArray
    case importedGame
    case lineupRecord
    case pitcherRecord
    case compatibilityTransport
    case syntheticVerification
    case unknown
}

enum SubstitutionRoleEvidence: Hashable, Sendable {
    case batterReplacement
    case runnerReplacement
    case defensiveReplacement
    case pitcherChange
    case lineupEntryReplacement
    case administrative
    case unknown
    case unsupported(String)
}

enum SubstitutionParticipantEvidence: Hashable, Sendable {
    case participant(LineupParticipantEvidence)
    case missing
    case invalid(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case unresolved(PlayerDisplayEvidence)

    var identity: ImportedIdentifierEvidence {
        switch self {
        case let .participant(participant):
            return participant.playerIdentity
        case .missing, .unresolved:
            return .missing
        case let .invalid(identity, _):
            return identity
        }
    }
}

enum LegacyParallelSubstitutionEvidence: Hashable, Sendable {
    case equalCountsPlausibleIndexPairing(count: Int)
    case unequalCounts(incoming: Int, outgoing: Int)
    case missingIncomingArray
    case missingOutgoingArray
    case duplicateIncomingParticipant
    case duplicateOutgoingParticipant
    case sameParticipantInBothRoles
    case ambiguousOrdering
    case cannotEstablishRoleOrTiming
}

struct CanonicalSubstitutionEvidence: Hashable, Sendable {
    let substitutionIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let teamSide: TeamSideRole?
    let incoming: SubstitutionParticipantEvidence
    let outgoing: SubstitutionParticipantEvidence
    let effectiveOrder: OrderEvidence?
    let battingSlotContext: CanonicalBattingSlotEvidence?
    let defensivePositionContext: DefensivePositionEvidence?
    let pitcherChangeContext: Bool
    let roleEvidence: Set<SubstitutionRoleEvidence>
    let historicalLineupContext: LineupSubstitutionEvidence?
    let legacyArrayEvidence: LegacyParallelSubstitutionEvidence?
    let unsupportedRawEvidence: [String]
    let source: SubstitutionEvidenceSource

    init(
        substitutionIdentity: ImportedIdentifierEvidence = .missing,
        gameIdentity: ImportedIdentifierEvidence,
        teamSide: TeamSideRole? = nil,
        incoming: SubstitutionParticipantEvidence,
        outgoing: SubstitutionParticipantEvidence,
        effectiveOrder: OrderEvidence? = nil,
        battingSlotContext: CanonicalBattingSlotEvidence? = nil,
        defensivePositionContext: DefensivePositionEvidence? = nil,
        pitcherChangeContext: Bool = false,
        roleEvidence: Set<SubstitutionRoleEvidence> = [.unknown],
        historicalLineupContext: LineupSubstitutionEvidence? = nil,
        legacyArrayEvidence: LegacyParallelSubstitutionEvidence? = nil,
        unsupportedRawEvidence: [String] = [],
        source: SubstitutionEvidenceSource = .unknown
    ) {
        self.substitutionIdentity = substitutionIdentity
        self.gameIdentity = gameIdentity
        self.teamSide = teamSide
        self.incoming = incoming
        self.outgoing = outgoing
        self.effectiveOrder = effectiveOrder
        self.battingSlotContext = battingSlotContext
        self.defensivePositionContext = defensivePositionContext
        self.pitcherChangeContext = pitcherChangeContext
        self.roleEvidence = roleEvidence
        self.historicalLineupContext = historicalLineupContext
        self.legacyArrayEvidence = legacyArrayEvidence
        self.unsupportedRawEvidence = unsupportedRawEvidence
        self.source = source
    }
}

enum SubstitutionClassification: Hashable, Sendable {
    case incomingParticipantKnown
    case outgoingParticipantKnown
    case missingIncomingParticipant
    case missingOutgoingParticipant
    case sameParticipantIncomingAndOutgoing
    case duplicateSubstitutionEvidence
    case conflictingSubstitutionEvidence
    case ambiguousSubstitutionPairing
    case unsupportedSubstitutionEvidence
    case unresolvedSubstitutionEvidence
    case effectiveOrderKnown
    case missingEffectiveOrder
    case battingSlotContextKnown
    case conflictingBattingSlotContext
    case defensivePositionContextKnown
    case conflictingDefensivePositionContext
    case pitcherChangeEvidence
    case unknownSubstitutionRole
    case batterReplacementEvidence
    case runnerReplacementEvidence
    case defensiveReplacementEvidence
    case lineupEntryReplacementEvidence
    case equalLegacyArraysPlausiblePairingOnly
    case unequalLegacyArrays
    case missingLegacyIncomingArray
    case missingLegacyOutgoingArray
    case duplicateIncomingParticipant
    case duplicateOutgoingParticipant
    case sameParticipantOnBothTeamSides
    case historicalSubstitutionEvidence
    case arrayOrderDoesNotFabricateTimingRoleOrLegality
    case nonApplyingSubstitutionEvidenceOnly
}

enum CanonicalSubstitutionMeaningClassifier {
    static func classify(_ substitution: CanonicalSubstitutionEvidence) -> Set<SubstitutionClassification> {
        var classifications: Set<SubstitutionClassification> = [.nonApplyingSubstitutionEvidenceOnly]

        switch substitution.incoming {
        case .participant:
            classifications.insert(.incomingParticipantKnown)
        case .missing:
            classifications.insert(.missingIncomingParticipant)
            classifications.insert(.unresolvedSubstitutionEvidence)
        case .invalid, .unresolved:
            classifications.insert(.unresolvedSubstitutionEvidence)
        }

        switch substitution.outgoing {
        case .participant:
            classifications.insert(.outgoingParticipantKnown)
        case .missing:
            classifications.insert(.missingOutgoingParticipant)
            classifications.insert(.unresolvedSubstitutionEvidence)
        case .invalid, .unresolved:
            classifications.insert(.unresolvedSubstitutionEvidence)
        }

        if let incomingID = substitution.incoming.identity.validIdentifier,
           let outgoingID = substitution.outgoing.identity.validIdentifier,
           incomingID == outgoingID {
            classifications.insert(.sameParticipantIncomingAndOutgoing)
            classifications.insert(.conflictingSubstitutionEvidence)
        }

        if substitution.effectiveOrder == nil {
            classifications.insert(.missingEffectiveOrder)
        } else {
            classifications.insert(.effectiveOrderKnown)
        }

        if let battingSlotContext = substitution.battingSlotContext {
            switch battingSlotContext {
            case .conflicting:
                classifications.insert(.conflictingBattingSlotContext)
            default:
                classifications.insert(.battingSlotContextKnown)
            }
        }

        if let defensivePositionContext = substitution.defensivePositionContext {
            switch defensivePositionContext {
            case .conflicting:
                classifications.insert(.conflictingDefensivePositionContext)
            default:
                classifications.insert(.defensivePositionContextKnown)
            }
        }

        if substitution.pitcherChangeContext { classifications.insert(.pitcherChangeEvidence) }
        if substitution.historicalLineupContext != nil { classifications.insert(.historicalSubstitutionEvidence) }
        if substitution.unsupportedRawEvidence.isEmpty == false { classifications.insert(.unsupportedSubstitutionEvidence) }

        for role in substitution.roleEvidence {
            switch role {
            case .batterReplacement:
                classifications.insert(.batterReplacementEvidence)
            case .runnerReplacement:
                classifications.insert(.runnerReplacementEvidence)
            case .defensiveReplacement:
                classifications.insert(.defensiveReplacementEvidence)
            case .pitcherChange:
                classifications.insert(.pitcherChangeEvidence)
            case .lineupEntryReplacement:
                classifications.insert(.lineupEntryReplacementEvidence)
            case .administrative, .unknown:
                classifications.insert(.unknownSubstitutionRole)
            case .unsupported:
                classifications.insert(.unsupportedSubstitutionEvidence)
            }
        }

        if let legacyArrayEvidence = substitution.legacyArrayEvidence {
            classifications.formUnion(classifyLegacyEvidence(legacyArrayEvidence))
        }

        return classifications
    }

    static func classifySet(_ substitutions: [CanonicalSubstitutionEvidence]) -> Set<SubstitutionClassification> {
        var classifications = substitutions.reduce(into: Set<SubstitutionClassification>()) { result, substitution in
            result.formUnion(classify(substitution))
        }

        let identities = substitutions.compactMap { $0.substitutionIdentity.validIdentifier }
        if identities.contains(where: { id in identities.filter { $0 == id }.count > 1 }) {
            classifications.insert(.duplicateSubstitutionEvidence)
        }

        var sidesByParticipant: [UUID: Set<TeamSideRole>] = [:]
        for substitution in substitutions {
            for participant in [substitution.incoming, substitution.outgoing] {
                if let id = participant.identity.validIdentifier, let side = substitution.teamSide {
                    sidesByParticipant[id, default: []].insert(side)
                }
            }
        }
        if sidesByParticipant.values.contains(where: { $0.count > 1 }) {
            classifications.insert(.sameParticipantOnBothTeamSides)
            classifications.insert(.conflictingSubstitutionEvidence)
        }

        return classifications
    }

    static func classifyLegacyParallelArrays(
        incoming: [SubstitutionParticipantEvidence]?,
        outgoing: [SubstitutionParticipantEvidence]?
    ) -> Set<SubstitutionClassification> {
        switch (incoming, outgoing) {
        case (nil, nil):
            return [.missingLegacyIncomingArray, .missingLegacyOutgoingArray, .unresolvedSubstitutionEvidence]
        case (nil, .some):
            return [.missingLegacyIncomingArray, .unresolvedSubstitutionEvidence]
        case (.some, nil):
            return [.missingLegacyOutgoingArray, .unresolvedSubstitutionEvidence]
        case let (.some(incoming), .some(outgoing)):
            var classifications: Set<SubstitutionClassification> = [.arrayOrderDoesNotFabricateTimingRoleOrLegality]
            if incoming.count == outgoing.count {
                classifications.insert(.equalLegacyArraysPlausiblePairingOnly)
                classifications.insert(.ambiguousSubstitutionPairing)
            } else {
                classifications.insert(.unequalLegacyArrays)
                classifications.insert(.conflictingSubstitutionEvidence)
            }
            if hasDuplicateIdentities(incoming) { classifications.insert(.duplicateIncomingParticipant) }
            if hasDuplicateIdentities(outgoing) { classifications.insert(.duplicateOutgoingParticipant) }
            let incomingIDs = Set(incoming.compactMap { $0.identity.validIdentifier })
            let outgoingIDs = Set(outgoing.compactMap { $0.identity.validIdentifier })
            if incomingIDs.isDisjoint(with: outgoingIDs) == false {
                classifications.insert(.sameParticipantIncomingAndOutgoing)
                classifications.insert(.conflictingSubstitutionEvidence)
            }
            return classifications
        }
    }

    private static func classifyLegacyEvidence(_ evidence: LegacyParallelSubstitutionEvidence) -> Set<SubstitutionClassification> {
        switch evidence {
        case .equalCountsPlausibleIndexPairing:
            return [.equalLegacyArraysPlausiblePairingOnly, .ambiguousSubstitutionPairing, .arrayOrderDoesNotFabricateTimingRoleOrLegality]
        case .unequalCounts:
            return [.unequalLegacyArrays, .conflictingSubstitutionEvidence]
        case .missingIncomingArray:
            return [.missingLegacyIncomingArray, .unresolvedSubstitutionEvidence]
        case .missingOutgoingArray:
            return [.missingLegacyOutgoingArray, .unresolvedSubstitutionEvidence]
        case .duplicateIncomingParticipant:
            return [.duplicateIncomingParticipant]
        case .duplicateOutgoingParticipant:
            return [.duplicateOutgoingParticipant]
        case .sameParticipantInBothRoles:
            return [.sameParticipantIncomingAndOutgoing, .conflictingSubstitutionEvidence]
        case .ambiguousOrdering:
            return [.ambiguousSubstitutionPairing]
        case .cannotEstablishRoleOrTiming:
            return [.arrayOrderDoesNotFabricateTimingRoleOrLegality, .unknownSubstitutionRole, .missingEffectiveOrder]
        }
    }

    private static func hasDuplicateIdentities(_ participants: [SubstitutionParticipantEvidence]) -> Bool {
        let ids = participants.compactMap { $0.identity.validIdentifier }
        return ids.contains { id in ids.filter { $0 == id }.count > 1 }
    }
}
