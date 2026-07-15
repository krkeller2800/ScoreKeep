import Foundation

enum TeamCreationOperationTransitionPolicy {
    static func canAdvance(from current: CanonicalTeamCreationOperationPhase, to next: CanonicalTeamCreationOperationPhase) -> Bool {
        if current == next { return true }
        if isTerminal(current) { return false }

        switch (current, next) {
        case (.prepared, .inProgress),
             (.prepared, .failedSafely),
             (.prepared, .reviewRequired),
             (.inProgress, .saveAttempted),
             (.inProgress, .failedSafely),
             (.inProgress, .failedWithUncertainCompletion),
             (.inProgress, .reviewRequired),
             (.saveAttempted, .saveOutcomeUncertain),
             (.saveAttempted, .persistedTeamVerified),
             (.saveAttempted, .completed),
             (.saveAttempted, .failedSafely),
             (.saveAttempted, .failedWithUncertainCompletion),
             (.saveAttempted, .reviewRequired),
             (.saveOutcomeUncertain, .reviewRequired),
             (.persistedTeamVerified, .completed),
             (.failedSafely, .prepared):
            return true
        default:
            return next == .reviewRequired || next == .conflicting
        }
    }

    static func isTerminal(_ phase: CanonicalTeamCreationOperationPhase) -> Bool {
        switch phase {
        case .completed, .conflicting, .disabled, .superseded:
            return true
        case .prepared, .inProgress, .saveAttempted, .saveOutcomeUncertain, .persistedTeamVerified, .rejected, .failedSafely, .failedWithUncertainCompletion, .reviewRequired:
            return false
        }
    }
}

struct TeamCreationObservedTeam: Hashable, Sendable {
    let identity: UUID
    let name: String
    let coach: String
    let details: String
}

enum TeamCreationOperationReconciliationOutcome: String, CaseIterable, Hashable, Sendable {
    case noPriorEvidence
    case preparedWithNoTeam
    case safeFailureWithNoTeam
    case teamAndEvidenceMatchCompletionNotFinalized
    case teamAndCompletedEvidenceMatch
    case teamExistsWithConflictingSemanticMeaning
    case completedEvidenceExistsButTeamMissing
    case evidenceIsUncertain
    case evidenceFingerprintConflicts
    case duplicateTeamRecordsExist
    case reviewRequired
    case retryProhibited
    case safeRetry
}

struct TeamCreationOperationReconciliationInput: Hashable, Sendable {
    let request: CanonicalTeamCreationOperationalRequest
    let evidence: [CanonicalTeamCreationOperationEvidence]
    let teams: [TeamCreationObservedTeam]
}

enum TeamCreationOperationReconciler {
    static func reconcile(_ input: TeamCreationOperationReconciliationInput) -> TeamCreationOperationReconciliationOutcome {
        let matchingOperation = input.evidence.first { $0.operationIdentity == input.request.operationIdentity }
        let matchingTeams = input.teams.filter { $0.identity == input.request.teamIdentity }

        if matchingTeams.count > 1 { return .duplicateTeamRecordsExist }

        guard let evidence = matchingOperation else {
            if let team = matchingTeams.first {
                return teamMatchesRequest(team, request: input.request) ? .reviewRequired : .teamExistsWithConflictingSemanticMeaning
            }
            return .noPriorEvidence
        }

        guard evidence.requestFingerprint == input.request.semanticFingerprint else {
            return .evidenceFingerprintConflicts
        }

        if evidence.reviewRequired || evidence.phase == .reviewRequired || evidence.phase == .conflicting {
            return .reviewRequired
        }

        if evidence.phase == .failedWithUncertainCompletion || evidence.phase == .saveOutcomeUncertain || evidence.completionProof == .completionUncertain {
            return .evidenceIsUncertain
        }

        if evidence.phase == .failedSafely && matchingTeams.isEmpty {
            return .safeFailureWithNoTeam
        }

        guard let team = matchingTeams.first else {
            if evidence.completionProof.provesOperationCompletion || evidence.phase == .completed {
                return .completedEvidenceExistsButTeamMissing
            }
            return evidence.phase == .prepared ? .preparedWithNoTeam : .safeRetry
        }

        guard teamMatchesRequest(team, request: input.request) else {
            return .teamExistsWithConflictingSemanticMeaning
        }

        if evidence.phase == .completed && evidence.completionProof.provesOperationCompletion {
            return .teamAndCompletedEvidenceMatch
        }

        return .teamAndEvidenceMatchCompletionNotFinalized
    }

    private static func teamMatchesRequest(_ team: TeamCreationObservedTeam, request: CanonicalTeamCreationOperationalRequest) -> Bool {
        team.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == request.approvedComparableTeamName
        && team.coach.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == request.approvedComparableCoach
        && team.details.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == request.approvedComparableDetails
    }
}

enum TeamCreationOperationRetentionClassification: String, CaseIterable, Hashable, Sendable {
    case active
    case uncertain
    case reviewRequired
    case completedRecently
    case completedEligibleForFutureCleanup
    case failedSafelyEligibleForFutureCleanup
    case mustRetainUnresolvedReconciliation
    case mustRetainConflict
    case neverDeleteAutomaticallyDuringRead
}

enum TeamCreationOperationRetentionPolicy {
    static func classification(for evidence: CanonicalTeamCreationOperationEvidence) -> TeamCreationOperationRetentionClassification {
        if evidence.reviewRequired || evidence.phase == .reviewRequired { return .reviewRequired }
        if evidence.phase == .conflicting || evidence.completionProof == .conflictingEvidence { return .mustRetainConflict }
        if evidence.phase == .saveOutcomeUncertain || evidence.phase == .failedWithUncertainCompletion || evidence.completionProof == .completionUncertain { return .uncertain }
        if evidence.phase == .completed { return .completedRecently }
        if evidence.phase == .failedSafely { return .failedSafelyEligibleForFutureCleanup }
        return .active
    }
}

enum TeamCreationCrashWindowClassification: String, CaseIterable, Hashable, Sendable {
    case beforeAnySaveSafeRetry
    case preparedOnlySafeRetry
    case teamInsertedBeforeSaveSafeRetry
    case duringSaveCompletionUncertain
    case afterSaveBeforeReloadCompletionUncertain
    case afterReloadBeforeCompletionUpdateReconciliationRequired
    case afterCompletionUpdateCompleted
    case preparedEvidenceOnRelaunchSafeRetry
    case saveAttemptedOnRelaunchCompletionUncertain
    case teamPresentIncompleteEvidenceReconciliationRequired
    case evidenceCompleteTeamPresentCompleted
    case evidenceCompleteTeamMissingReviewRequired
    case teamPresentEvidenceMissingReviewRequired
}
