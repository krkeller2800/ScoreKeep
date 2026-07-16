import Foundation
import SwiftData
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Migration orchestrator disposable integration")
struct ScoreKeepMigrationOrchestratorTests {
    @Test("orchestrator preserves source migrates target and records sidecar completion")
    func orchestratorPreservesSourceMigratesTargetAndRecordsSidecarCompletion() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.representative)
        let originalSourceFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url)
        let journalStore = try journalStore()
        let backupURL = try storeURL()
        let targetURL = try storeURL()

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: "orchestrator-source-a"
            ),
            journalStore: journalStore
        )

        #expect(result.disposition == .completed)
        #expect(result.journal.phase == .completionRecorded)
        #expect(result.journal.completionDisposition == "sidecarCompletionRecorded")
        #expect(result.writeReadiness.permitsBaseballWrites == false)
        #expect(result.writeReadiness.blockingReasons.contains("routeNotActive"))
        #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == originalSourceFingerprint)
        let migrated = try #require(result.container)
        #expect(try IsolatedUnversionedProductionStoreSupport.snapshot(from: migrated, fixtureIdentity: UnversionedStoreScenario.representative.rawValue) == source.snapshot)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: migrated) == 0)
    }

    @Test("disable state and ownership conflicts prohibit orchestration")
    func disableStateAndOwnershipConflictsProhibitOrchestration() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let disabledResult = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-b",
                disableState: .proposedTransitionPreparedButDisabled,
                authorizationEvidence: nil
            ),
            journalStore: try journalStore()
        )
        #expect(disabledResult.disposition == .disabled)
        #expect(disabledResult.writeReadiness.permitsBaseballWrites == false)

        let ownershipJournalStore = try journalStore()
        var record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operationIdentity(storeIdentity: "orchestrator-source-c"),
            sourceStoreDiagnosticIdentity: "orchestrator-source-c",
            sourceClassification: .populatedCurrentUnversionedStore,
            disableState: .proposedTransitionExplicitlyAuthorized
        )
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .preflightStarted, startupOwnership: .legacyContainerSelected)
        try ownershipJournalStore.save(record)

        let conflictResult = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-c"
            ),
            journalStore: ownershipJournalStore
        )
        #expect(conflictResult.disposition == .ownershipConflict)
        #expect(conflictResult.journal.startupOwnership == .conflictingOwners)
    }

    @Test("factory and verification failures classify recovery without write readiness")
    func factoryAndVerificationFailuresClassifyRecoveryWithoutWriteReadiness() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let factoryFailure = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-d",
                factoryInjection: .containerConstructionFailure
            ),
            journalStore: try journalStore()
        )
        #expect(factoryFailure.disposition == .constructionFailed)
        #expect(factoryFailure.journal.phase == .failedSafely)
        #expect(factoryFailure.diagnostics == [.proposedContainerConstructionFailed])
        #expect(factoryFailure.writeReadiness.permitsBaseballWrites == false)

        let verificationFailure = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-e",
                postOpenVerifier: { _ in false }
            ),
            journalStore: try journalStore()
        )
        #expect(verificationFailure.disposition == .verificationFailed)
        #expect(verificationFailure.journal.recoveryRequirement == .verifyExistingTarget)
        #expect(verificationFailure.diagnostics == [.postOpenVerificationFailed])
        #expect(verificationFailure.writeReadiness.permitsBaseballWrites == false)
    }

    @Test("interruption points reconcile deterministically with same operation identity")
    func interruptionPointsReconcileDeterministicallyWithSameOperationIdentity() throws {
        for point in ScoreKeepMigrationInterruptionPoint.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
            let journalStore = try journalStore()
            let result = try ScoreKeepMigrationOrchestrator.run(
                input: input(
                    source: source,
                    backupURL: try storeURL(),
                    targetURL: try storeURL(),
                    journalStoreIdentity: "interrupt-\(point.rawValue)",
                    interruptionPoint: point
                ),
                journalStore: journalStore
            )

            #expect(result.disposition == .interrupted)
            let freshLoad = journalStore.load()
            #expect(freshLoad.record?.operationIdentity == result.journal.operationIdentity)
            #expect(ScoreKeepMigrationOrchestrator.reconcile(freshLoad.record) != .noRecoveryRequired || point == .afterCompletionRecordingSucceeds || point == .afterOwnershipFinalization)
            #expect(result.writeReadiness.permitsBaseballWrites == false)
        }
    }

    private func input(
        source: (url: URL, snapshot: UnversionedStoreSnapshot),
        backupURL: URL,
        targetURL: URL,
        journalStoreIdentity: String,
        disableState: ScoreKeepSchemaRouteDisableState = .proposedTransitionExplicitlyAuthorized,
        authorizationEvidence: String? = "local-explicit-test-authorization",
        interruptionPoint: ScoreKeepMigrationInterruptionPoint? = nil,
        factoryInjection: ScoreKeepProposedContainerFactoryInjection? = nil,
        postOpenVerifier: ((ModelContainer) throws -> Bool)? = nil
    ) -> ScoreKeepMigrationOrchestratorInput {
        ScoreKeepMigrationOrchestratorInput(
            operationIdentity: operationIdentity(storeIdentity: journalStoreIdentity),
            sourceStoreURL: source.url,
            backupStoreURL: backupURL,
            targetStoreURL: targetURL,
            sourceClassification: .populatedCurrentUnversionedStore,
            disableState: disableState,
            authorizationEvidence: authorizationEvidence,
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: interruptionPoint,
            factoryInjection: factoryInjection,
            semanticRestoreVerifier: { restoreURL in
                let restored = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: restoreURL)
                let restoredSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: restored, fixtureIdentity: source.snapshot.fixtureIdentity)
                return restoredSnapshot == source.snapshot
            },
            postOpenVerifier: postOpenVerifier ?? { container in
                let snapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: container, fixtureIdentity: source.snapshot.fixtureIdentity)
                return snapshot == source.snapshot
            }
        )
    }

    private func journalStore() throws -> ScoreKeepMigrationJournalStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepMigrationOrchestratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("journal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ScoreKeepMigrationJournalStore(directory: directory)
    }

    private func storeURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepMigrationOrchestratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ScoreKeep.store")
    }

    private func operationIdentity(storeIdentity: String) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: storeIdentity,
            sourceSchema: .populatedCurrentUnversionedStore,
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000008101")!
        )
    }
}
#endif
