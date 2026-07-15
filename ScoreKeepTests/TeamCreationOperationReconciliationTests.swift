import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation operation reconciliation")
struct TeamCreationOperationReconciliationTests {
    @Test("reconciliation classifies no evidence prepared safe failure completed missing and duplicates")
    func reconciliationClassifiesNoEvidencePreparedSafeFailureCompletedMissingAndDuplicates() {
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)
        let team = TeamCreationObservedTeam(identity: request.teamIdentity, name: request.teamName, coach: request.coach, details: request.details)

        #expect(reconcile(request, [], []) == .noPriorEvidence)
        #expect(reconcile(request, [evidence], []) == .preparedWithNoTeam)
        #expect(reconcile(request, [evidence.advanced(to: .failedSafely)], []) == .safeFailureWithNoTeam)
        #expect(reconcile(request, [evidence.advanced(to: .saveAttempted)], [team]) == .teamAndEvidenceMatchCompletionNotFinalized)
        #expect(reconcile(request, [evidence.advanced(to: .completed, proof: .completionMarkerRecorded)], [team]) == .teamAndCompletedEvidenceMatch)
        #expect(reconcile(request, [evidence.advanced(to: .completed, proof: .completionMarkerRecorded)], []) == .completedEvidenceExistsButTeamMissing)
        #expect(reconcile(request, [evidence], [team, team]) == .duplicateTeamRecordsExist)
    }

    @Test("reconciliation classifies conflicting semantic meaning fingerprint uncertainty and review")
    func reconciliationClassifiesConflictingSemanticMeaningFingerprintUncertaintyAndReview() {
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)
        let conflictingTeam = TeamCreationObservedTeam(identity: request.teamIdentity, name: "Changed", coach: request.coach, details: request.details)
        let conflictingEvidence = CanonicalTeamCreationOperationEvidence(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: IsolatedVersionedTeamCreationEvidenceSupport.request(teamName: "Changed").semanticFingerprint
        )

        #expect(reconcile(request, [evidence], [conflictingTeam]) == .teamExistsWithConflictingSemanticMeaning)
        #expect(reconcile(request, [conflictingEvidence], []) == .evidenceFingerprintConflicts)
        #expect(reconcile(request, [evidence.advanced(to: .failedWithUncertainCompletion, proof: .completionUncertain)], []) == .evidenceIsUncertain)
        #expect(reconcile(request, [evidence.advanced(to: .reviewRequired, reviewRequired: true)], []) == .reviewRequired)
    }

    @Test("transition retention and crash classifications cover required policy")
    func transitionRetentionAndCrashClassificationsCoverRequiredPolicy() {
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)

        #expect(TeamCreationOperationTransitionPolicy.canAdvance(from: .prepared, to: .inProgress))
        #expect(TeamCreationOperationTransitionPolicy.canAdvance(from: .saveAttempted, to: .prepared) == false)
        #expect(TeamCreationOperationTransitionPolicy.canAdvance(from: .completed, to: .prepared) == false)
        #expect(TeamCreationOperationRetentionPolicy.classification(for: evidence) == .active)
        #expect(TeamCreationOperationRetentionPolicy.classification(for: evidence.advanced(to: .failedWithUncertainCompletion, proof: .completionUncertain)) == .uncertain)
        #expect(TeamCreationOperationRetentionPolicy.classification(for: evidence.advanced(to: .conflicting, proof: .conflictingEvidence)) == .mustRetainConflict)
        #expect(Set(TeamCreationCrashWindowClassification.allCases).contains(.afterReloadBeforeCompletionUpdateReconciliationRequired))
        #expect(Set(TeamCreationCrashWindowClassification.allCases).contains(.teamPresentEvidenceMissingReviewRequired))
    }

    private func reconcile(
        _ request: CanonicalTeamCreationOperationalRequest,
        _ evidence: [CanonicalTeamCreationOperationEvidence],
        _ teams: [TeamCreationObservedTeam]
    ) -> TeamCreationOperationReconciliationOutcome {
        TeamCreationOperationReconciler.reconcile(TeamCreationOperationReconciliationInput(request: request, evidence: evidence, teams: teams))
    }
}
