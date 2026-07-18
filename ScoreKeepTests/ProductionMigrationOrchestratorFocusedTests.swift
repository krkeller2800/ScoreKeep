import Foundation
import SwiftData
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Migration orchestrator disposable integration")
struct ScoreKeepMigrationOrchestratorTests {
    @Test("orchestrator preserves unsupported unversioned source and fails closed before V3 construction")
    func orchestratorPreservesUnsupportedUnversionedSourceAndFailsClosedBeforeV3Construction() throws {
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

        #expect(result.disposition == .constructionFailed)
        #expect(result.journal.phase == .failedSafely)
        #expect(result.journal.containerConstructionDisposition == .unsafe)
        #expect(result.recoveryRequirement == .discardIncompleteDisposableTarget)
        #expect(result.diagnostics == [.proposedContainerConstructionFailed])
        #expect(result.writeReadiness.permitsBaseballWrites == false)
        #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == originalSourceFingerprint)
        #expect(result.container == nil)
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

    @Test("factory failures and blocked hosted verification classify recovery without write readiness")
    func factoryFailuresAndBlockedHostedVerificationClassifyRecoveryWithoutWriteReadiness() throws {
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

        let blockedHostedVerification = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-e",
                postOpenVerifier: { _ in false }
            ),
            journalStore: try journalStore()
        )
        #expect(blockedHostedVerification.disposition == .constructionFailed)
        #expect(blockedHostedVerification.journal.recoveryRequirement == .writesRemainProhibited)
        #expect(blockedHostedVerification.journal.containerConstructionDisposition == .unsafe)
        #expect(blockedHostedVerification.diagnostics == [.proposedContainerConstructionFailed])
        #expect(blockedHostedVerification.writeReadiness.permitsBaseballWrites == false)
    }

    @Test("source preservation failure carries sanitized backup verification identity")
    func sourcePreservationFailureCarriesSanitizedBackupVerificationIdentity() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let result = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: try storeURL(fileName: "Different.store"),
                targetURL: try storeURL(),
                journalStoreIdentity: "orchestrator-source-preservation-diagnostic"
            ),
            journalStore: try journalStore()
        )

        #expect(result.disposition == .sourcePreservationFailed)
        #expect(result.journal.phase == .recoveryRequired)
        #expect(result.recoveryRequirement == .writesRemainProhibited)
        #expect(result.failureDiagnosticIdentity == "backupVerificationFailed.memberInventoryMismatch")
        #expect(result.failureDiagnosticIdentity?.contains("/") == false)
        #expect(result.writeReadiness.permitsBaseballWrites == false)
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

            if unsupportedUnversionedConstructionAlreadyReached(at: point) {
                #expect(result.disposition == .constructionFailed)
                #expect(result.journal.containerConstructionDisposition == .unsafe)
            } else {
                #expect(result.disposition == .interrupted)
            }
            let freshLoad = journalStore.load()
            #expect(freshLoad.record?.operationIdentity == result.journal.operationIdentity)
            #expect(ScoreKeepMigrationOrchestrator.reconcile(freshLoad.record) != .noRecoveryRequired)
            #expect(result.writeReadiness.permitsBaseballWrites == false)
        }
    }

    @Test("retry resumes from verified backup with same operation identity and no duplicate backup")
    func retryResumesFromVerifiedBackupWithSameOperationIdentityAndNoDuplicateBackup() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let journalStore = try journalStore()
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        let identity = "resume-verified-backup"
        let interrupted = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                interruptionPoint: .afterBackupVerification
            ),
            journalStore: journalStore
        )
        let backupIdentity = interrupted.journal.backupIdentity

        let resumed = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity
            ),
            journalStore: journalStore
        )

        #expect(interrupted.disposition == .interrupted)
        #expect(ScoreKeepMigrationOrchestrator.reconcile(interrupted.journal) == .reuseVerifiedBackup)
        #expect(resumed.disposition == .constructionFailed)
        #expect(resumed.journal.operationIdentity == interrupted.journal.operationIdentity)
        #expect(resumed.journal.backupIdentity == backupIdentity)
        #expect(resumed.journal.phase == .failedSafely)
        #expect(resumed.journal.containerConstructionDisposition == .unsafe)
        #expect(resumed.writeReadiness.permitsBaseballWrites == false)
    }

    private func unsupportedUnversionedConstructionAlreadyReached(at point: ScoreKeepMigrationInterruptionPoint) -> Bool {
        switch point {
        case .afterContainerConstructionReturns, .afterPostOpenVerificationStarts, .afterPostOpenVerificationPasses,
             .afterCompletionRecordingStarts, .afterCompletionRecordingSucceeds, .afterOwnershipFinalization:
            return true
        case .afterJournalCreation, .afterDisableStateResolution, .afterOwnershipClaim,
             .afterSourceClassification, .afterBackupCopyStart, .afterBackupCopyCompletion,
             .afterBackupVerification, .afterMigrationAttemptRecording, .afterContainerConstructionBegins:
            return false
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

    private func storeURL(fileName: String = "ScoreKeep.store") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepMigrationOrchestratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
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
