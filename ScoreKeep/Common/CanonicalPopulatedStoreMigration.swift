import Foundation

/// Non-routed Phase 3 vocabulary for populated existing-store migration verification.
///
/// These types describe shallow evidence only. They do not open stores, route startup,
/// register schemas, mutate models, store contexts, retain live SwiftData objects, or
/// carry purchase receipts, signed transactions, Keychain material, or production state.
enum CanonicalPopulatedMigrationPhase: String, CaseIterable, Hashable, Sendable {
    case inspectSource
    case classifySource
    case validateSource
    case snapshotSourceEvidence
    case buildMigrationPlan
    case createIsolatedTarget
    case writeSupportedTargetRecords
    case preserveUnsupportedEvidence
    case saveTarget
    case reloadTarget
    case interpretTargetCanonically
    case compareSourceAndTargetMeaning
    case markCompletion
}

enum CanonicalMigrationEvidenceReconciliation: String, CaseIterable, Hashable, Sendable {
    case preservedDirectly
    case reconstructedCanonically
    case recalculated
    case preservedAsCompatibilityEvidence
    case preservedWithWarning
    case unsupported
    case ambiguous
    case contradictory
    case requiresRepairAssessment
    case requiresUserReview
    case cannotSafelyMigrate
}

enum CanonicalStoredScoreReconciliation: String, CaseIterable, Hashable, Sendable {
    case matchesReplayDerivedScore
    case differsFromReplayDerivedScore
    case replayCannotEstablishScore
    case storedScoreUnsupported
    case storedScoreAbsent
    case reviewRequired
}

struct CanonicalPopulatedMigrationProgressEvidence: Hashable, Sendable {
    let operationIdentity: String
    let sourceIdentity: String
    let targetIdentity: String
    let currentPhase: CanonicalPopulatedMigrationPhase?
    let completedPhases: [CanonicalPopulatedMigrationPhase]
    let recordCounts: CanonicalMigrationRecordCounts
    let completionMarker: Bool
    let failureMarker: String?
    let interruptionMarker: String?

    init(
        operationIdentity: String,
        sourceIdentity: String,
        targetIdentity: String,
        currentPhase: CanonicalPopulatedMigrationPhase?,
        completedPhases: [CanonicalPopulatedMigrationPhase],
        recordCounts: CanonicalMigrationRecordCounts,
        completionMarker: Bool,
        failureMarker: String? = nil,
        interruptionMarker: String? = nil
    ) {
        self.operationIdentity = operationIdentity
        self.sourceIdentity = sourceIdentity
        self.targetIdentity = targetIdentity
        self.currentPhase = currentPhase
        self.completedPhases = completedPhases
        self.recordCounts = recordCounts
        self.completionMarker = completionMarker
        self.failureMarker = failureMarker
        self.interruptionMarker = interruptionMarker
    }
}

struct CanonicalPopulatedMigrationSummary: Hashable, Sendable {
    let sourceIdentity: String
    let targetIdentity: String
    let lastCompletedPhase: CanonicalPopulatedMigrationPhase?
    let sourceRecordCounts: CanonicalMigrationRecordCounts
    let targetRecordCounts: CanonicalMigrationRecordCounts
    let migratedCounts: CanonicalMigrationRecordCounts
    let preservedEvidenceCount: Int
    let skippedRecordCount: Int
    let unsupportedEvidenceCount: Int
    let duplicateIdentityCount: Int
    let relationshipFindingCount: Int
    let orderingFindingCount: Int
    let mediaFindingCount: Int
    let storedScoreReconciliation: CanonicalStoredScoreReconciliation
    let reconciliation: [CanonicalMigrationEvidenceReconciliation]
    let progress: CanonicalPopulatedMigrationProgressEvidence

    var completedAllVerificationPhases: Bool {
        lastCompletedPhase == .markCompletion && progress.completionMarker
    }
}
