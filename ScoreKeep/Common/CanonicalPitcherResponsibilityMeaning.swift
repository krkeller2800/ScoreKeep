import Foundation

/// Non-routed Phase 1 foundation for pitcher appearance and responsibility evidence.
/// These values classify evidence only and do not project active pitchers or calculate statistics.
enum PitcherResponsibilityEvidenceSource: String, Hashable, Sendable {
    case currentPitcherRecord
    case currentAtbatRecord
    case importedGame
    case compatibilityTransport
    case currentActivePitcherState
    case syntheticVerification
    case unknown
}

enum PitcherAppearanceRoleEvidence: Hashable, Sendable {
    case startingPitcher
    case reliefPitcher
    case activePitcher
    case pitcherOnlyParticipant
    case batterAndPitcher
    case unknown
    case conflicting(Set<PitcherAppearanceRoleEvidence>)
}

enum PitcherAppearanceBoundaryEvidence: Hashable, Sendable {
    case notRepresented
    case known(inning: Int, outs: Int, batters: Int)
    case missing
    case incomplete(inning: Int?, outs: Int?, batters: Int?)
    case conflicting(String)
}

struct CanonicalPitcherAppearanceEvidence: Hashable, Sendable {
    let appearanceIdentity: ImportedIdentifierEvidence
    let reusablePitcherIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let teamSide: TeamSideRole?
    let appearanceOrder: OrderEvidence?
    let roleEvidence: Set<PitcherAppearanceRoleEvidence>
    let startBoundary: PitcherAppearanceBoundaryEvidence
    let endBoundary: PitcherAppearanceBoundaryEvidence
    let historicalDisplayEvidence: PlayerDisplayEvidence
    let source: PitcherResponsibilityEvidenceSource

    init(
        appearanceIdentity: ImportedIdentifierEvidence,
        reusablePitcherIdentity: ImportedIdentifierEvidence,
        gameIdentity: ImportedIdentifierEvidence,
        teamSide: TeamSideRole? = nil,
        appearanceOrder: OrderEvidence? = nil,
        roleEvidence: Set<PitcherAppearanceRoleEvidence> = [.unknown],
        startBoundary: PitcherAppearanceBoundaryEvidence = .notRepresented,
        endBoundary: PitcherAppearanceBoundaryEvidence = .notRepresented,
        historicalDisplayEvidence: PlayerDisplayEvidence = PlayerDisplayEvidence(),
        source: PitcherResponsibilityEvidenceSource = .unknown
    ) {
        self.appearanceIdentity = appearanceIdentity
        self.reusablePitcherIdentity = reusablePitcherIdentity
        self.gameIdentity = gameIdentity
        self.teamSide = teamSide
        self.appearanceOrder = appearanceOrder
        self.roleEvidence = roleEvidence
        self.startBoundary = startBoundary
        self.endBoundary = endBoundary
        self.historicalDisplayEvidence = historicalDisplayEvidence
        self.source = source
    }
}

enum PitcherEventResponsibilityEvidence: Hashable, Sendable {
    case explicitPitcher(CanonicalPitcherAppearanceEvidence)
    case missingPitcherRelationship
    case invalidPitcherIdentity(ImportedIdentifierEvidence)
    case multiplePitchers(Set<ImportedIdentifierEvidence>)
    case currentActivePitcherDiffers(historical: ImportedIdentifierEvidence, current: ImportedIdentifierEvidence)
    case unresolved
}

struct CanonicalPitcherResponsibilityEvidence: Hashable, Sendable {
    let eventIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let teamSide: TeamSideRole?
    let responsibility: PitcherEventResponsibilityEvidence
    let runResponsibilityEvidence: ScoringEventMarkerEvidence
    let earnedRunResponsibilityEvidence: ScoringEventMarkerEvidence
    let source: PitcherResponsibilityEvidenceSource

    init(
        eventIdentity: ImportedIdentifierEvidence,
        gameIdentity: ImportedIdentifierEvidence,
        teamSide: TeamSideRole? = nil,
        responsibility: PitcherEventResponsibilityEvidence,
        runResponsibilityEvidence: ScoringEventMarkerEvidence = .notRepresented,
        earnedRunResponsibilityEvidence: ScoringEventMarkerEvidence = .notRepresented,
        source: PitcherResponsibilityEvidenceSource = .unknown
    ) {
        self.eventIdentity = eventIdentity
        self.gameIdentity = gameIdentity
        self.teamSide = teamSide
        self.responsibility = responsibility
        self.runResponsibilityEvidence = runResponsibilityEvidence
        self.earnedRunResponsibilityEvidence = earnedRunResponsibilityEvidence
        self.source = source
    }
}

enum PitcherResponsibilityClassification: Hashable, Sendable {
    case validPitcherIdentity
    case missingPitcherRelationship
    case invalidPitcherIdentity
    case duplicatePitcherIdentity
    case conflictingPitcherResponsibility
    case incompletePitcherRelationship
    case ambiguousPitcherRelationship
    case unresolvedPitcherRelationship
    case appearanceOrderKnown
    case appearanceOrderMissing
    case appearanceOrderDuplicated(Int)
    case startingPitcherEvidence
    case reliefPitcherEvidence
    case activePitcherEvidence
    case pitcherOnlyParticipant
    case batterAndPitcherParticipant
    case eventReferencesKnownPitcher
    case runMarkerWithoutResolvablePitcher
    case earnedRunMarkerWithoutResolvablePitcher
    case teamSideConflict
    case currentPitcherStateDoesNotRewriteHistoricalResponsibility
    case historicalPitcherEvidence
    case nonCalculatingResponsibilityEvidenceOnly
}

enum CanonicalPitcherResponsibilityMeaningClassifier {
    static func classifyAppearance(_ appearance: CanonicalPitcherAppearanceEvidence) -> Set<PitcherResponsibilityClassification> {
        var classifications: Set<PitcherResponsibilityClassification> = [.nonCalculatingResponsibilityEvidenceOnly]

        switch appearance.reusablePitcherIdentity {
        case .valid:
            classifications.insert(.validPitcherIdentity)
        case .missing:
            classifications.insert(.missingPitcherRelationship)
            classifications.insert(.unresolvedPitcherRelationship)
        case .invalid:
            classifications.insert(.invalidPitcherIdentity)
            classifications.insert(.unresolvedPitcherRelationship)
        }

        if let order = appearance.appearanceOrder, let value = order.value {
            classifications.insert(.appearanceOrderKnown)
            if order.kind != .pitcherAppearance { classifications.insert(.ambiguousPitcherRelationship) }
            if value < 0 { classifications.insert(.appearanceOrderMissing) }
        } else {
            classifications.insert(.appearanceOrderMissing)
        }

        if appearance.startBoundary == .missing || appearance.endBoundary == .missing {
            classifications.insert(.incompletePitcherRelationship)
        }

        for role in appearance.roleEvidence {
            switch role {
            case .startingPitcher:
                classifications.insert(.startingPitcherEvidence)
            case .reliefPitcher:
                classifications.insert(.reliefPitcherEvidence)
            case .activePitcher:
                classifications.insert(.activePitcherEvidence)
            case .pitcherOnlyParticipant:
                classifications.insert(.pitcherOnlyParticipant)
            case .batterAndPitcher:
                classifications.insert(.batterAndPitcherParticipant)
            case .unknown:
                classifications.insert(.ambiguousPitcherRelationship)
            case .conflicting:
                classifications.insert(.conflictingPitcherResponsibility)
            }
        }

        return classifications
    }

    static func classifyResponsibility(_ evidence: CanonicalPitcherResponsibilityEvidence) -> Set<PitcherResponsibilityClassification> {
        var classifications: Set<PitcherResponsibilityClassification> = [.nonCalculatingResponsibilityEvidenceOnly]
        switch evidence.responsibility {
        case let .explicitPitcher(appearance):
            classifications.formUnion(classifyAppearance(appearance))
            classifications.insert(.eventReferencesKnownPitcher)
            classifications.insert(.historicalPitcherEvidence)
            if let eventSide = evidence.teamSide,
               let pitcherSide = appearance.teamSide,
               eventSide != pitcherSide {
                classifications.insert(.teamSideConflict)
            }
        case .missingPitcherRelationship:
            classifications.insert(.missingPitcherRelationship)
            classifications.insert(.unresolvedPitcherRelationship)
        case .invalidPitcherIdentity:
            classifications.insert(.invalidPitcherIdentity)
            classifications.insert(.unresolvedPitcherRelationship)
        case .multiplePitchers:
            classifications.insert(.conflictingPitcherResponsibility)
        case .currentActivePitcherDiffers:
            classifications.insert(.currentPitcherStateDoesNotRewriteHistoricalResponsibility)
            classifications.insert(.historicalPitcherEvidence)
        case .unresolved:
            classifications.insert(.unresolvedPitcherRelationship)
        }

        if markerHasEvidence(evidence.runResponsibilityEvidence), hasResolvablePitcher(evidence.responsibility) == false {
            classifications.insert(.runMarkerWithoutResolvablePitcher)
        }
        if markerHasEvidence(evidence.earnedRunResponsibilityEvidence), hasResolvablePitcher(evidence.responsibility) == false {
            classifications.insert(.earnedRunMarkerWithoutResolvablePitcher)
        }
        return classifications
    }

    static func classifyAppearanceSet(_ appearances: [CanonicalPitcherAppearanceEvidence]) -> Set<PitcherResponsibilityClassification> {
        var classifications = appearances.reduce(into: Set<PitcherResponsibilityClassification>()) { result, appearance in
            result.formUnion(classifyAppearance(appearance))
        }

        let ids = appearances.compactMap { $0.appearanceIdentity.validIdentifier }
        if ids.contains(where: { id in ids.filter { $0 == id }.count > 1 }) {
            classifications.insert(.duplicatePitcherIdentity)
        }

        let orders = appearances.compactMap { $0.appearanceOrder?.value }
        if let duplicated = orders.first(where: { value in orders.filter { $0 == value }.count > 1 }) {
            classifications.insert(.appearanceOrderDuplicated(duplicated))
        }

        return classifications
    }

    private static func hasResolvablePitcher(_ evidence: PitcherEventResponsibilityEvidence) -> Bool {
        if case .explicitPitcher = evidence { return true }
        return false
    }

    private static func markerHasEvidence(_ marker: ScoringEventMarkerEvidence) -> Bool {
        switch marker {
        case .notRepresented:
            return false
        case let .count(value):
            return value != 0
        case .flag, .conflicting:
            return true
        }
    }
}
