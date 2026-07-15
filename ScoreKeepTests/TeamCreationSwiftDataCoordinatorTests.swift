import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation SwiftData evidence coordinator")
struct TeamCreationSwiftDataCoordinatorTests {
    @Test("matching concurrent requests execute at most once and survive coordinator recreation")
    func matchingConcurrentRequestsExecuteAtMostOnceAndSurviveCoordinatorRecreation() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let counter = TeamCreationExecutorCounter()
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let coordinator = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await counter.increment()
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        }
        let readiness = readySnapshot()

        async let first = coordinator.submit(request, readiness: readiness)
        async let second = coordinator.submit(request, readiness: readiness)
        let results = await [first, second]

        #expect(await counter.value == 1)
        #expect(results.allSatisfy { $0.disposition == .createdAndVerified })

        let recreated = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await counter.increment()
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        }
        let repeated = await recreated.submit(request, readiness: readiness)

        #expect(repeated.disposition == .duplicateRequestCompleted)
        #expect(repeated.executorInvoked == false)
        #expect(await counter.value == 1)
    }

    @Test("conflicting operation and uncertain evidence block blind execution after relaunch")
    func conflictingOperationAndUncertainEvidenceBlockBlindExecutionAfterRelaunch() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let counter = TeamCreationExecutorCounter()
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "uncertain-op")
        await store.markCompletionUncertain(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request))
        let coordinator = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await counter.increment()
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        }

        let uncertain = await coordinator.submit(request, readiness: readySnapshot())
        let conflicting = await coordinator.submit(IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "uncertain-op", teamName: "Changed"), readiness: readySnapshot())

        #expect(uncertain.disposition == .completionUncertain)
        #expect(uncertain.executorInvoked == false)
        #expect(conflicting.disposition == .conflictingExistingTeam)
        #expect(conflicting.executorInvoked == false)
        #expect(await counter.value == 0)
    }

    @Test("same team competing operations do not duplicate accepted execution")
    func sameTeamCompetingOperationsDoNotDuplicateAcceptedExecution() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let counter = TeamCreationExecutorCounter()
        let firstRequest = IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "same-team-op-1")
        let secondRequest = IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "same-team-op-2")
        let coordinator = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await counter.increment()
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        }

        async let first = coordinator.submit(firstRequest, readiness: readySnapshot())
        async let second = coordinator.submit(secondRequest, readiness: readySnapshot())
        let results = await [first, second]

        #expect(await counter.value == 1)
        #expect(results.allSatisfy { $0.disposition == .createdAndVerified })
        #expect(results.allSatisfy { $0.teamIdentity == firstRequest.teamIdentity })
        #expect(await store.evidenceForTeam(firstRequest.teamIdentity).count == 1)
    }

    @Test("safe failure permits same operation retry only")
    func safeFailurePermitsSameOperationRetryOnly() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let counter = TeamCreationExecutorCounter()
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "safe-failure-op")
        await store.markSafeFailure(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request))
        let coordinator = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await counter.increment()
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        }

        let result = await coordinator.submit(request, readiness: readySnapshot())

        #expect(result.executorInvoked)
        #expect(result.disposition == .createdAndVerified)
        #expect(await counter.value == 1)
    }

    private func readySnapshot() -> CanonicalTeamCreationWriteReadinessSnapshot {
        CanonicalTeamCreationWriteReadinessSnapshot(
            storeOpenedSuccessfully: true,
            sourceVersionState: .supportedCurrent,
            migrationState: .complete,
            cutoverApprovalPresent: true
        )
    }
}

private actor TeamCreationExecutorCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
