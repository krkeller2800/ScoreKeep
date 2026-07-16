import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@Suite("Team creation operational coordinator")
struct CanonicalTeamCreationCoordinatorTests {
    @Test("matching simultaneous requests execute once", .timeLimit(.minutes(1)))
    func matchingSimultaneousRequestsExecuteOnce() async throws {
        let harness = try await CoordinatorHarness(delayNanoseconds: 50_000_000)
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()

        async let first = harness.coordinator.submit(request, readiness: .authorized)
        async let second = harness.coordinator.submit(request, readiness: .authorized)
        let results = await [first, second]
        let count = await harness.executor.count

        let dispositions = Set(results.map { $0.disposition })
        let allExecutorInvoked = results.allSatisfy { $0.executorInvoked }
        #expect(count == 1)
        #expect(dispositions == [.createdAndVerified])
        #expect(allExecutorInvoked)
    }

    @Test("conflicting simultaneous requests with same operation do not both execute")
    func conflictingSimultaneousRequestsWithSameOperationDoNotBothExecute() async throws {
        let harness = try await CoordinatorHarness(delayNanoseconds: 50_000_000)
        let firstRequest = IsolatedTeamCreationOperationEvidenceSupport.request(teamName: "First Meaning")
        let secondRequest = IsolatedTeamCreationOperationEvidenceSupport.request(teamName: "Second Meaning")

        async let first = harness.coordinator.submit(firstRequest, readiness: .authorized)
        async let second = harness.coordinator.submit(secondRequest, readiness: .authorized)
        let results = await [first, second]
        let count = await harness.executor.count

        #expect(count == 1)
        #expect(results.contains { $0.disposition == .createdAndVerified })
        #expect(results.contains { $0.disposition == .conflictingExistingTeam })
    }

    @Test("same team with different operations and matching meaning executes once")
    func sameTeamWithDifferentOperationsAndMatchingMeaningExecutesOnce() async throws {
        let harness = try await CoordinatorHarness(delayNanoseconds: 50_000_000)
        let first = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "op-001")
        let second = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "op-002")

        async let firstResult = harness.coordinator.submit(first, readiness: .authorized)
        async let secondResult = harness.coordinator.submit(second, readiness: .authorized)
        let results = await [firstResult, secondResult]
        let count = await harness.executor.count

        #expect(count == 1)
        #expect(results.allSatisfy { $0.disposition == .createdAndVerified })
    }

    @Test("same team with different operations and conflicting meaning executes once")
    func sameTeamWithDifferentOperationsAndConflictingMeaningExecutesOnce() async throws {
        let harness = try await CoordinatorHarness(delayNanoseconds: 50_000_000)
        let first = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "op-001", teamName: "First Meaning")
        let second = IsolatedTeamCreationOperationEvidenceSupport.request(operationIdentity: "op-002", teamName: "Second Meaning")

        async let firstResult = harness.coordinator.submit(first, readiness: .authorized)
        async let secondResult = harness.coordinator.submit(second, readiness: .authorized)
        let results = await [firstResult, secondResult]
        let count = await harness.executor.count

        #expect(count == 1)
        #expect(results.contains { $0.disposition == .createdAndVerified })
        #expect(results.contains { $0.disposition == .conflictingExistingTeam })
    }

    @Test("repeat during in progress request resolves to first result")
    func repeatDuringInProgressRequestResolvesToFirstResult() async throws {
        let harness = try await CoordinatorHarness(delayNanoseconds: 50_000_000)
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()

        async let first = harness.coordinator.submit(request, readiness: .authorized)
        async let second = harness.coordinator.submit(request, readiness: .authorized)
        let results = await [first, second]

        #expect(await harness.executor.count == 1)
        #expect(results[0].disposition == .createdAndVerified)
        #expect(results[1].disposition == .createdAndVerified)
    }

    @Test("repeat after completion returns proven duplicate without executor")
    func repeatAfterCompletionReturnsProvenDuplicateWithoutExecutor() async throws {
        let harness = try await CoordinatorHarness()
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let first = await harness.coordinator.submit(request, readiness: .authorized)
        let second = await harness.coordinator.submit(request, readiness: .authorized)

        #expect(first.disposition == .createdAndVerified)
        #expect(second.disposition == .duplicateRequestCompleted)
        #expect(second.executorInvoked == false)
        #expect(await harness.executor.count == 1)
    }

    @Test("repeat after safe failure permits same operation retry")
    func repeatAfterSafeFailurePermitsSameOperationRetry() async throws {
        let harness = try await CoordinatorHarness(results: [.saveFailedSafe, .success])
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let failed = await harness.coordinator.submit(request, readiness: .authorized)
        let retry = await harness.coordinator.submit(request, readiness: .authorized)

        #expect(failed.disposition == .saveFailedSafely)
        #expect(failed.retryClassification == .retryPermittedSameOperationIdentity)
        #expect(retry.disposition == .createdAndVerified)
        #expect(await harness.executor.count == 2)
    }

    @Test("repeat after uncertain completion blocks blind retry")
    func repeatAfterUncertainCompletionBlocksBlindRetry() async throws {
        let harness = try await CoordinatorHarness(results: [.uncertain, .success])
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let uncertain = await harness.coordinator.submit(request, readiness: .authorized)
        let retry = await harness.coordinator.submit(request, readiness: .authorized)

        #expect(uncertain.disposition == .completionUncertain)
        #expect(retry.disposition == .completionUncertain)
        #expect(retry.retryClassification == .retryProhibitedCompletionUncertain)
        #expect(retry.executorInvoked == false)
        #expect(await harness.executor.count == 1)
    }

    @Test("coordinator recreation reconciles preserved evidence")
    func coordinatorRecreationReconcilesPreservedEvidence() async throws {
        let directory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let firstExecutor = ExecutionRecorder(results: [.success])
        let firstCoordinator = try await coordinator(directory: directory, executor: firstExecutor)
        _ = await firstCoordinator.submit(request, readiness: .authorized)

        let secondExecutor = ExecutionRecorder(results: [.success])
        let secondCoordinator = try await coordinator(directory: directory, executor: secondExecutor)
        let repeated = await secondCoordinator.submit(request, readiness: .authorized)

        #expect(repeated.disposition == .duplicateRequestCompleted)
        #expect(repeated.executorInvoked == false)
        #expect(await firstExecutor.count == 1)
        #expect(await secondExecutor.count == 0)
    }

    @Test("simulated relaunch with preserved evidence blocks uncertain retry")
    func simulatedRelaunchWithPreservedEvidenceBlocksUncertainRetry() async throws {
        let directory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let firstExecutor = ExecutionRecorder(results: [.uncertain])
        let firstCoordinator = try await coordinator(directory: directory, executor: firstExecutor)
        _ = await firstCoordinator.submit(request, readiness: .authorized)

        let relaunchedExecutor = ExecutionRecorder(results: [.success])
        let relaunchedCoordinator = try await coordinator(directory: directory, executor: relaunchedExecutor)
        let retry = await relaunchedCoordinator.submit(request, readiness: .authorized)

        #expect(retry.disposition == .completionUncertain)
        #expect(retry.executorInvoked == false)
        #expect(await relaunchedExecutor.count == 0)
    }

    @Test("write gate blocks executor when not explicitly ready")
    func writeGateBlocksExecutorWhenNotExplicitlyReady() async throws {
        let harness = try await CoordinatorHarness()
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()
        let blocked = await harness.coordinator.submit(request, readiness: .writeReadyForIsolatedVerification)
        let disabled = await harness.coordinator.submit(request, readiness: .disabled)

        #expect(blocked.disposition == .storeNotWritable)
        #expect(blocked.executorInvoked == false)
        #expect(disabled.disposition == .adapterDisabled)
        #expect(disabled.executorInvoked == false)
        #expect(await harness.executor.count == 0)
    }

    @MainActor
    @Test("existing transaction adapter can remain an injected isolated executor")
    func existingTransactionAdapterCanRemainInjectedIsolatedExecutor() async throws {
        let environment = try IsolatedPersistenceEnvironment()
        let storeDirectory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let evidenceStore = try IsolatedTeamCreationOperationEvidenceSupport.store(at: storeDirectory)
        let adapter = IsolatedTeamCreationTransactionSupport.adapter(for: environment)
        let coordinator = CanonicalTeamCreationCoordinator(evidenceStore: evidenceStore) { request in
            await MainActor.run {
                let adapterRequest = IsolatedTeamCreationTransactionSupport.request(
                    operationIdentity: request.operationIdentity.rawValue,
                    teamIdentity: request.teamIdentity,
                    teamName: request.teamName,
                    coach: request.coach,
                    details: request.details
                )
                return adapter.apply(adapterRequest, in: ModelContext(environment.container))
            }
        }
        let request = IsolatedTeamCreationOperationEvidenceSupport.request()

        let result = await coordinator.submit(request, readiness: .authorized)
        let snapshot = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(result.disposition == .createdAndVerified)
        #expect(snapshot.teams[request.teamIdentity]?.name == request.teamName)
    }

    @Test("current route is legacy and production sources do not call coordinator")
    func currentRouteIsLegacyAndProductionSourcesDoNotCallCoordinator() throws {
        let teamView = try source(named: "ScoreKeep/List Data/TeamView.swift")
        let teamContentView = try source(named: "ScoreKeep/Content Views/TeamContentView.swift")
        let contentView = try source(named: "ScoreKeep/Content Views/ContentView.swift")
        let productionSources = [teamView, teamContentView, contentView]

        #expect(CanonicalTeamCreationRouteChoice.currentNamedTeamCreation == .legacyWriterActive)
        #expect(teamView.contains("modelContext.insert(theTeam)"))
        #expect(productionSources.allSatisfy { !$0.contains("CanonicalTeamCreationCoordinator") })
        #expect(productionSources.allSatisfy { !$0.contains("CanonicalTeamCreationOperationalRequest") })
    }

    private func coordinator(directory: URL, executor: ExecutionRecorder) async throws -> CanonicalTeamCreationCoordinator {
        let store = try IsolatedTeamCreationOperationEvidenceSupport.store(at: directory)
        return CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await executor.execute(request)
        }
    }

    private func source(named relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }
}

private struct CoordinatorHarness {
    let directory: URL
    let executor: ExecutionRecorder
    let coordinator: CanonicalTeamCreationCoordinator

    init(delayNanoseconds: UInt64 = 0, results: [ExecutionRecorder.ResultKind] = [.success]) async throws {
        let createdDirectory = try IsolatedTeamCreationOperationEvidenceSupport.storeDirectory()
        let createdExecutor = ExecutionRecorder(delayNanoseconds: delayNanoseconds, results: results)
        let store = try IsolatedTeamCreationOperationEvidenceSupport.store(at: createdDirectory)
        let createdCoordinator = CanonicalTeamCreationCoordinator(evidenceStore: store) { request in
            await createdExecutor.execute(request)
        }
        directory = createdDirectory
        executor = createdExecutor
        coordinator = createdCoordinator
    }
}

actor ExecutionRecorder {
    enum ResultKind: Sendable {
        case success
        case saveFailedSafe
        case uncertain
    }

    private let delayNanoseconds: UInt64
    private var results: [ResultKind]
    private var requests: [CanonicalTeamCreationOperationalRequest] = []

    init(delayNanoseconds: UInt64 = 0, results: [ResultKind] = [.success]) {
        self.delayNanoseconds = delayNanoseconds
        self.results = results
    }

    var count: Int { requests.count }

    func execute(_ request: CanonicalTeamCreationOperationalRequest) async -> CanonicalTeamCreationTransactionResult {
        requests.append(request)
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        let kind = results.isEmpty ? .success : results.removeFirst()
        switch kind {
        case .success:
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request)
        case .saveFailedSafe:
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request, disposition: .saveFailed, retrySafety: .safe, saveProven: false)
        case .uncertain:
            return IsolatedTeamCreationOperationEvidenceSupport.transactionResult(for: request, disposition: .partialOrUncertainOutcome, retrySafety: .unknown, saveProven: false, uncertain: true)
        }
    }
}

private extension CanonicalTeamCreationWriteReadinessSnapshot {
    static let authorized = CanonicalTeamCreationWriteReadinessSnapshot(
        storeOpenedSuccessfully: true,
        sourceVersionState: .supportedCurrent,
        migrationState: .complete,
        cutoverApprovalPresent: true
    )

    static let disabled = CanonicalTeamCreationWriteReadinessSnapshot(
        storeOpenedSuccessfully: true,
        sourceVersionState: .supportedCurrent,
        migrationState: .complete,
        cutoverApprovalPresent: true,
        disableStateActive: true
    )
}

enum TeamCreationCoordinatorTestError: Error {
    case repositoryRootNotFound
}
