import Foundation
import Testing
@testable import ScoreKeep

@Suite("Team creation operational safety vocabulary")
struct CanonicalTeamCreationOperationalSafetyTests {
    @Test("operation identity is stable and distinct from team identity")
    func operationIdentityIsStableAndDistinctFromTeamIdentity() {
        let request = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: " team-create-op-001 ")

        #expect(request.operationIdentity.rawValue == "team-create-op-001")
        #expect(request.operationIdentity.rawValue != request.teamIdentity.uuidString)
        #expect(request.operationIdentity.rawValue != request.teamName)
    }

    @Test("semantic fingerprint is deterministic conflict detecting and locale independent")
    func semanticFingerprintIsDeterministicConflictDetectingAndLocaleIndependent() {
        let request = IsolatedTeamCreationOperationEvidenceSupport.request(teamName: "  Isolated Falcons  ", options: ["b": "2", "a": "1"])
        let matching = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "other-op", teamName: "isolated falcons", options: ["a": "1", "b": "2"])
        let conflicting = IsolatedTeamCreationOperationEvidenceSupport.request(teamName: "Isolated Hawks", options: ["a": "1", "b": "2"])
        let first = request.semanticFingerprint
        let second = request.semanticFingerprint

        #expect(first == second)
        #expect(first == matching.semanticFingerprint)
        #expect(first != conflicting.semanticFingerprint)
        #expect(first.rawValue.contains(request.operationIdentity.rawValue) == false)
        #expect(first.rawValue.contains(request.teamIdentity.uuidString.lowercased()))
    }

    @Test("fingerprint calculation leaves input unchanged")
    func fingerprintCalculationLeavesInputUnchanged() {
        let request = IsolatedTeamCreationOperationEvidenceSupport.request(teamName: "  Isolated Falcons  ", coach: "  Coach One  ")
        let original = request
        _ = request.semanticFingerprint

        #expect(request == original)
    }

    @Test("evidence phases include required operation states")
    func evidencePhasesIncludeRequiredOperationStates() {
        let phases = Set(CanonicalTeamCreationOperationPhase.allCases)

        #expect(phases.contains(.prepared))
        #expect(phases.contains(.inProgress))
        #expect(phases.contains(.saveAttempted))
        #expect(phases.contains(.saveOutcomeUncertain))
        #expect(phases.contains(.persistedTeamVerified))
        #expect(phases.contains(.completed))
        #expect(phases.contains(.rejected))
        #expect(phases.contains(.conflicting))
        #expect(phases.contains(.failedSafely))
        #expect(phases.contains(.failedWithUncertainCompletion))
        #expect(phases.contains(.reviewRequired))
        #expect(phases.contains(.disabled))
        #expect(phases.contains(.superseded))
    }

    @Test("completion proof distinguishes team existence from operation proof")
    func completionProofDistinguishesTeamExistenceFromOperationProof() {
        #expect(CanonicalTeamCreationCompletionProof.teamExistenceObserved.provesOperationCompletion == false)
        #expect(CanonicalTeamCreationCompletionProof.semanticTeamMatchObserved.provesOperationCompletion == false)
        #expect(CanonicalTeamCreationCompletionProof.operationEvidenceAndSemanticTeamMatchObserved.provesOperationCompletion == false)
        #expect(CanonicalTeamCreationCompletionProof.completionMarkerRecorded.provesOperationCompletion)
        #expect(CanonicalTeamCreationCompletionProof.conflictingEvidence.provesOperationCompletion == false)
        #expect(CanonicalTeamCreationCompletionProof.completionUncertain.provesOperationCompletion == false)
    }

    @Test("test evidence store begins advances and preserves completion classifications")
    func testEvidenceStoreBeginsAdvancesAndPreservesCompletionClassifications() async throws {
        let directory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let store = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let evidence = IsolatedTeamCreationOperationEvidenceSupport.evidence(for: request)

        #expect(await store.begin(evidence) == .none)
        await store.advance(evidence.advanced(to: .inProgress))
        await store.markCompletionProven(evidence.advanced(to: .persistedTeamVerified))
        let reloaded = try await #require(store.evidence(for: request.operationIdentity))

        #expect(reloaded.phase == .completed)
        #expect(reloaded.completionProof == .completionMarkerRecorded)
        #expect(reloaded.retryClassification == .retryUnnecessaryCompletionProven)
    }

    @Test("safe failure uncertain completion and conflicting reuse are durable")
    func safeFailureUncertainCompletionAndConflictingReuseAreDurable() async throws {
        let directory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let store = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        let safeFailure = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "safe-failure-op")
        let uncertain = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "uncertain-op", teamIdentity: TeamCreationTransactionVerificationIDs.conflictingTeam)
        let conflict = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "safe-failure-op", teamName: "Changed")

        await store.markSafeFailure(IsolatedTeamCreationOperationEvidenceSupport.evidence(for: safeFailure))
        await store.markCompletionUncertain(IsolatedTeamCreationOperationEvidenceSupport.evidence(for: uncertain))

        let reloadedStore = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        let safeFailureReloaded = try await #require(reloadedStore.evidence(for: safeFailure.operationIdentity))
        let uncertainReloaded = try await #require(reloadedStore.evidence(for: uncertain.operationIdentity))
        let conflictingEvidence = IsolatedTeamCreationOperationEvidenceSupport.evidence(for: conflict)

        #expect(safeFailureReloaded.phase == .failedSafely)
        #expect(safeFailureReloaded.retryClassification == .retryPermittedSameOperationIdentity)
        #expect(uncertainReloaded.phase == .failedWithUncertainCompletion)
        #expect(uncertainReloaded.retryClassification == .retryProhibitedCompletionUncertain)
        #expect(await reloadedStore.detectConflictingReuse(conflictingEvidence) == .sameOperationDifferentRequest)
    }

    @Test("cross instance and simulated relaunch preserve operation evidence")
    func crossInstanceAndSimulatedRelaunchPreserveOperationEvidence() async throws {
        let directory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let first = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        await first.markCompletionProven(IsolatedTeamCreationOperationEvidenceSupport.evidence(for: request))

        let second = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        let thirdAfterRelaunch = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)

        #expect(await second.evidence(for: request.operationIdentity)?.completionProof == .completionMarkerRecorded)
        #expect(await thirdAfterRelaunch.evidence(for: request.operationIdentity)?.phase == .completed)
    }

    @Test("write readiness blocks unsafe source migration and disable states")
    func writeReadinessBlocksUnsafeSourceMigrationAndDisableStates() {
        let ready = CanonicalTeamCreationWriteReadinessSnapshot.writeReadyForIsolatedVerification
        let unknownSource = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .unknown, migrationState: .complete, cutoverApprovalPresent: true)
        let unsupportedFuture = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .unsupportedFuture, migrationState: .complete, cutoverApprovalPresent: true)
        let inProgress = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .inProgress, cutoverApprovalPresent: true)
        let interrupted = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .interrupted, cutoverApprovalPresent: true)
        let uncertain = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .completionUncertain, cutoverApprovalPresent: true)
        let recovery = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .recoveryRequired, cutoverApprovalPresent: true)
        let readOnly = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .complete, readOnlyAccessOnly: true, cutoverApprovalPresent: true)
        let approvalAbsent = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .complete)
        let disabled = CanonicalTeamCreationWriteReadinessSnapshot(storeOpenedSuccessfully: true, sourceVersionState: .supportedCurrent, migrationState: .complete, cutoverApprovalPresent: true, disableStateActive: true)

        #expect(ready.permitsBoundedWrite == false)
        #expect(unknownSource.permitsBoundedWrite == false)
        #expect(unsupportedFuture.permitsBoundedWrite == false)
        #expect(inProgress.permitsBoundedWrite == false)
        #expect(interrupted.permitsBoundedWrite == false)
        #expect(uncertain.permitsBoundedWrite == false)
        #expect(recovery.permitsBoundedWrite == false)
        #expect(readOnly.permitsBoundedWrite == false)
        #expect(approvalAbsent.permitsBoundedWrite == false)
        #expect(disabled.permitsBoundedWrite == false)
        #expect(disabled.blockDisposition == .adapterDisabled)
    }

    @Test("explicitly authorized isolated snapshot permits bounded write evaluation")
    func explicitlyAuthorizedIsolatedSnapshotPermitsBoundedWriteEvaluation() {
        let snapshot = CanonicalTeamCreationWriteReadinessSnapshot(
            storeOpenedSuccessfully: true,
            sourceVersionState: .supportedCurrent,
            migrationState: .complete,
            cutoverApprovalPresent: true
        )

        #expect(snapshot.permitsBoundedWrite)
    }

    @Test("route choice remains legacy and disable policy prohibits fallback")
    func routeChoiceRemainsLegacyAndDisablePolicyProhibitsFallback() {
        let route = CanonicalTeamCreationRouteChoice.currentNamedTeamCreation
        let disable = CanonicalTeamCreationDisablePolicy.futureRequired

        #expect(route == .legacyWriterActive)
        #expect(route.productionUsesLegacyWriter)
        #expect(route.adapterIsProductionRouted == false)
        #expect(disable.preventsNewAdapterTransactions)
        #expect(disable.preservesExistingOperationEvidence)
        #expect(disable.allowsUncertainOperationReconciliation)
        #expect(disable.prohibitsDualWriters)
        #expect(disable.prohibitsAutomaticLegacyRetry)
    }

    @Test("workflow outcomes preserve values retry policy and fallback prohibition")
    func workflowOutcomesPreserveValuesRetryPolicyAndFallbackProhibition() {
        let created = CanonicalTeamCreationWorkflowOutcome.policy(for: .createdAndVerified)
        let existing = CanonicalTeamCreationWorkflowOutcome.policy(for: .existingMatchingTeam)
        let duplicate = CanonicalTeamCreationWorkflowOutcome.policy(for: .duplicateRequestCompleted)
        let validation = CanonicalTeamCreationWorkflowOutcome.policy(for: .validationRejected)
        let conflict = CanonicalTeamCreationWorkflowOutcome.policy(for: .conflictingExistingTeam)
        let inProgress = CanonicalTeamCreationWorkflowOutcome.policy(for: .operationAlreadyInProgress)
        let safeFailure = CanonicalTeamCreationWorkflowOutcome.policy(for: .saveFailedSafely)
        let uncertain = CanonicalTeamCreationWorkflowOutcome.policy(for: .completionUncertain)
        let storeBlocked = CanonicalTeamCreationWorkflowOutcome.policy(for: .storeNotWritable)
        let migration = CanonicalTeamCreationWorkflowOutcome.policy(for: .migrationIncomplete)
        let disabled = CanonicalTeamCreationWorkflowOutcome.policy(for: .adapterDisabled)
        let internalFailure = CanonicalTeamCreationWorkflowOutcome.policy(for: .internalVerificationFailure)

        #expect(created.formMayClose)
        #expect(existing.formMayClose)
        #expect(duplicate.formMayClose)
        #expect(validation.enteredValuesMustRemainAvailable)
        #expect(conflict.userReviewRequired)
        #expect(inProgress.newOperationIdentityProhibited)
        #expect(safeFailure.retryMayBeOffered)
        #expect(safeFailure.retryMustReuseSameOperationIdentity)
        #expect(uncertain.retryMayBeOffered == false)
        #expect(uncertain.newOperationIdentityProhibited)
        #expect(storeBlocked.enteredValuesMustRemainAvailable)
        #expect(migration.enteredValuesMustRemainAvailable)
        #expect(disabled.userReviewRequired)
        #expect(internalFailure.userReviewRequired)
        let outcomes = [created, existing, duplicate, validation, conflict, inProgress, safeFailure, uncertain, storeBlocked, migration, disabled, internalFailure]
        let fallbackProhibited = outcomes.allSatisfy { $0.legacyFallbackProhibited }
        #expect(fallbackProhibited)
    }

    @Test("operational safety source has no production persistence purchase or secure storage dependency")
    func operationalSafetySourceHasNoProductionPersistencePurchaseOrSecureStorageDependency() throws {
        let safety = try source(named: "ScoreKeep/Common/CanonicalTeamCreationOperationalSafety.swift")
        let coordinator = try source(named: "ScoreKeep/Common/CanonicalTeamCreationCoordinator.swift")
        let combined = safety + coordinator
        let forbidden = ["SwiftData", "ModelContext", "ModelContainer", "FetchDescriptor", "@Model", "UserDefaults", "AppStorage", "StoreKit", "Keychain", ".insert(", ".delete("]

        #expect(forbidden.allSatisfy { !combined.contains($0) })
    }

    private func source(named relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.last != "ScoreKeepTests" {
            url.deleteLastPathComponent()
            if url.path == "/" { throw TeamCreationOperationalSafetyTestError.repositoryRootNotFound }
        }
        url.deleteLastPathComponent()
        return url
    }
}

enum TeamCreationOperationalSafetyTestError: Error {
    case repositoryRootNotFound
}
