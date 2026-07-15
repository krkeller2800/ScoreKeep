import Foundation

/// Non-routed Phase 3 assessment vocabulary for persistence evidence that may need explicit review.
///
/// This type describes repair need only. It must not execute repair, mutate models, save,
/// delete, merge, generate identities, reorder records, replace media, consume allowances,
/// or route production behavior.
enum CanonicalPersistenceRepairAssessmentDisposition: String, CaseIterable, Hashable, Sendable {
    case noRepairRequired
    case reloadRequired
    case reviewRequired
    case relationshipRepairCandidate
    case orderingRepairCandidate
    case mediaCleanupCandidate
    case duplicateIdentityCandidate
    case orphanCandidate
    case unsupportedRepair
    case unsafeAutomaticRepair
    case explicitUserDecisionRequired
    case migrationRequired
    case recordShouldRemainPreserved
    case cannotBeInterpretedCanonically
}

struct CanonicalPersistenceRepairAssessment: Hashable, Sendable {
    let disposition: CanonicalPersistenceRepairAssessmentDisposition
    let findings: [CanonicalValidationFinding]
    let affectedRecordIdentities: [String]
    let modifiesModel: Bool
    let savesStore: Bool
    let deletesRecord: Bool
    let mergesRecords: Bool
    let generatesIdentity: Bool
    let reordersRecords: Bool
    let replacesMedia: Bool
    let consumesAllowanceOrChangesEntitlement: Bool
    let routesProductionBehavior: Bool

    var isAssessmentOnly: Bool {
        !modifiesModel
        && !savesStore
        && !deletesRecord
        && !mergesRecords
        && !generatesIdentity
        && !reordersRecords
        && !replacesMedia
        && !consumesAllowanceOrChangesEntitlement
        && !routesProductionBehavior
    }

    var requiresExplicitReview: Bool {
        switch disposition {
        case .noRepairRequired, .reloadRequired, .recordShouldRemainPreserved:
            return false
        case .reviewRequired, .relationshipRepairCandidate, .orderingRepairCandidate,
             .mediaCleanupCandidate, .duplicateIdentityCandidate, .orphanCandidate,
             .unsupportedRepair, .unsafeAutomaticRepair, .explicitUserDecisionRequired,
             .migrationRequired, .cannotBeInterpretedCanonically:
            return true
        }
    }

    init(
        disposition: CanonicalPersistenceRepairAssessmentDisposition,
        findings: [CanonicalValidationFinding] = [],
        affectedRecordIdentities: [String] = []
    ) {
        self.disposition = disposition
        self.findings = findings.sorted { lhs, rhs in
            if lhs.code != rhs.code { return lhs.code < rhs.code }
            return lhs.summary < rhs.summary
        }
        self.affectedRecordIdentities = affectedRecordIdentities.sorted()
        self.modifiesModel = false
        self.savesStore = false
        self.deletesRecord = false
        self.mergesRecords = false
        self.generatesIdentity = false
        self.reordersRecords = false
        self.replacesMedia = false
        self.consumesAllowanceOrChangesEntitlement = false
        self.routesProductionBehavior = false
    }
}

enum CanonicalPersistenceRepairAssessor {
    static func assess(_ disposition: CanonicalPersistenceRepairAssessmentDisposition, findings: [CanonicalValidationFinding] = [], affectedRecordIdentities: [String] = []) -> CanonicalPersistenceRepairAssessment {
        CanonicalPersistenceRepairAssessment(
            disposition: disposition,
            findings: findings,
            affectedRecordIdentities: affectedRecordIdentities
        )
    }

    static func assessment(for validation: CanonicalValidationResult, affectedRecordIdentities: [String] = []) -> CanonicalPersistenceRepairAssessment {
        if validation.findings.isEmpty {
            return assess(.noRepairRequired, affectedRecordIdentities: affectedRecordIdentities)
        }

        if validation.findings.contains(where: { $0.concept == .ordering }) {
            return assess(.orderingRepairCandidate, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        if validation.findings.contains(where: { $0.concept == .stableIdentity && $0.code.contains("duplicate") }) {
            return assess(.duplicateIdentityCandidate, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        if validation.findings.contains(where: { $0.concept == .team || $0.concept == .player }) {
            return assess(.mediaCleanupCandidate, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        if validation.findings.contains(where: { $0.concept == .rosterMembership || $0.concept == .gameSide || $0.concept == .lineup || $0.concept == .substitution || $0.concept == .pitcherResponsibility || $0.concept == .scoringEvent }) {
            return assess(.relationshipRepairCandidate, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        if validation.containsUnsupportedEvidence || validation.disposition == .unsupported {
            return assess(.unsupportedRepair, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        if validation.futureWriteMustStop || validation.explicitRepairRequired {
            return assess(.explicitUserDecisionRequired, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
        }
        return assess(.reviewRequired, findings: validation.findings, affectedRecordIdentities: affectedRecordIdentities)
    }
}
