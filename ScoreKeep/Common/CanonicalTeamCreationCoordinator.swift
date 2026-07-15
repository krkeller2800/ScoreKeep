import Foundation

typealias CanonicalTeamCreationTransactionExecutor = @Sendable (CanonicalTeamCreationOperationalRequest) async -> CanonicalTeamCreationTransactionResult

actor CanonicalTeamCreationCoordinator {
    private let evidenceStore: CanonicalTeamCreationOperationEvidenceStore
    private let executor: CanonicalTeamCreationTransactionExecutor
    private var inFlightByOperation: [CanonicalTeamCreationOperationIdentity: InFlightOperationRequest] = [:]
    private var inFlightByTeam: [UUID: InFlightTeamRequest] = [:]

    init(
        evidenceStore: CanonicalTeamCreationOperationEvidenceStore,
        executor: @escaping CanonicalTeamCreationTransactionExecutor
    ) {
        self.evidenceStore = evidenceStore
        self.executor = executor
    }

    func submit(
        _ request: CanonicalTeamCreationOperationalRequest,
        readiness: CanonicalTeamCreationWriteReadinessSnapshot
    ) async -> CanonicalTeamCreationOperationalResult {
        let fingerprint = request.semanticFingerprint

        guard request.operationIdentity.isValid else {
            return Self.blockedResult(
                request: request,
                disposition: .validationRejected,
                retry: .retryBlockedByConflict,
                proof: .noProof,
                codes: [.operationIdentityMissing]
            )
        }

        guard readiness.permitsBoundedWrite else {
            return Self.blockedResult(
                request: request,
                disposition: readiness.blockDisposition,
                retry: readiness.disableStateActive ? .reviewRequiredBeforeRetry : .retryBlockedByMigrationOrSourceState,
                proof: .noProof,
                codes: readiness.disableStateActive ? [.adapterDisabled] : [.writeGateBlocked]
            )
        }

        if let operationRequest = inFlightByOperation[request.operationIdentity] {
            if operationRequest.fingerprint != fingerprint {
                return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.operationIdentityConflict])
            }
            return await operationRequest.task.value
        }

        if let teamRequest = inFlightByTeam[request.teamIdentity] {
            if teamRequest.fingerprint == fingerprint {
                return await teamRequest.task.value
            }
            return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.teamIdentityConflict])
        }

        let preparedEvidence = CanonicalTeamCreationOperationEvidence(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: fingerprint
        )

        let task = Task { [evidenceStore, executor] in
            if let existing = await evidenceStore.evidence(for: request.operationIdentity) {
                if existing.requestFingerprint != preparedEvidence.requestFingerprint {
                    return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.operationIdentityConflict])
                }
                if let reconciled = Self.result(for: existing, request: request) {
                    return reconciled
                }
            }

            let teamEvidence = await evidenceStore.evidenceForTeam(request.teamIdentity)
            if let conflicting = teamEvidence.first(where: { $0.requestFingerprint != preparedEvidence.requestFingerprint && $0.phase != .failedSafely }) {
                return Self.result(for: conflicting.advanced(to: .conflicting, proof: .conflictingEvidence), request: request)
                    ?? Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.teamIdentityConflict])
            }
            if let matchingCompleted = teamEvidence.first(where: { $0.requestFingerprint == preparedEvidence.requestFingerprint && $0.completionProof.provesOperationCompletion }) {
                return Self.result(for: matchingCompleted.advanced(to: .completed, disposition: .existingMatchingTeam), request: request)
                    ?? Self.blockedResult(request: request, disposition: .existingMatchingTeam, retry: .retryUnnecessaryCompletionProven, proof: .completionMarkerRecorded, codes: [.previousCompletionProven])
            }

            let conflict = await evidenceStore.begin(preparedEvidence)
            switch conflict {
            case .none:
                break
            case .sameOperationDifferentRequest:
                return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.operationIdentityConflict])
            case .sameTeamDifferentMeaning:
                return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.teamIdentityConflict])
            case .uncertainPriorCompletion:
                return Self.blockedResult(request: request, disposition: .completionUncertain, retry: .retryProhibitedCompletionUncertain, proof: .completionUncertain, codes: [.previousCompletionUncertain])
            case .inProgress:
                return Self.blockedResult(request: request, disposition: .operationAlreadyInProgress, retry: .retryBlockedWhileInProgress, proof: .noProof, codes: [.operationInProgress])
            }

            await evidenceStore.advance(preparedEvidence.advanced(to: .inProgress, retry: .retryBlockedWhileInProgress))
            await evidenceStore.advance(preparedEvidence.advanced(to: .saveAttempted, retry: .retryBlockedWhileInProgress))
            let transactionResult = await executor(request)
            let operationalResult = CanonicalTeamCreationCoordinator.map(transactionResult, request: request)
            let completionEvidence = preparedEvidence.advanced(
                to: CanonicalTeamCreationCoordinator.evidencePhase(for: operationalResult),
                proof: operationalResult.completionProof,
                disposition: operationalResult.disposition,
                retry: operationalResult.retryClassification,
                reviewRequired: operationalResult.workflowOutcome.userReviewRequired,
                adding: operationalResult.diagnosticCodes.first
            )

            switch operationalResult.disposition {
            case .createdAndVerified, .existingMatchingTeam, .duplicateRequestCompleted:
                await evidenceStore.markCompletionProven(completionEvidence)
            case .completionUncertain, .internalVerificationFailure:
                await evidenceStore.markCompletionUncertain(completionEvidence)
            case .saveFailedSafely, .validationRejected:
                await evidenceStore.markSafeFailure(completionEvidence)
            default:
                await evidenceStore.advance(completionEvidence)
            }

            return operationalResult
        }

        inFlightByOperation[request.operationIdentity] = InFlightOperationRequest(fingerprint: fingerprint, task: task)
        inFlightByTeam[request.teamIdentity] = InFlightTeamRequest(fingerprint: fingerprint, task: task)
        let result = await task.value
        inFlightByOperation[request.operationIdentity] = nil
        inFlightByTeam[request.teamIdentity] = nil
        return result
    }

    private func reconcileExistingEvidence(
        _ preparedEvidence: CanonicalTeamCreationOperationEvidence,
        request: CanonicalTeamCreationOperationalRequest
    ) async -> CanonicalTeamCreationOperationalResult? {
        if let existing = await evidenceStore.evidence(for: request.operationIdentity) {
            if existing.requestFingerprint != preparedEvidence.requestFingerprint {
                return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.operationIdentityConflict])
            }
            return Self.result(for: existing, request: request)
        }

        let teamEvidence = await evidenceStore.evidenceForTeam(request.teamIdentity)
        if let conflicting = teamEvidence.first(where: { $0.requestFingerprint != preparedEvidence.requestFingerprint && $0.phase != .failedSafely }) {
            return Self.result(for: conflicting.advanced(to: .conflicting, proof: .conflictingEvidence), request: request)
        }
        if let matchingCompleted = teamEvidence.first(where: { $0.requestFingerprint == preparedEvidence.requestFingerprint && $0.completionProof.provesOperationCompletion }) {
            return Self.result(for: matchingCompleted.advanced(to: .completed, disposition: .existingMatchingTeam), request: request)
        }
        return nil
    }

    private static func result(
        for evidence: CanonicalTeamCreationOperationEvidence,
        request: CanonicalTeamCreationOperationalRequest
    ) -> CanonicalTeamCreationOperationalResult? {
        switch evidence.phase {
        case .completed where evidence.completionProof.provesOperationCompletion,
             .persistedTeamVerified where evidence.completionProof.provesOperationCompletion:
            return Self.blockedResult(request: request, disposition: evidence.finalDisposition == .existingMatchingTeam ? .existingMatchingTeam : .duplicateRequestCompleted, retry: .retryUnnecessaryCompletionProven, proof: evidence.completionProof, codes: [.previousCompletionProven])
        case .saveOutcomeUncertain, .failedWithUncertainCompletion, .reviewRequired,
             .completed, .persistedTeamVerified:
            return Self.blockedResult(request: request, disposition: .completionUncertain, retry: .retryProhibitedCompletionUncertain, proof: .completionUncertain, codes: [.previousCompletionUncertain])
        case .failedSafely:
            return nil
        case .inProgress, .saveAttempted:
            return Self.blockedResult(request: request, disposition: .operationAlreadyInProgress, retry: .retryBlockedWhileInProgress, proof: .noProof, codes: [.operationInProgress])
        case .conflicting:
            return Self.blockedResult(request: request, disposition: .conflictingExistingTeam, retry: .retryBlockedByConflict, proof: .conflictingEvidence, codes: [.teamIdentityConflict])
        case .disabled:
            return Self.blockedResult(request: request, disposition: .adapterDisabled, retry: .reviewRequiredBeforeRetry, proof: .noProof, codes: [.adapterDisabled])
        case .prepared, .rejected, .superseded:
            return nil
        }
    }

    private static func blockedResult(
        request: CanonicalTeamCreationOperationalRequest,
        disposition: CanonicalTeamCreationFinalDisposition,
        retry: CanonicalTeamCreationRetryClassification,
        proof: CanonicalTeamCreationCompletionProof,
        codes: [CanonicalTeamCreationDiagnosticCode]
    ) -> CanonicalTeamCreationOperationalResult {
        CanonicalTeamCreationOperationalResult(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: request.semanticFingerprint,
            disposition: disposition,
            retryClassification: retry,
            completionProof: proof,
            diagnosticCodes: codes,
            executorInvoked: false
        )
    }

    private static func map(
        _ transactionResult: CanonicalTeamCreationTransactionResult,
        request: CanonicalTeamCreationOperationalRequest
    ) -> CanonicalTeamCreationOperationalResult {
        let disposition: CanonicalTeamCreationFinalDisposition
        let retry: CanonicalTeamCreationRetryClassification
        let proof: CanonicalTeamCreationCompletionProof
        let code: CanonicalTeamCreationDiagnosticCode

        switch transactionResult.transaction.disposition {
        case .success, .successWithWarnings:
            disposition = .createdAndVerified
            retry = .retryUnnecessaryCompletionProven
            proof = .completionMarkerRecorded
            code = .executorCompletionProven
        case .duplicateAlreadyApplied:
            disposition = transactionResult.idempotencyResult == .matchingExistingDifferentOperation ? .existingMatchingTeam : .duplicateRequestCompleted
            retry = .retryUnnecessaryCompletionProven
            proof = .operationEvidenceAndSemanticTeamMatchObserved
            code = .previousCompletionProven
        case .validationRejected:
            disposition = .validationRejected
            retry = transactionResult.retryIsSafe ? .retryPermittedSameOperationIdentity : .retryBlockedByConflict
            proof = .noProof
            code = .executorValidationRejected
        case .saveFailed:
            if transactionResult.retryIsSafe {
                disposition = .saveFailedSafely
                retry = .retryPermittedSameOperationIdentity
                proof = .noProof
                code = .executorSaveFailedSafely
            } else {
                disposition = .completionUncertain
                retry = .retryProhibitedCompletionUncertain
                proof = .completionUncertain
                code = .executorCompletionUncertain
            }
        case .partialOrUncertainOutcome, .interruptedOperation:
            disposition = .completionUncertain
            retry = .retryProhibitedCompletionUncertain
            proof = .completionUncertain
            code = .executorCompletionUncertain
        case .contradictory, .relationshipFailure, .orderingFailure:
            disposition = .conflictingExistingTeam
            retry = .retryBlockedByConflict
            proof = .conflictingEvidence
            code = .internalVerificationFailure
        case .staleProjection, .mediaFailure, .unresolved, .unsupported, .retryUnsafe:
            disposition = .internalVerificationFailure
            retry = .reviewRequiredBeforeRetry
            proof = .completionUncertain
            code = .internalVerificationFailure
        case .noChange, .recoveryAvailable, .retrySafe:
            disposition = .saveFailedSafely
            retry = .retryPermittedSameOperationIdentity
            proof = .noProof
            code = .safeFailureRetryPermitted
        }

        return CanonicalTeamCreationOperationalResult(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: request.semanticFingerprint,
            disposition: disposition,
            retryClassification: retry,
            completionProof: proof,
            diagnosticCodes: [code],
            executorInvoked: true
        )
    }

    private static func evidencePhase(for result: CanonicalTeamCreationOperationalResult) -> CanonicalTeamCreationOperationPhase {
        switch result.disposition {
        case .createdAndVerified, .existingMatchingTeam, .duplicateRequestCompleted:
            return .completed
        case .validationRejected:
            return .rejected
        case .conflictingExistingTeam:
            return .conflicting
        case .saveFailedSafely:
            return .failedSafely
        case .completionUncertain, .internalVerificationFailure:
            return .failedWithUncertainCompletion
        case .adapterDisabled:
            return .disabled
        case .operationAlreadyInProgress:
            return .inProgress
        case .storeNotWritable, .migrationIncomplete, .reviewRequired, .none:
            return .reviewRequired
        }
    }
}

private struct InFlightOperationRequest {
    let fingerprint: CanonicalTeamCreationSemanticRequestFingerprint
    let task: Task<CanonicalTeamCreationOperationalResult, Never>
}

private struct InFlightTeamRequest {
    let fingerprint: CanonicalTeamCreationSemanticRequestFingerprint
    let task: Task<CanonicalTeamCreationOperationalResult, Never>
}

private func === (lhs: Task<CanonicalTeamCreationOperationalResult, Never>, rhs: Task<CanonicalTeamCreationOperationalResult, Never>) -> Bool {
    ObjectIdentifier(lhs as AnyObject) == ObjectIdentifier(rhs as AnyObject)
}
