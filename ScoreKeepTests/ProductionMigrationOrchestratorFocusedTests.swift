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

    @Test("orchestrator migrates copied V3 source to V4 preserving zero backfill")
    func orchestratorMigratesCopiedV3SourceToV4PreservingZeroBackfill() throws {
        let source = try finalizedRepresentativeV3Source(fileName: "V3Source.sqlite")
        let sourceURL = source.url
        let sourceBaseline = source.baseline
        let sourceFamilyDiagnostic = source.family.diagnosticSummary(sourceURL: sourceURL)
        #expect(source.family.directoryIsReadable, "Disposable V3 source directory is not readable. \(sourceFamilyDiagnostic)")
        #expect(source.family.directoryIsWritable, "Disposable V3 source directory is not writable. \(sourceFamilyDiagnostic)")
        #expect(source.family.primary.exists, "Disposable V3 source primary is missing. \(sourceFamilyDiagnostic)")
        #expect((source.family.primary.size ?? 0) > 0, "Disposable V3 source primary is empty. \(sourceFamilyDiagnostic)")
        let sourceBefore = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: sourceURL)
        let journalStore = try journalStore()
        let backupURL = try storeURL(fileName: sourceURL.lastPathComponent)
        let targetURL = try storeURL(fileName: sourceURL.lastPathComponent)

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: ScoreKeepMigrationOrchestratorInput(
                operationIdentity: operationIdentity(storeIdentity: "orchestrator-v3-to-v4", source: .existingProposedV3Store, target: .proposedV4),
                sourceStoreURL: sourceURL,
                backupStoreURL: backupURL,
                targetStoreURL: targetURL,
                sourceClassification: .existingProposedV3Store,
                disableState: .proposedTransitionExplicitlyAuthorized,
                authorizationEvidence: "local-explicit-test-authorization",
                sourceClosureEvidence: .closedForDisposableVerification,
                interruptionPoint: nil,
                factoryInjection: nil,
                semanticRestoreVerifier: { restoreURL in
                    let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
                    let configuration = ModelConfiguration("OrchestratorV3Restore", url: restoreURL, allowsSave: false)
                    let container = try ModelContainer(for: schema, configurations: [configuration])
                    let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                    return baselineSemanticsMatch(record, sourceBaseline)
                },
                postOpenVerifier: { container in
                    let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                    return baselineSemanticsMatch(record, sourceBaseline)
                }
            ),
            journalStore: journalStore
        )

        #expect(result.disposition == .completed)
        #expect(result.journal.phase == .completionRecorded)
        #expect(result.journal.operationIdentity.targetSchema == .proposedV4)
        #expect(result.journal.containerConstructionDisposition == .openedCompatibleSourceAndTransitionedToProposedV4)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL).sourceClassification == .existingProposedV4Store)
        #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: sourceURL) == sourceBefore)
        #expect(result.container != nil)
        if let container = result.container {
            let migratedBaseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
            #expect(migratedBaseline.legacyScoringOperationEvidenceCount == 0)
        }
    }

    private func finalizedRepresentativeV3Source(fileName: String) throws -> FinalizedV3Source {
        let sourceURL = try storeURL(fileName: fileName)
        let baseline: ScoreKeepMigrationBaselineRecord
        do {
            let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
            let configuration = ModelConfiguration("OrchestratorV3Source", url: sourceURL, allowsSave: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: context)
            try context.save()
            baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: context)
        }
        return FinalizedV3Source(
            url: sourceURL,
            baseline: baseline,
            family: try V3SourceFamilyState(sourceURL: sourceURL)
        )
    }

    private struct FinalizedV3Source {
        let url: URL
        let baseline: ScoreKeepMigrationBaselineRecord
        let family: V3SourceFamilyState
    }

    private struct V3SourceFamilyState {
        let primary: Member
        let wal: Member
        let shm: Member
        let directoryIsReadable: Bool
        let directoryIsWritable: Bool

        init(sourceURL: URL) throws {
            let fileManager = FileManager.default
            let directory = sourceURL.deletingLastPathComponent()
            primary = try Member(url: sourceURL)
            wal = try Member(url: directory.appendingPathComponent("\(sourceURL.lastPathComponent)-wal"))
            shm = try Member(url: directory.appendingPathComponent("\(sourceURL.lastPathComponent)-shm"))
            directoryIsReadable = fileManager.isReadableFile(atPath: directory.path)
            directoryIsWritable = Self.verifyWritableDirectory(directory, fileManager: fileManager)
        }

        func diagnosticSummary(sourceURL: URL) -> String {
            "source=\(sourceURL.path); family=[\(primary.summary), \(wal.summary), \(shm.summary)]"
        }

        private static func verifyWritableDirectory(_ directory: URL, fileManager: FileManager) -> Bool {
            let probe = directory.appendingPathComponent(".scorekeep-v3-source-write-probe-\(UUID().uuidString)")
            do {
                try Data([0x01]).write(to: probe)
                try fileManager.removeItem(at: probe)
                return true
            } catch {
                try? fileManager.removeItem(at: probe)
                return false
            }
        }

        struct Member {
            let name: String
            let exists: Bool
            let size: UInt64?

            init(url: URL) throws {
                name = url.lastPathComponent
                let fileManager = FileManager.default
                exists = fileManager.fileExists(atPath: url.path)
                if exists {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    size = (attributes[.size] as? NSNumber)?.uint64Value
                } else {
                    size = nil
                }
            }

            var summary: String {
                "\(name):exists=\(exists):size=\(size.map(String.init) ?? "nil")"
            }
        }
    }

    private func baselineSemanticsMatch(_ lhs: ScoreKeepMigrationBaselineRecord, _ rhs: ScoreKeepMigrationBaselineRecord) -> Bool {
        lhs.gameCount == rhs.gameCount
            && lhs.teamCount == rhs.teamCount
            && lhs.playerCount == rhs.playerCount
            && lhs.lineupCount == rhs.lineupCount
            && lhs.atbatCount == rhs.atbatCount
            && lhs.pitcherCount == rhs.pitcherCount
            && lhs.teamCreationOperationEvidenceCount == rhs.teamCreationOperationEvidenceCount
            && lhs.canonicalHistoryCount == rhs.canonicalHistoryCount
            && lhs.canonicalEventCount == rhs.canonicalEventCount
            && lhs.canonicalPayloadCount == rhs.canonicalPayloadCount
            && lhs.canonicalOperationCount == rhs.canonicalOperationCount
            && lhs.canonicalCorrectionCount == rhs.canonicalCorrectionCount
            && lhs.legacyScoringOperationEvidenceCount == rhs.legacyScoringOperationEvidenceCount
            && lhs.stableIdentityFingerprint == rhs.stableIdentityFingerprint
            && lhs.relationshipFingerprint == rhs.relationshipFingerprint
            && lhs.orderingFingerprint == rhs.orderingFingerprint
            && lhs.scoreEvidence == rhs.scoreEvidence
            && lhs.substitutionEvidence == rhs.substitutionEvidence
            && lhs.mediaOwnershipFingerprint == rhs.mediaOwnershipFingerprint
    }

    private func unsupportedUnversionedConstructionAlreadyReached(at point: ScoreKeepMigrationInterruptionPoint) -> Bool {
        switch point {
        case .afterContainerConstructionReturns, .afterPostOpenVerificationStarts, .afterPostOpenVerificationPasses,
             .afterCompletionRecordingStarts, .afterCompletionRecordingSucceeds, .afterOwnershipFinalization:
            return true
        case .afterJournalCreation, .afterDisableStateResolution, .afterOwnershipClaim,
             .afterSourceClassification, .afterBackupCopyStart, .afterBackupCopyCompletion,
             .afterBackupVerification, .afterWorkspaceCreationStarted, .afterWorkspaceVerification,
             .afterMigrationAttemptRecording, .afterContainerConstructionBegins:
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

    private func operationIdentity(
        storeIdentity: String,
        source: ScoreKeepSourceStoreClassification = .populatedCurrentUnversionedStore,
        target: ScoreKeepProposedSchemaSelection = .proposedV2
    ) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: storeIdentity,
            sourceSchema: source,
            targetSchema: target,
            applicationMigrationGeneration: 1,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000008101")!
        )
    }
}
#endif
