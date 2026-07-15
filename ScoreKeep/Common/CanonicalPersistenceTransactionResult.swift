import Foundation

/// Non-routed Phase 3 vocabulary for future baseball persistence transaction outcomes.
enum CanonicalPersistenceTransactionDisposition: String, CaseIterable, Hashable, Sendable {
    case success
    case successWithWarnings
    case noChange
    case duplicateAlreadyApplied
    case validationRejected
    case saveFailed
    case partialOrUncertainOutcome
    case staleProjection
    case relationshipFailure
    case orderingFailure
    case mediaFailure
    case interruptedOperation
    case recoveryAvailable
    case retrySafe
    case retryUnsafe
    case unsupported
    case contradictory
    case unresolved
}

enum CanonicalPersistenceRetrySafety: String, Hashable, Sendable {
    case notNeeded
    case safe
    case unsafe
    case unknown
}

struct CanonicalPersistenceTransactionResult: Hashable, Sendable {
    let disposition: CanonicalPersistenceTransactionDisposition
    let findings: [CanonicalValidationFinding]
    let operationIdentity: String?
    let affectedRecordIdentities: [String]
    let priorAcceptedStateRemainsUsable: Bool
    let retrySafety: CanonicalPersistenceRetrySafety
    let explicitReloadRequired: Bool
    let repairOrReviewRequired: Bool
    let workflowMayContinue: Bool
    let allowanceOrEntitlementMustRemainUnchanged: Bool
    let saveCompletionProven: Bool
    let resultUncertainBecauseSaveCompletionCannotBeProven: Bool

    var retryIsSafe: Bool { retrySafety == .safe || disposition == .retrySafe }
    var retryIsUnsafe: Bool { retrySafety == .unsafe || disposition == .retryUnsafe }
    var recoveryIsAvailable: Bool { disposition == .recoveryAvailable || repairOrReviewRequired || explicitReloadRequired }

    init(
        disposition: CanonicalPersistenceTransactionDisposition,
        findings: [CanonicalValidationFinding] = [],
        operationIdentity: String? = nil,
        affectedRecordIdentities: [String] = [],
        priorAcceptedStateRemainsUsable: Bool,
        retrySafety: CanonicalPersistenceRetrySafety,
        explicitReloadRequired: Bool,
        repairOrReviewRequired: Bool,
        workflowMayContinue: Bool,
        allowanceOrEntitlementMustRemainUnchanged: Bool = true,
        saveCompletionProven: Bool,
        resultUncertainBecauseSaveCompletionCannotBeProven: Bool = false
    ) {
        self.disposition = disposition
        self.findings = findings.sorted { lhs, rhs in
            if lhs.code != rhs.code { return lhs.code < rhs.code }
            return lhs.summary < rhs.summary
        }
        self.operationIdentity = operationIdentity
        self.affectedRecordIdentities = affectedRecordIdentities.sorted()
        self.priorAcceptedStateRemainsUsable = priorAcceptedStateRemainsUsable
        self.retrySafety = retrySafety
        self.explicitReloadRequired = explicitReloadRequired
        self.repairOrReviewRequired = repairOrReviewRequired
        self.workflowMayContinue = workflowMayContinue
        self.allowanceOrEntitlementMustRemainUnchanged = allowanceOrEntitlementMustRemainUnchanged
        self.saveCompletionProven = saveCompletionProven
        self.resultUncertainBecauseSaveCompletionCannotBeProven = resultUncertainBecauseSaveCompletionCannotBeProven
    }
}

enum CanonicalPersistenceTransactionClassifier {
    static func success(operationIdentity: String? = nil, affectedRecordIdentities: [String] = []) -> CanonicalPersistenceTransactionResult {
        result(.success, operationIdentity: operationIdentity, affectedRecordIdentities: affectedRecordIdentities, priorUsable: true, retry: .notNeeded, reload: false, repair: false, continueWorkflow: true, saveProven: true)
    }

    static func successWithWarnings(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.successWithWarnings, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .notNeeded, reload: false, repair: false, continueWorkflow: true, saveProven: true)
    }

    static func noChange(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.noChange, operationIdentity: operationIdentity, priorUsable: true, retry: .notNeeded, reload: false, repair: false, continueWorkflow: true, saveProven: true)
    }

    static func duplicateAlreadyApplied(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.duplicateAlreadyApplied, operationIdentity: operationIdentity, priorUsable: true, retry: .notNeeded, reload: false, repair: false, continueWorkflow: true, saveProven: true)
    }

    static func validationRejected(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.validationRejected, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: false, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func saveFailed(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.saveFailed, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unknown, reload: true, repair: true, continueWorkflow: false, saveProven: false, uncertain: true)
    }

    static func partialOrUncertainOutcome(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.partialOrUncertainOutcome, findings: findings, operationIdentity: operationIdentity, priorUsable: false, retry: .unknown, reload: true, repair: true, continueWorkflow: false, saveProven: false, uncertain: true)
    }

    static func staleProjection(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.staleProjection, operationIdentity: operationIdentity, priorUsable: true, retry: .safe, reload: true, repair: false, continueWorkflow: false, saveProven: true)
    }

    static func relationshipFailure(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.relationshipFailure, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: true, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func orderingFailure(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.orderingFailure, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: true, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func mediaFailure(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.mediaFailure, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .safe, reload: false, repair: true, continueWorkflow: true, saveProven: true)
    }

    static func interruptedOperation(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.interruptedOperation, operationIdentity: operationIdentity, priorUsable: true, retry: .unknown, reload: true, repair: true, continueWorkflow: false, saveProven: false, uncertain: true)
    }

    static func recoveryAvailable(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.recoveryAvailable, operationIdentity: operationIdentity, priorUsable: true, retry: .safe, reload: true, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func retrySafe(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.retrySafe, operationIdentity: operationIdentity, priorUsable: true, retry: .safe, reload: false, repair: false, continueWorkflow: true, saveProven: true)
    }

    static func retryUnsafe(operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.retryUnsafe, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: true, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func unsupported(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.unsupported, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: false, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func contradictory(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.contradictory, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: true, repair: true, continueWorkflow: false, saveProven: true)
    }

    static func unresolved(_ findings: [CanonicalValidationFinding], operationIdentity: String? = nil) -> CanonicalPersistenceTransactionResult {
        result(.unresolved, findings: findings, operationIdentity: operationIdentity, priorUsable: true, retry: .unsafe, reload: false, repair: true, continueWorkflow: false, saveProven: true)
    }

    private static func result(
        _ disposition: CanonicalPersistenceTransactionDisposition,
        findings: [CanonicalValidationFinding] = [],
        operationIdentity: String? = nil,
        affectedRecordIdentities: [String] = [],
        priorUsable: Bool,
        retry: CanonicalPersistenceRetrySafety,
        reload: Bool,
        repair: Bool,
        continueWorkflow: Bool,
        saveProven: Bool,
        uncertain: Bool = false
    ) -> CanonicalPersistenceTransactionResult {
        CanonicalPersistenceTransactionResult(
            disposition: disposition,
            findings: findings,
            operationIdentity: operationIdentity,
            affectedRecordIdentities: affectedRecordIdentities,
            priorAcceptedStateRemainsUsable: priorUsable,
            retrySafety: retry,
            explicitReloadRequired: reload,
            repairOrReviewRequired: repair,
            workflowMayContinue: continueWorkflow,
            saveCompletionProven: saveProven,
            resultUncertainBecauseSaveCompletionCannotBeProven: uncertain
        )
    }
}
