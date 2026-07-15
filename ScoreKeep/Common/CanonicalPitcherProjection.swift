import Foundation

struct CanonicalPitcherChangeEvidence: Hashable, Sendable {
    let substitution: CanonicalSubstitutionEvidence

    init(_ substitution: CanonicalSubstitutionEvidence) {
        self.substitution = substitution
    }
}

struct CanonicalProjectedPitcher: Hashable, Sendable {
    let appearance: CanonicalPitcherAppearanceEvidence
    let appearanceOrder: Int?
    let isStartingPitcher: Bool
    let isReliefPitcher: Bool
}

struct CanonicalPitcherResponsibilityWarning: Hashable, Sendable {
    let eventIdentity: ImportedIdentifierEvidence
    let responsibility: PitcherEventResponsibilityEvidence
    let classifications: Set<PitcherResponsibilityClassification>
}

struct CanonicalPitcherProjectionInput: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let defensiveSide: TeamSideRole
    let appearances: [CanonicalPitcherAppearanceEvidence]
    let pitcherChanges: [CanonicalPitcherChangeEvidence]
    let eventResponsibilities: [CanonicalPitcherResponsibilityEvidence]
    let validationFindings: [CanonicalValidationFinding]
    let sourceLocation: String?

    init(
        gameIdentity: ImportedIdentifierEvidence,
        defensiveSide: TeamSideRole,
        appearances: [CanonicalPitcherAppearanceEvidence],
        pitcherChanges: [CanonicalPitcherChangeEvidence] = [],
        eventResponsibilities: [CanonicalPitcherResponsibilityEvidence] = [],
        validationFindings: [CanonicalValidationFinding] = [],
        sourceLocation: String? = nil
    ) {
        self.gameIdentity = gameIdentity
        self.defensiveSide = defensiveSide
        self.appearances = appearances
        self.pitcherChanges = pitcherChanges
        self.eventResponsibilities = eventResponsibilities
        self.validationFindings = validationFindings
        self.sourceLocation = sourceLocation
    }
}

struct CanonicalPitcherProjectionResult: Hashable, Sendable {
    let disposition: CanonicalProjectionDisposition
    let activePitcher: CanonicalProjectedPitcher?
    let startingPitcher: CanonicalProjectedPitcher?
    let reliefAppearances: [CanonicalProjectedPitcher]
    let appearanceOrder: [CanonicalProjectedPitcher]
    let responsibilityWarnings: [CanonicalPitcherResponsibilityWarning]
    let diagnostics: [CanonicalProjectionDiagnostic]
    let validation: CanonicalValidationResult
    let sourceEvidenceUsed: [String]
    let sourceEvidenceIgnored: [String]
    let replayMayContinue: Bool
    let futureProductionMustStop: Bool

    init(
        disposition: CanonicalProjectionDisposition,
        activePitcher: CanonicalProjectedPitcher?,
        startingPitcher: CanonicalProjectedPitcher?,
        reliefAppearances: [CanonicalProjectedPitcher],
        appearanceOrder: [CanonicalProjectedPitcher],
        responsibilityWarnings: [CanonicalPitcherResponsibilityWarning],
        diagnostics: [CanonicalProjectionDiagnostic],
        validationFindings: [CanonicalValidationFinding],
        sourceEvidenceUsed: [String],
        sourceEvidenceIgnored: [String]
    ) {
        self.disposition = disposition
        self.activePitcher = activePitcher
        self.startingPitcher = startingPitcher
        self.reliefAppearances = reliefAppearances
        self.appearanceOrder = appearanceOrder
        self.responsibilityWarnings = responsibilityWarnings
        self.diagnostics = diagnostics
        self.validation = CanonicalValidationResult(findings: validationFindings + diagnostics.map(\.finding))
        self.sourceEvidenceUsed = sourceEvidenceUsed.sorted()
        self.sourceEvidenceIgnored = sourceEvidenceIgnored.sorted()
        self.replayMayContinue = disposition.replayMayContinue && validation.processingMayContinueReadOnly
        self.futureProductionMustStop = disposition.futureProductionMustStop || validation.futureWriteMustStop
    }
}

enum CanonicalPitcherProjector {
    static func project(_ input: CanonicalPitcherProjectionInput) -> CanonicalPitcherProjectionResult {
        var diagnostics: [CanonicalProjectionDiagnostic] = []
        var used: Set<String> = ["pitcherAppearances", "appearanceOrder", "appearanceRole", "eventResponsibilities"]
        let ignored: Set<String> = ["currentRosterOrder", "displaySortOrder", "playerPositionText", "currentBatter", "swiftDataFetchOrder", "currentDate"]

        let appearances = input.appearances.filter { appearance in
            if appearance.gameIdentity != input.gameIdentity {
                diagnostics.append(diagnostic("pitcherProjection.gameMismatch", .contradictory, .pitcherResponsibility, .contradiction, .contradictory, "Pitcher appearance game identity conflicts with projection game.", input.sourceLocation))
                return false
            }
            if let side = appearance.teamSide, side != input.defensiveSide {
                diagnostics.append(diagnostic("pitcherProjection.teamSideConflict", .contradictory, .pitcherResponsibility, .contradiction, .contradictory, "Pitcher appearance team side conflicts with requested defensive side.", input.sourceLocation))
                return false
            }
            return appearance.teamSide == nil || appearance.teamSide == input.defensiveSide
        }

        guard appearances.isEmpty == false else {
            diagnostics.append(diagnostic("pitcherProjection.missingPitcher", .incomplete, .pitcherResponsibility, .incomplete, .incomplete, "No pitcher appearance evidence was supplied for this defensive side.", input.sourceLocation))
            return result(.incomplete, input, nil, nil, [], [], [], diagnostics, used, ignored)
        }

        let projected = orderedAppearances(appearances, diagnostics: &diagnostics, sourceLocation: input.sourceLocation)
        if projected == nil {
            return result(.ambiguous, input, nil, nil, [], [], [], diagnostics, used, ignored)
        }

        var ordered = projected ?? []
        let starters = ordered.filter(\.isStartingPitcher)
        let relief = ordered.filter(\.isReliefPitcher)

        if starters.isEmpty {
            diagnostics.append(diagnostic("pitcherProjection.missingStartingPitcher", .incomplete, .pitcherResponsibility, .incomplete, .incomplete, "No starting-pitcher evidence was supplied.", input.sourceLocation))
        } else if starters.count > 1 {
            diagnostics.append(diagnostic("pitcherProjection.multipleStartingPitchers", .ambiguous, .pitcherResponsibility, .repair, .repairRequired, "Multiple pitcher appearances claim starting-pitcher role.", input.sourceLocation))
        }

        applyPitcherChanges(input.pitcherChanges, activeOrder: &ordered, diagnostics: &diagnostics, used: &used, sourceLocation: input.sourceLocation)

        let active = activePitcher(from: ordered)
        let warnings = responsibilityWarnings(input.eventResponsibilities, active: active, defensiveSide: input.defensiveSide, diagnostics: &diagnostics, sourceLocation: input.sourceLocation)
        if warnings.isEmpty == false {
            used.insert("eventPitcherResponsibility")
        }

        let finalDisposition = disposition(for: diagnostics, resolved: active != nil)
        return result(finalDisposition, input, active, starters.first, relief, ordered, warnings, diagnostics, used, ignored)
    }

    private static func orderedAppearances(
        _ appearances: [CanonicalPitcherAppearanceEvidence],
        diagnostics: inout [CanonicalProjectionDiagnostic],
        sourceLocation: String?
    ) -> [CanonicalProjectedPitcher]? {
        var seenOrders: [Int: Int] = [:]
        var duplicateIdentities: [UUID: Int] = [:]
        var keyed: [(Int, Int, CanonicalPitcherAppearanceEvidence)] = []

        for (sourceIndex, appearance) in appearances.enumerated() {
            switch appearance.reusablePitcherIdentity {
            case .valid:
                if let id = appearance.appearanceIdentity.validIdentifier {
                    duplicateIdentities[id, default: 0] += 1
                }
            case .missing:
                diagnostics.append(diagnostic("pitcherProjection.missingPitcherIdentity", .incomplete, .pitcherResponsibility, .incomplete, .incomplete, "Pitcher appearance is missing pitcher identity.", sourceLocation))
            case .invalid:
                diagnostics.append(diagnostic("pitcherProjection.invalidPitcherIdentity", .rejected, .pitcherResponsibility, .rejection, .rejected, "Pitcher appearance has invalid pitcher identity.", sourceLocation))
            }

            if let order = appearance.appearanceOrder?.value {
                if order < 0 {
                    diagnostics.append(diagnostic("pitcherProjection.invalidAppearanceOrder", .rejected, .pitcherResponsibility, .rejection, .rejected, "Pitcher appearance order is invalid.", sourceLocation))
                }
                seenOrders[order, default: 0] += 1
                keyed.append((order, sourceIndex, appearance))
            } else if appearance.roleEvidence.contains(.startingPitcher) {
                diagnostics.append(diagnostic("pitcherProjection.missingStarterOrder", .resolvedWithWarnings, .pitcherResponsibility, .warning, .validWithWarnings, "Starting pitcher has no explicit order and is treated as the first appearance.", sourceLocation))
                keyed.append((0, sourceIndex, appearance))
            } else {
                diagnostics.append(diagnostic("pitcherProjection.missingAppearanceOrder", .ambiguous, .pitcherResponsibility, .repair, .repairRequired, "Relief pitcher appearance is missing order evidence.", sourceLocation))
                return nil
            }

            if appearance.roleEvidence.contains(where: { role in
                if case .conflicting = role { return true }
                return false
            }) {
                diagnostics.append(diagnostic("pitcherProjection.conflictingRole", .contradictory, .pitcherResponsibility, .contradiction, .contradictory, "Pitcher appearance has conflicting role evidence.", sourceLocation))
            }
        }

        for (order, count) in seenOrders where count > 1 {
            diagnostics.append(diagnostic("pitcherProjection.duplicateAppearanceOrder.\(order)", .ambiguous, .pitcherResponsibility, .repair, .repairRequired, "Multiple pitcher appearances claim the same order.", sourceLocation))
            return nil
        }

        if duplicateIdentities.values.contains(where: { $0 > 1 }) {
            diagnostics.append(diagnostic("pitcherProjection.duplicateAppearanceIdentity", .ambiguous, .pitcherResponsibility, .repair, .repairRecommended, "The same pitcher appearance identity appears more than once.", sourceLocation))
        }

        return keyed.sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
            return lhs.1 < rhs.1
        }.map { order, _, appearance in
            CanonicalProjectedPitcher(
                appearance: appearance,
                appearanceOrder: order,
                isStartingPitcher: appearance.roleEvidence.contains(.startingPitcher),
                isReliefPitcher: appearance.roleEvidence.contains(.reliefPitcher)
            )
        }
    }

    private static func applyPitcherChanges(
        _ changes: [CanonicalPitcherChangeEvidence],
        activeOrder: inout [CanonicalProjectedPitcher],
        diagnostics: inout [CanonicalProjectionDiagnostic],
        used: inout Set<String>,
        sourceLocation: String?
    ) {
        for change in changes.sorted(by: { ($0.substitution.effectiveOrder?.value ?? Int.max) < ($1.substitution.effectiveOrder?.value ?? Int.max) }) {
            let substitution = change.substitution
            guard substitution.pitcherChangeContext || substitution.roleEvidence.contains(.pitcherChange) else { continue }
            used.insert("pitcherChangeEvidence")

            if substitution.effectiveOrder == nil {
                diagnostics.append(diagnostic("pitcherProjection.pitcherChangeMissingTiming", .unresolved, .substitution, .unresolved, .unresolved, "Pitcher change has no timing evidence.", sourceLocation))
            }
            guard case let .participant(incoming) = substitution.incoming, incoming.playerIdentity.validIdentifier != nil else {
                diagnostics.append(diagnostic("pitcherProjection.pitcherChangeMissingIncoming", .unresolved, .substitution, .unresolved, .unresolved, "Pitcher change has no resolvable incoming pitcher.", sourceLocation))
                continue
            }
            guard case let .participant(outgoing) = substitution.outgoing, outgoing.playerIdentity.validIdentifier != nil else {
                diagnostics.append(diagnostic("pitcherProjection.pitcherChangeMissingOutgoing", .unresolved, .substitution, .unresolved, .unresolved, "Pitcher change has no resolvable outgoing pitcher.", sourceLocation))
                continue
            }
            guard incoming.playerIdentity != outgoing.playerIdentity else {
                diagnostics.append(diagnostic("pitcherProjection.pitcherChangeSameParticipant", .contradictory, .substitution, .contradiction, .contradictory, "Pitcher change incoming and outgoing participants are the same.", sourceLocation))
                continue
            }

            if activeOrder.contains(where: { $0.appearance.reusablePitcherIdentity == incoming.playerIdentity }) == false {
                let appearance = CanonicalPitcherAppearanceEvidence(
                    appearanceIdentity: .missing,
                    reusablePitcherIdentity: incoming.playerIdentity,
                    gameIdentity: substitution.gameIdentity,
                    teamSide: substitution.teamSide,
                    appearanceOrder: substitution.effectiveOrder,
                    roleEvidence: [.reliefPitcher, .activePitcher],
                    startBoundary: .missing,
                    endBoundary: .missing,
                    historicalDisplayEvidence: PlayerDisplayEvidence(),
                    source: .syntheticVerification
                )
                activeOrder.append(
                    CanonicalProjectedPitcher(
                        appearance: appearance,
                        appearanceOrder: substitution.effectiveOrder?.value,
                        isStartingPitcher: false,
                        isReliefPitcher: true
                    )
                )
                diagnostics.append(diagnostic("pitcherProjection.pitcherChangeApplied", .resolvedWithWarnings, .substitution, .warning, .validWithWarnings, "Pitcher change supplies an incoming relief pitcher without a separate appearance record.", sourceLocation))
            }
        }
        activeOrder.sort { lhs, rhs in
            let lhsOrder = lhs.appearanceOrder ?? Int.max
            let rhsOrder = rhs.appearanceOrder ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return String(describing: lhs.appearance.reusablePitcherIdentity) < String(describing: rhs.appearance.reusablePitcherIdentity)
        }
    }

    private static func activePitcher(from ordered: [CanonicalProjectedPitcher]) -> CanonicalProjectedPitcher? {
        if let explicit = ordered.last(where: { $0.appearance.roleEvidence.contains(.activePitcher) }) {
            return explicit
        }
        return ordered.last
    }

    private static func responsibilityWarnings(
        _ responsibilities: [CanonicalPitcherResponsibilityEvidence],
        active: CanonicalProjectedPitcher?,
        defensiveSide: TeamSideRole,
        diagnostics: inout [CanonicalProjectionDiagnostic],
        sourceLocation: String?
    ) -> [CanonicalPitcherResponsibilityWarning] {
        var warnings: [CanonicalPitcherResponsibilityWarning] = []

        for responsibility in responsibilities {
            let classifications = CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(responsibility)
            var shouldWarn = classifications.contains(.missingPitcherRelationship) ||
                classifications.contains(.invalidPitcherIdentity) ||
                classifications.contains(.conflictingPitcherResponsibility) ||
                classifications.contains(.runMarkerWithoutResolvablePitcher) ||
                classifications.contains(.earnedRunMarkerWithoutResolvablePitcher) ||
                classifications.contains(.teamSideConflict) ||
                classifications.contains(.currentPitcherStateDoesNotRewriteHistoricalResponsibility)

            if let side = responsibility.teamSide, side != defensiveSide {
                shouldWarn = true
                diagnostics.append(diagnostic("pitcherProjection.eventTeamSideConflict", .contradictory, .pitcherResponsibility, .contradiction, .contradictory, "Event pitcher responsibility team side conflicts with projected defensive side.", sourceLocation))
            }

            if let active {
                switch responsibility.responsibility {
                case let .explicitPitcher(appearance):
                    if appearance.reusablePitcherIdentity != active.appearance.reusablePitcherIdentity {
                        shouldWarn = true
                        diagnostics.append(diagnostic("pitcherProjection.eventPriorPitcher", .resolvedWithWarnings, .pitcherResponsibility, .warning, .validWithWarnings, "Event responsibility references a pitcher other than the projected active pitcher.", sourceLocation))
                    }
                case .missingPitcherRelationship, .invalidPitcherIdentity, .multiplePitchers, .currentActivePitcherDiffers, .unresolved:
                    shouldWarn = true
                }
            }

            if shouldWarn {
                warnings.append(
                    CanonicalPitcherResponsibilityWarning(
                        eventIdentity: responsibility.eventIdentity,
                        responsibility: responsibility.responsibility,
                        classifications: classifications
                    )
                )
            }
        }

        return warnings
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

    private static func result(
        _ disposition: CanonicalProjectionDisposition,
        _ input: CanonicalPitcherProjectionInput,
        _ active: CanonicalProjectedPitcher?,
        _ starter: CanonicalProjectedPitcher?,
        _ relief: [CanonicalProjectedPitcher],
        _ ordered: [CanonicalProjectedPitcher],
        _ warnings: [CanonicalPitcherResponsibilityWarning],
        _ diagnostics: [CanonicalProjectionDiagnostic],
        _ used: Set<String>,
        _ ignored: Set<String>
    ) -> CanonicalPitcherProjectionResult {
        CanonicalPitcherProjectionResult(
            disposition: disposition,
            activePitcher: active,
            startingPitcher: starter,
            reliefAppearances: relief,
            appearanceOrder: ordered,
            responsibilityWarnings: warnings,
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
