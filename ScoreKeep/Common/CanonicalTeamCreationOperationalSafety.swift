import Foundation

struct CanonicalTeamCreationOperationIdentity: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool { rawValue.isEmpty == false }
    var description: String { rawValue }
}

struct CanonicalTeamCreationSemanticRequestFingerprint: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(request: CanonicalTeamCreationOperationalRequest) {
        let fields = [
            Self.field("teamIdentity", request.teamIdentity.uuidString.lowercased()),
            Self.field("teamName", request.approvedComparableTeamName),
            Self.field("coach", request.approvedComparableCoach),
            Self.field("details", request.approvedComparableDetails),
            Self.field("source", request.source.rawValue)
        ] + request.options.keys.sorted().map { key in
            Self.field("option.\(key)", request.options[key] ?? "")
        }
        rawValue = "team-create-semantic-v1|" + fields.joined(separator: "|")
    }

    var description: String { rawValue }

    private static func field(_ key: String, _ value: String) -> String {
        "\(key)=\(value.utf8.count):\(value)"
    }
}

struct CanonicalTeamCreationOperationalRequest: Hashable, Sendable {
    let operationIdentity: CanonicalTeamCreationOperationIdentity
    let teamIdentity: UUID
    let teamName: String
    let coach: String
    let details: String
    let source: CanonicalTeamCreationSourceClassification
    let options: [String: String]

    init(
        operationIdentity: CanonicalTeamCreationOperationIdentity,
        teamIdentity: UUID,
        teamName: String,
        coach: String = "",
        details: String = "",
        source: CanonicalTeamCreationSourceClassification = .isolatedCandidateAdapter,
        options: [String: String] = [:]
    ) {
        self.operationIdentity = operationIdentity
        self.teamIdentity = teamIdentity
        self.teamName = teamName
        self.coach = coach
        self.details = details
        self.source = source
        self.options = options
    }

    var approvedComparableTeamName: String { normalized(teamName) }
    var approvedComparableCoach: String { normalized(coach) }
    var approvedComparableDetails: String { normalized(details) }
    var semanticFingerprint: CanonicalTeamCreationSemanticRequestFingerprint { CanonicalTeamCreationSemanticRequestFingerprint(request: self) }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum CanonicalTeamCreationOperationPhase: String, CaseIterable, Codable, Hashable, Sendable {
    case prepared
    case inProgress
    case saveAttempted
    case saveOutcomeUncertain
    case persistedTeamVerified
    case completed
    case rejected
    case conflicting
    case failedSafely
    case failedWithUncertainCompletion
    case reviewRequired
    case disabled
    case superseded
}

enum CanonicalTeamCreationCompletionProof: String, CaseIterable, Codable, Hashable, Sendable {
    case noProof
    case teamExistenceObserved
    case semanticTeamMatchObserved
    case operationEvidenceAndSemanticTeamMatchObserved
    case completionMarkerRecorded
    case conflictingEvidence
    case completionUncertain

    var provesOperationCompletion: Bool { self == .completionMarkerRecorded }
}

enum CanonicalTeamCreationFinalDisposition: String, CaseIterable, Codable, Hashable, Sendable {
    case none
    case createdAndVerified
    case existingMatchingTeam
    case duplicateRequestCompleted
    case validationRejected
    case conflictingExistingTeam
    case operationAlreadyInProgress
    case saveFailedSafely
    case completionUncertain
    case storeNotWritable
    case migrationIncomplete
    case adapterDisabled
    case internalVerificationFailure
    case reviewRequired
}

enum CanonicalTeamCreationRetryClassification: String, CaseIterable, Codable, Hashable, Sendable {
    case retryPermittedSameOperationIdentity
    case retryProhibitedCompletionUncertain
    case retryUnnecessaryCompletionProven
    case retryBlockedByConflict
    case retryBlockedByMigrationOrSourceState
    case retryBlockedWhileInProgress
    case reviewRequiredBeforeRetry
    case newIntentRequiresNewOperationIdentity
}

enum CanonicalTeamCreationDiagnosticCode: String, CaseIterable, Codable, Hashable, Sendable {
    case operationIdentityMissing
    case operationIdentityConflict
    case teamIdentityConflict
    case operationInProgress
    case previousCompletionProven
    case previousCompletionUncertain
    case safeFailureRetryPermitted
    case writeGateBlocked
    case adapterDisabled
    case routeLegacyActive
    case executorValidationRejected
    case executorSaveFailedSafely
    case executorCompletionUncertain
    case executorCompletionProven
    case internalVerificationFailure
}

struct CanonicalTeamCreationOperationEvidence: Hashable, Codable, Sendable {
    let operationIdentity: CanonicalTeamCreationOperationIdentity
    let teamIdentity: UUID
    let requestFingerprint: CanonicalTeamCreationSemanticRequestFingerprint
    var phase: CanonicalTeamCreationOperationPhase
    var completionProof: CanonicalTeamCreationCompletionProof
    var finalDisposition: CanonicalTeamCreationFinalDisposition
    var retryClassification: CanonicalTeamCreationRetryClassification
    var reviewRequired: Bool
    var diagnosticCodes: [CanonicalTeamCreationDiagnosticCode]

    init(
        operationIdentity: CanonicalTeamCreationOperationIdentity,
        teamIdentity: UUID,
        requestFingerprint: CanonicalTeamCreationSemanticRequestFingerprint,
        phase: CanonicalTeamCreationOperationPhase = .prepared,
        completionProof: CanonicalTeamCreationCompletionProof = .noProof,
        finalDisposition: CanonicalTeamCreationFinalDisposition = .none,
        retryClassification: CanonicalTeamCreationRetryClassification = .retryBlockedWhileInProgress,
        reviewRequired: Bool = false,
        diagnosticCodes: [CanonicalTeamCreationDiagnosticCode] = []
    ) {
        self.operationIdentity = operationIdentity
        self.teamIdentity = teamIdentity
        self.requestFingerprint = requestFingerprint
        self.phase = phase
        self.completionProof = completionProof
        self.finalDisposition = finalDisposition
        self.retryClassification = retryClassification
        self.reviewRequired = reviewRequired
        self.diagnosticCodes = diagnosticCodes.sorted { $0.rawValue < $1.rawValue }
    }

    func advanced(
        to phase: CanonicalTeamCreationOperationPhase,
        proof: CanonicalTeamCreationCompletionProof? = nil,
        disposition: CanonicalTeamCreationFinalDisposition? = nil,
        retry: CanonicalTeamCreationRetryClassification? = nil,
        reviewRequired: Bool? = nil,
        adding code: CanonicalTeamCreationDiagnosticCode? = nil
    ) -> CanonicalTeamCreationOperationEvidence {
        var updated = self
        updated.phase = phase
        if let proof { updated.completionProof = proof }
        if let disposition { updated.finalDisposition = disposition }
        if let retry { updated.retryClassification = retry }
        if let reviewRequired { updated.reviewRequired = reviewRequired }
        if let code, !updated.diagnosticCodes.contains(code) {
            updated.diagnosticCodes.append(code)
            updated.diagnosticCodes.sort { $0.rawValue < $1.rawValue }
        }
        return updated
    }
}

enum CanonicalTeamCreationEvidenceConflict: String, Hashable, Sendable {
    case none
    case sameOperationDifferentRequest
    case sameTeamDifferentMeaning
    case uncertainPriorCompletion
    case inProgress
}

protocol CanonicalTeamCreationOperationEvidenceStore: Sendable {
    func evidence(for operationIdentity: CanonicalTeamCreationOperationIdentity) async -> CanonicalTeamCreationOperationEvidence?
    func evidenceForTeam(_ teamIdentity: UUID) async -> [CanonicalTeamCreationOperationEvidence]
    func begin(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict
    func advance(_ evidence: CanonicalTeamCreationOperationEvidence) async
    func markCompletionProven(_ evidence: CanonicalTeamCreationOperationEvidence) async
    func markCompletionUncertain(_ evidence: CanonicalTeamCreationOperationEvidence) async
    func markSafeFailure(_ evidence: CanonicalTeamCreationOperationEvidence) async
    func detectConflictingReuse(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict
}

enum CanonicalTeamCreationSourceVersionState: String, CaseIterable, Hashable, Codable, Sendable {
    case supportedCurrent
    case unknown
    case unsupportedFuture
}

enum CanonicalTeamCreationMigrationState: String, CaseIterable, Hashable, Codable, Sendable {
    case notRequired
    case complete
    case inProgress
    case interrupted
    case failed
    case completionUncertain
    case recoveryRequired
}

struct CanonicalTeamCreationWriteReadinessSnapshot: Hashable, Codable, Sendable {
    let storeOpenedSuccessfully: Bool
    let sourceVersionState: CanonicalTeamCreationSourceVersionState
    let migrationState: CanonicalTeamCreationMigrationState
    let readOnlyAccessOnly: Bool
    let writesProhibited: Bool
    let cutoverApprovalPresent: Bool
    let disableStateActive: Bool

    init(
        storeOpenedSuccessfully: Bool,
        sourceVersionState: CanonicalTeamCreationSourceVersionState,
        migrationState: CanonicalTeamCreationMigrationState,
        readOnlyAccessOnly: Bool = false,
        writesProhibited: Bool = false,
        cutoverApprovalPresent: Bool = false,
        disableStateActive: Bool = false
    ) {
        self.storeOpenedSuccessfully = storeOpenedSuccessfully
        self.sourceVersionState = sourceVersionState
        self.migrationState = migrationState
        self.readOnlyAccessOnly = readOnlyAccessOnly
        self.writesProhibited = writesProhibited
        self.cutoverApprovalPresent = cutoverApprovalPresent
        self.disableStateActive = disableStateActive
    }

    static let writeReadyForIsolatedVerification = CanonicalTeamCreationWriteReadinessSnapshot(
        storeOpenedSuccessfully: true,
        sourceVersionState: .supportedCurrent,
        migrationState: .complete
    )

    var permitsBoundedWrite: Bool {
        storeOpenedSuccessfully
        && sourceVersionState == .supportedCurrent
        && (migrationState == .notRequired || migrationState == .complete)
        && !readOnlyAccessOnly
        && !writesProhibited
        && cutoverApprovalPresent
        && !disableStateActive
    }

    var blockDisposition: CanonicalTeamCreationFinalDisposition {
        if disableStateActive { return .adapterDisabled }
        if sourceVersionState != .supportedCurrent || readOnlyAccessOnly || writesProhibited || !storeOpenedSuccessfully { return .storeNotWritable }
        if migrationState != .notRequired && migrationState != .complete { return .migrationIncomplete }
        return .storeNotWritable
    }
}

enum CanonicalTeamCreationRouteChoice: String, CaseIterable, Hashable, Sendable {
    case legacyWriterActive
    case adapterPreparedButDisabled
    case adapterEligibleForIsolatedVerification
    case adapterEligibleForBoundedRoutingAfterExplicitAuthorization
    case adapterTemporarilyDisabled
    case unsafeOrBlocked

    static let currentNamedTeamCreation = CanonicalTeamCreationRouteChoice.legacyWriterActive

    var productionUsesLegacyWriter: Bool { self == .legacyWriterActive }
    var adapterIsProductionRouted: Bool { false }
}

struct CanonicalTeamCreationDisablePolicy: Hashable, Sendable {
    let preventsNewAdapterTransactions: Bool
    let preservesExistingOperationEvidence: Bool
    let allowsUncertainOperationReconciliation: Bool
    let prohibitsDualWriters: Bool
    let prohibitsAutomaticLegacyRetry: Bool
    let laterLegacyRoutingRequiresExplicitOneWriterConfiguration: Bool
    let diagnosable: Bool

    static let futureRequired = CanonicalTeamCreationDisablePolicy(
        preventsNewAdapterTransactions: true,
        preservesExistingOperationEvidence: true,
        allowsUncertainOperationReconciliation: true,
        prohibitsDualWriters: true,
        prohibitsAutomaticLegacyRetry: true,
        laterLegacyRoutingRequiresExplicitOneWriterConfiguration: true,
        diagnosable: true
    )
}

struct CanonicalTeamCreationWorkflowOutcome: Hashable, Sendable {
    let disposition: CanonicalTeamCreationFinalDisposition
    let formMayClose: Bool
    let enteredValuesMustRemainAvailable: Bool
    let retryMayBeOffered: Bool
    let retryMustReuseSameOperationIdentity: Bool
    let newOperationIdentityProhibited: Bool
    let userReviewRequired: Bool
    let legacyFallbackProhibited: Bool

    static func policy(for disposition: CanonicalTeamCreationFinalDisposition) -> CanonicalTeamCreationWorkflowOutcome {
        switch disposition {
        case .createdAndVerified, .existingMatchingTeam, .duplicateRequestCompleted:
            return outcome(disposition, close: true, preserve: false, retry: false, sameOperation: false, prohibitNew: false, review: false)
        case .validationRejected, .conflictingExistingTeam, .operationAlreadyInProgress, .storeNotWritable, .migrationIncomplete, .adapterDisabled, .internalVerificationFailure, .reviewRequired:
            return outcome(disposition, close: false, preserve: true, retry: false, sameOperation: false, prohibitNew: disposition == .operationAlreadyInProgress, review: disposition != .validationRejected && disposition != .operationAlreadyInProgress)
        case .saveFailedSafely:
            return outcome(disposition, close: false, preserve: true, retry: true, sameOperation: true, prohibitNew: true, review: false)
        case .completionUncertain:
            return outcome(disposition, close: false, preserve: true, retry: false, sameOperation: true, prohibitNew: true, review: true)
        case .none:
            return outcome(disposition, close: false, preserve: true, retry: false, sameOperation: false, prohibitNew: false, review: true)
        }
    }

    private static func outcome(
        _ disposition: CanonicalTeamCreationFinalDisposition,
        close: Bool,
        preserve: Bool,
        retry: Bool,
        sameOperation: Bool,
        prohibitNew: Bool,
        review: Bool
    ) -> CanonicalTeamCreationWorkflowOutcome {
        CanonicalTeamCreationWorkflowOutcome(
            disposition: disposition,
            formMayClose: close,
            enteredValuesMustRemainAvailable: preserve,
            retryMayBeOffered: retry,
            retryMustReuseSameOperationIdentity: sameOperation,
            newOperationIdentityProhibited: prohibitNew,
            userReviewRequired: review,
            legacyFallbackProhibited: true
        )
    }
}

struct CanonicalTeamCreationOperationalResult: Hashable, Sendable {
    let operationIdentity: CanonicalTeamCreationOperationIdentity
    let teamIdentity: UUID
    let requestFingerprint: CanonicalTeamCreationSemanticRequestFingerprint
    let disposition: CanonicalTeamCreationFinalDisposition
    let retryClassification: CanonicalTeamCreationRetryClassification
    let completionProof: CanonicalTeamCreationCompletionProof
    let workflowOutcome: CanonicalTeamCreationWorkflowOutcome
    let diagnosticCodes: [CanonicalTeamCreationDiagnosticCode]
    let executorInvoked: Bool

    init(
        operationIdentity: CanonicalTeamCreationOperationIdentity,
        teamIdentity: UUID,
        requestFingerprint: CanonicalTeamCreationSemanticRequestFingerprint,
        disposition: CanonicalTeamCreationFinalDisposition,
        retryClassification: CanonicalTeamCreationRetryClassification,
        completionProof: CanonicalTeamCreationCompletionProof,
        diagnosticCodes: [CanonicalTeamCreationDiagnosticCode],
        executorInvoked: Bool
    ) {
        self.operationIdentity = operationIdentity
        self.teamIdentity = teamIdentity
        self.requestFingerprint = requestFingerprint
        self.disposition = disposition
        self.retryClassification = retryClassification
        self.completionProof = completionProof
        self.workflowOutcome = CanonicalTeamCreationWorkflowOutcome.policy(for: disposition)
        self.diagnosticCodes = diagnosticCodes.sorted { $0.rawValue < $1.rawValue }
        self.executorInvoked = executorInvoked
    }
}
