import Foundation

enum ScoreKeepMigrationEvidenceStatus: String, CaseIterable, Hashable, Sendable, Codable {
    case none
    case preflightBegan
    case sourceClassified
    case sourcePreserved
    case migrationAttempted
    case containerConstructionRecorded
    case postOpenVerificationRecorded
    case completed
    case failedSafely
    case completionUncertain
    case recoveryRequired
    case disabled
}

struct ScoreKeepMigrationEvidenceRecord: Hashable, Sendable, Codable {
    let operationIdentity: ScoreKeepMigrationOperationIdentity
    let storeIdentity: String
    let sourceClassification: ScoreKeepSourceStoreClassification?
    let sourcePreserved: Bool
    let constructionDisposition: ScoreKeepProposedContainerConstructionDisposition?
    let verificationPassed: Bool?
    let status: ScoreKeepMigrationEvidenceStatus
    let diagnosticCodes: [String]

    static func initial(operationIdentity: ScoreKeepMigrationOperationIdentity, storeIdentity: String) -> ScoreKeepMigrationEvidenceRecord {
        ScoreKeepMigrationEvidenceRecord(
            operationIdentity: operationIdentity,
            storeIdentity: storeIdentity,
            sourceClassification: nil,
            sourcePreserved: false,
            constructionDisposition: nil,
            verificationPassed: nil,
            status: .none,
            diagnosticCodes: []
        )
    }
}

enum ScoreKeepMigrationEvidenceError: Error, Equatable {
    case evidenceMissing
    case phaseRegression(from: ScoreKeepMigrationEvidenceStatus, to: ScoreKeepMigrationEvidenceStatus)
    case conflictingOperationReuse
    case conflictingStoreIdentity
}

protocol ScoreKeepMigrationOperationEvidenceAuthority {
    func evidence(for operationIdentity: ScoreKeepMigrationOperationIdentity) throws -> ScoreKeepMigrationEvidenceRecord?
    func currentEvidence(forStoreIdentity storeIdentity: String) throws -> ScoreKeepMigrationEvidenceRecord?
    func beginPreflight(operationIdentity: ScoreKeepMigrationOperationIdentity, storeIdentity: String) throws
    func recordSourceClassification(_ classification: ScoreKeepSourceStoreClassification, operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordSourcePreservationStatus(_ preserved: Bool, operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordMigrationAttempt(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordContainerConstructionResult(_ disposition: ScoreKeepProposedContainerConstructionDisposition, operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordPostOpenVerificationResult(_ passed: Bool, operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordCompletion(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordSafeFailure(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordUncertainCompletion(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordRecoveryRequirement(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
    func recordDisableState(operationIdentity: ScoreKeepMigrationOperationIdentity) throws
}

enum ScoreKeepMigrationEvidenceStorageAssessment: String, CaseIterable, Hashable, Sendable {
    case recommendedStorageDesign
    case splitPreOpenAndPostOpenEvidenceDesign
    case furtherProofRequired
    case noSafeProductionDesignSelected

    static let current: ScoreKeepMigrationEvidenceStorageAssessment = .splitPreOpenAndPostOpenEvidenceDesign
}

enum ScoreKeepMigrationReconciliationDisposition: String, CaseIterable, Hashable, Sendable {
    case safeToStart
    case safeToResumeWithSameIdentity
    case safeToVerifyWithoutRepeatingMigration
    case retryRequiresFreshSourceCopy
    case retryProhibited
    case completionProven
    case completionUncertain
    case recoveryRequired
    case reviewRequired
    case unsupported
}

enum ScoreKeepMigrationReconciler {
    static func reconcile(
        sourceClassification: ScoreKeepSourceStoreClassification,
        evidence: ScoreKeepMigrationEvidenceRecord?,
        targetReadable: Bool = true,
        disableActivated: Bool = false
    ) -> ScoreKeepMigrationReconciliationDisposition {
        guard disableActivated == false else { return .reviewRequired }
        guard sourceClassification.isSupportedForProposedV2Startup else { return .unsupported }
        guard let evidence else { return .safeToStart }
        guard targetReadable else {
            return evidence.status == .completed ? .completionUncertain : .retryRequiresFreshSourceCopy
        }

        switch evidence.status {
        case .none:
            return .safeToStart
        case .preflightBegan, .sourceClassified, .sourcePreserved:
            return .safeToResumeWithSameIdentity
        case .migrationAttempted, .containerConstructionRecorded:
            return .safeToVerifyWithoutRepeatingMigration
        case .postOpenVerificationRecorded:
            return evidence.verificationPassed == true ? .safeToVerifyWithoutRepeatingMigration : .reviewRequired
        case .completed:
            return .completionProven
        case .failedSafely:
            return .retryRequiresFreshSourceCopy
        case .completionUncertain:
            return .completionUncertain
        case .recoveryRequired:
            return .recoveryRequired
        case .disabled:
            return .reviewRequired
        }
    }
}
