import Foundation
import Testing
@testable import ScoreKeep

@Suite("Startup migration evidence and reconciliation verification")
struct ScoreKeepMigrationReconciliationTests {
    @Test("evidence records full operation and survives fresh authority instances")
    func evidenceRecordsFullOperationAndSurvivesFreshAuthorityInstances() throws {
        let authority = IsolatedStartupMigrationEvidenceSupport()
        let operation = startupMigrationIdentity(storeIdentity: "store-a")

        try authority.beginPreflight(operationIdentity: operation, storeIdentity: "store-a")
        try authority.recordSourceClassification(.populatedCurrentUnversionedStore, operationIdentity: operation)
        try authority.recordSourcePreservationStatus(true, operationIdentity: operation)
        try authority.recordMigrationAttempt(operationIdentity: operation)
        try authority.recordContainerConstructionResult(.openedCompatibleUnversionedSourceAndTransitionedToProposedV2, operationIdentity: operation)
        try authority.recordPostOpenVerificationResult(true, operationIdentity: operation)
        try authority.recordCompletion(operationIdentity: operation)

        let relaunched = authority.freshAuthorityInstance()
        let evidence = try relaunched.currentEvidence(forStoreIdentity: "store-a")

        #expect(evidence?.status == .completed)
        #expect(evidence?.sourceClassification == .populatedCurrentUnversionedStore)
        #expect(evidence?.sourcePreserved == true)
        #expect(evidence?.verificationPassed == true)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: evidence) == .completionProven)
    }

    @Test("interrupted phases reconcile deterministically")
    func interruptedPhasesReconcileDeterministically() throws {
        let authority = IsolatedStartupMigrationEvidenceSupport()
        let operation = startupMigrationIdentity(storeIdentity: "store-b")

        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: nil) == .safeToStart)

        try authority.beginPreflight(operationIdentity: operation, storeIdentity: "store-b")
        var evidence = try authority.evidence(for: operation)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: evidence) == .safeToResumeWithSameIdentity)

        try authority.recordSourcePreservationStatus(true, operationIdentity: operation)
        evidence = try authority.evidence(for: operation)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: evidence) == .safeToResumeWithSameIdentity)

        try authority.recordMigrationAttempt(operationIdentity: operation)
        try authority.recordContainerConstructionResult(.containerCreatedVerificationPending, operationIdentity: operation)
        evidence = try authority.evidence(for: operation)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: evidence) == .safeToVerifyWithoutRepeatingMigration)
    }

    @Test("uncertain failure recovery and disable states reconcile without automatic retry")
    func uncertainFailureRecoveryAndDisableStatesReconcileWithoutAutomaticRetry() throws {
        let authority = IsolatedStartupMigrationEvidenceSupport()

        let failed = startupMigrationIdentity(storeIdentity: "store-c", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007002")!)
        try authority.beginPreflight(operationIdentity: failed, storeIdentity: "store-c")
        try authority.recordSafeFailure(operationIdentity: failed)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: try authority.evidence(for: failed)) == .retryRequiresFreshSourceCopy)

        let uncertain = startupMigrationIdentity(storeIdentity: "store-d", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007003")!)
        try authority.beginPreflight(operationIdentity: uncertain, storeIdentity: "store-d")
        try authority.recordUncertainCompletion(operationIdentity: uncertain)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: try authority.evidence(for: uncertain)) == .completionUncertain)

        let recovery = startupMigrationIdentity(storeIdentity: "store-e", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007004")!)
        try authority.beginPreflight(operationIdentity: recovery, storeIdentity: "store-e")
        try authority.recordRecoveryRequirement(operationIdentity: recovery)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: try authority.evidence(for: recovery)) == .recoveryRequired)

        let disabled = startupMigrationIdentity(storeIdentity: "store-f", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007005")!)
        try authority.beginPreflight(operationIdentity: disabled, storeIdentity: "store-f")
        try authority.recordDisableState(operationIdentity: disabled)
        #expect(ScoreKeepMigrationReconciler.reconcile(sourceClassification: .populatedCurrentUnversionedStore, evidence: try authority.evidence(for: disabled)) == .reviewRequired)
    }

    @Test("conflicting operation and source identity are rejected")
    func conflictingOperationAndSourceIdentityAreRejected() throws {
        let authority = IsolatedStartupMigrationEvidenceSupport()
        let first = startupMigrationIdentity(storeIdentity: "store-g", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007006")!)
        let second = startupMigrationIdentity(storeIdentity: "store-g", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000007007")!)

        try authority.beginPreflight(operationIdentity: first, storeIdentity: "store-g")
        #expect(throws: ScoreKeepMigrationEvidenceError.conflictingOperationReuse) {
            try authority.beginPreflight(operationIdentity: second, storeIdentity: "store-g")
        }
        #expect(throws: ScoreKeepMigrationEvidenceError.conflictingStoreIdentity) {
            try authority.beginPreflight(operationIdentity: first, storeIdentity: "store-h")
        }
    }

    @Test("storage assessment selects split design and defers production storage implementation")
    func storageAssessmentSelectsSplitDesign() {
        #expect(ScoreKeepMigrationEvidenceStorageAssessment.current == .splitPreOpenAndPostOpenEvidenceDesign)
    }
}
