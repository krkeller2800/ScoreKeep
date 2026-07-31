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

    @Test("production startup gate permits only approved V1 to V4 source classification addition")
    func productionStartupGatePermitsApprovedV1ToV4SourceClassification() {
        #expect(ScoreKeepProductionStartupModel.supportsProductionMigrationStartup(.proposedV1RecognizableStore))
        #expect(ScoreKeepProductionStartupModel.supportsProductionMigrationStartup(.populatedCurrentUnversionedStore) == false)
        #expect(ScoreKeepProductionStartupModel.supportsProductionMigrationStartup(.emptyCurrentUnversionedStore) == false)
        #expect(ScoreKeepProductionStartupModel.supportsProductionMigrationStartup(.unknownVersion) == false)
    }

    @Test("exact V1 baseline capture skips absent optional V2 V3 V4 entities")
    func exactV1BaselineCaptureSkipsAbsentOptionalV2V3V4Entities() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)

        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: source.url).sourceClassification == .proposedV1RecognizableStore)
        let baseline = try formerUnversionedReadOnlyBaselineRecord(from: source.url)

        #expect(baseline.matchesRecordCounts(source.snapshot.counts))
        #expect(baseline.teamCreationOperationEvidenceCount == 0)
        #expect(baseline.canonicalHistoryCount == 0)
        #expect(baseline.canonicalEventCount == 0)
        #expect(baseline.canonicalPayloadCount == 0)
        #expect(baseline.canonicalOperationCount == 0)
        #expect(baseline.canonicalCorrectionCount == 0)
        #expect(baseline.legacyScoringOperationEvidenceCount == 0)

        let v1Schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V1.self)
        let optionalEntityNames = [
            "TeamCreationOperationEvidenceRecord",
            "CanonicalGameHistoryRecord",
            "CanonicalScoringEventEnvelopeRecord",
            "CanonicalScoringEventPayloadRecord",
            "CanonicalScoringOperationEvidenceRecord",
            "CanonicalScoringCorrectionRecord",
            "LegacyScoringOperationEvidenceRecord"
        ]
        for entityName in optionalEntityNames {
            var fetchWasConstructed = false
            let count = ScoreKeepMigrationBaselineCapture.optionalRecordCount(entityName: entityName, schema: v1Schema) {
                fetchWasConstructed = true
                return 1
            }
            #expect(count == 0)
            #expect(fetchWasConstructed == false)
        }
    }

    @Test("exact V1 backup helper captures baseline without mutating source or verified backup")
    func exactV1BackupHelperCapturesBaselineWithoutMutatingSourceOrVerifiedBackup() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.representative)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url)
        let sourceFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url)
        let backupURL = try storeURL()
        var capturedBaseline: ScoreKeepMigrationBaselineRecord?

        let evidence = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: source.url,
                backupStoreURL: backupURL,
                sourceLocation: .disposableTestStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: true,
                semanticRestoreVerifier: { restoreURL in
                    let record = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    capturedBaseline = record
                    return record.matchesRecordCounts(source.snapshot.counts)
                }
            )
        )
        let backupBeforeExplicitRead = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
        let backupFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: backupURL)
        let explicitRead = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: backupURL)

        #expect(evidence.disposition == .backupVerified)
        #expect(evidence.semanticVerificationPassed)
        #expect(capturedBaseline?.matchesRecordCounts(source.snapshot.counts) == true)
        #expect(explicitRead.matchesRecordCounts(source.snapshot.counts))
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url) == sourceBefore)
        #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == sourceFingerprint)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL) == backupBeforeExplicitRead)
        #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: backupURL) == backupFingerprint)
        #expect(evidence.sourceBefore.fileNames == evidence.backupAfter.fileNames)
        #expect(evidence.sourceBefore.missingOptionalSidecars == evidence.backupAfter.missingOptionalSidecars)
    }

    @Test("V1 semantic open failure remains backup verification failed and recovery required")
    func v1SemanticOpenFailureRemainsBackupVerificationFailedAndRecoveryRequired() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        var persistedDiagnosticSection: String?
        let diagnosticContext = ScoreKeepSourcePreservationSemanticDiagnosticContext(
            sourceClassification: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
            operationIdentity: "migration-2-v1diag",
            configurationName: "ScoreKeepProposedV1BackupSemanticVerification",
            allowsSave: true,
            automaticMigrationOptionPresent: true,
            inferredMigrationOptionPresent: true,
            requestedModelVersion: "ScoreKeepProposedVersionedSchema.V1:1.0.0",
            requestedModelEntityHashes: ["Game:hash-a"]
        )

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: "v1-semantic-open-failure",
                semanticRestoreVerifier: { _ in
                    throw ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError(diagnostic: "containerOpenFailed.readOnlyMigration")
                },
                postOpenVerifier: { _ in
                    Issue.record("Post-open verifier should not run after V1 backup semantic open failure.")
                    return false
                },
                semanticDiagnosticContext: diagnosticContext,
                semanticDiagnosticSnapshotSink: { persistedDiagnosticSection = $0 }
            ),
            journalStore: try journalStore()
        )

        #expect(result.disposition == .sourcePreservationFailed)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: result.disposition) == .backupVerificationFailed)
        #expect(result.journal.phase == .recoveryRequired)
        #expect(result.journal.recoveryRequirement == .writesRemainProhibited)
        #expect(result.recoveryRequirement == .writesRemainProhibited)
        #expect(result.container == nil)
        #expect(FileManager.default.fileExists(atPath: targetURL.path) == false)
        let persistedDiagnostic = try #require(persistedDiagnosticSection)
        #expect(persistedDiagnostic.contains("V1 Backup Semantic Verification Diagnostics"))
        #expect(persistedDiagnostic.contains("phase=afterOpenFailure"))
        #expect(persistedDiagnostic.contains("sourceUnchanged=true"))
        #expect(persistedDiagnostic.contains("verifiedBackupUnchanged=true"))
        let presentation = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .backupVerificationFailed,
            protectedDataState: .available,
            capacityStatus: "capacity.sufficient",
            sourceStatus: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
            backupStatus: "uncertain",
            migrationPhase: result.journal.phase.rawValue,
            targetVerification: result.journal.postOpenVerificationDisposition,
            retryAllowed: false,
            additionalSupportSection: persistedDiagnostic
        )
        #expect(presentation.diagnosticCode == ScoreKeepProductionStartupDiagnosticCode.backupVerificationFailed)
        #expect(presentation.supportSummary.contains("Startup Outcome: backupVerificationFailed"))
        #expect(presentation.supportSummary.contains("V1 Backup Semantic Verification Diagnostics"))
        #expect(presentation.supportSummary.contains("operationIdentity=migration-2-v1diag"))
    }

    @Test("V1 to V4 production post-open verifier uses in-memory baseline without fallback on uninterrupted run")
    func v1ToV4ProductionPostOpenVerifierUsesInMemoryBaselineWhenUninterrupted() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        var preservedBaseline: ScoreKeepMigrationBaselineRecord?
        var fallbackReadCount = 0

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: "v1-v4-uninterrupted",
                semanticRestoreVerifier: { restoreURL in
                    let record = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    preservedBaseline = record
                    return true
                },
                postOpenVerifier: { container in
                    ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaseline(
                        container: container,
                        sourceClassification: .proposedV1RecognizableStore,
                        preservedBaseline: preservedBaseline,
                        backupURL: backupURL,
                        baselineReconstructor: { _, _, _ in
                            fallbackReadCount += 1
                            return nil
                        }
                    )
                }
            ),
            journalStore: try journalStore()
        )

        #expect(result.disposition == .completed)
        #expect(result.journal.phase == .completionRecorded)
        #expect(result.journal.postOpenVerificationDisposition == "passed")
        #expect(result.journal.containerConstructionDisposition == .openedCompatibleSourceAndTransitionedToProposedV4)
        #expect(preservedBaseline != nil)
        #expect(fallbackReadCount == 0)
    }

    @Test("V1 to V4 production post-open verifier reconstructs resumed baseline from verified backup")
    func v1ToV4ProductionPostOpenVerifierReconstructsResumedBaselineFromVerifiedBackup() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let journalStore = try journalStore()
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        let identity = "v1-v4-resumed"
        var firstRunSemanticVerifierCalls = 0
        let interrupted = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                interruptionPoint: .afterBackupVerification,
                semanticRestoreVerifier: { restoreURL in
                    firstRunSemanticVerifierCalls += 1
                    _ = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    return true
                },
                postOpenVerifier: { _ in false }
            ),
            journalStore: journalStore
        )
        var resumedSemanticVerifierCalls = 0
        var fallbackReadCount = 0
        var reconstructedBaseline: ScoreKeepMigrationBaselineRecord?
        let restoreCountBeforeResume = try baselineRestoreDirectoryCount(containing: backupURL)

        let resumed = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                semanticRestoreVerifier: { _ in
                    resumedSemanticVerifierCalls += 1
                    return false
                },
                postOpenVerifier: { container in
                    ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaseline(
                        container: container,
                        sourceClassification: .proposedV1RecognizableStore,
                        preservedBaseline: nil,
                        backupURL: backupURL,
                        baselineReconstructor: { backupURL, sourceClassification, fileManager in
                            fallbackReadCount += 1
                            let baseline = try ScoreKeepProductionStartupModel.reconstructExpectedSourceBaseline(
                                fromVerifiedBackup: backupURL,
                                sourceClassification: sourceClassification,
                                fileManager: fileManager
                            )
                            reconstructedBaseline = baseline
                            return baseline
                        }
                    )
                }
            ),
            journalStore: journalStore
        )

        #expect(interrupted.disposition == .interrupted)
        #expect(interrupted.journal.phase == .backupVerified)
        #expect(firstRunSemanticVerifierCalls == 1)
        #expect(resumed.disposition == .completed)
        #expect(resumed.journal.operationIdentity == interrupted.journal.operationIdentity)
        #expect(resumed.journal.backupIdentity == interrupted.journal.backupIdentity)
        #expect(resumed.journal.phase == .completionRecorded)
        #expect(resumed.journal.postOpenVerificationDisposition == "passed")
        #expect(resumedSemanticVerifierCalls == 0)
        #expect(fallbackReadCount == 1)
        #expect(reconstructedBaseline != nil)
        #expect(try baselineRestoreDirectoryCount(containing: backupURL) == restoreCountBeforeResume)
        let resumedContainer = try #require(resumed.container)
        let failureResult = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaseline(
            container: resumedContainer,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: backupURL,
            baselineReconstructor: { _, _, _ in
                throw ScoreKeepStoreFamilyError.primaryStoreMissing
            }
        )
        #expect(failureResult == false)
    }

    @Test("baseline reconstruction removes disposable restore after failed copied-store open")
    func baselineReconstructionRemovesDisposableRestoreAfterFailedCopiedStoreOpen() throws {
        let backupURL = try storeURL(fileName: "Invalid.store")
        try Data([0x53, 0x4B, 0x00]).write(to: backupURL)
        let restoreCountBeforeFailure = try baselineRestoreDirectoryCount(containing: backupURL)

        #expect(throws: (any Error).self) {
            _ = try ScoreKeepProductionStartupModel.reconstructExpectedSourceBaseline(
                fromVerifiedBackup: backupURL,
                sourceClassification: .proposedV1RecognizableStore
            )
        }
        #expect(try baselineRestoreDirectoryCount(containing: backupURL) == restoreCountBeforeFailure)
    }

    @Test("post-open verifier reports missing verified backup diagnostic")
    func postOpenVerifierReportsMissingVerifiedBackupDiagnostic() throws {
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let container = try #require(target.container)
        let missingBackup = try storeURL(fileName: "Missing.store")

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: container,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: missingBackup
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenMissingVerifiedBackup])
    }

    @Test("post-open verifier reports backup restore copy diagnostic")
    func postOpenVerifierReportsBackupRestoreCopyDiagnostic() throws {
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let container = try #require(target.container)
        let backupURL = try storeURL(fileName: "CopyFailure.store")
        try Data([0x01]).write(to: backupURL)

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: container,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: backupURL,
            baselineReconstructor: { _, _, _ in
                throw ScoreKeepStoreFamilyError.backupDirectoryNotFresh
            }
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed])
    }

    @Test("post-open verifier reports backup family discovery restore-copy diagnostic")
    func postOpenVerifierReportsBackupFamilyDiscoveryRestoreCopyDiagnostic() throws {
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: storeURL(fileName: "DiscoveryFailure.store"),
            fileManager: RestoreCopyFailureFileManager(failure: .backupFamilyDiscovery)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupFamilyDiscoveryFailed])
    }

    @Test("post-open verifier reports incomplete backup family restore-copy diagnostic")
    func postOpenVerifierReportsIncompleteBackupFamilyRestoreCopyDiagnostic() throws {
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: storeURL(fileName: "Incomplete.store"),
            fileManager: RestoreCopyFailureFileManager(failure: .incompleteBackupFamily)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupFamilyIncomplete])
    }

    @Test("post-open verifier reports restore directory creation diagnostic")
    func postOpenVerifierReportsRestoreDirectoryCreationDiagnostic() throws {
        let backupURL = try singleMemberBackupURL(fileName: "DirectoryCreateFailure.store")
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: backupURL,
            fileManager: RestoreCopyFailureFileManager(failure: .restoreDirectoryCreate)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupRestoreDirectoryCreateFailed])
    }

    @Test("post-open verifier reports restore member copy diagnostic")
    func postOpenVerifierReportsRestoreMemberCopyDiagnostic() throws {
        let backupURL = try singleMemberBackupURL(fileName: "MemberCopyFailure.store")
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: backupURL,
            fileManager: RestoreCopyFailureFileManager(failure: .memberCopy)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupRestoreMemberCopyFailed])
    }

    @Test("post-open verifier reports restored family discovery diagnostic")
    func postOpenVerifierReportsRestoredFamilyDiscoveryDiagnostic() throws {
        let backupURL = try singleMemberBackupURL(fileName: "RestoredDiscoveryFailure.store")
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: backupURL,
            fileManager: RestoreCopyFailureFileManager(failure: .restoredFamilyDiscovery)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupRestoreDiscoveryFailed])
    }

    @Test("post-open verifier reports restore validation diagnostic")
    func postOpenVerifierReportsRestoreValidationDiagnostic() throws {
        let backupURL = try singleMemberBackupURL(fileName: "RestoreValidationFailure.store")
        let verification = try restoreCopyDiagnosticVerification(
            backupURL: backupURL,
            fileManager: RestoreCopyFailureFileManager(failure: .restoreValidation)
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupRestoreCopyFailed, .postOpenBackupRestoreValidationFailed])
    }

    @Test("post-open verifier reports backup container open diagnostic")
    func postOpenVerifierReportsBackupContainerOpenDiagnostic() throws {
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let container = try #require(target.container)
        let backupURL = try storeURL(fileName: "InvalidBackup.store")
        try Data([0x53, 0x4B, 0x00]).write(to: backupURL)

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: container,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: backupURL
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupContainerOpenFailed])
    }

    @Test("post-open verifier reports backup baseline capture diagnostic")
    func postOpenVerifierReportsBackupBaselineCaptureDiagnostic() throws {
        struct BaselineCaptureFailure: Error {}

        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let container = try #require(target.container)
        let backupURL = try storeURL(fileName: "BackupCaptureFailure.store")
        try Data([0x01]).write(to: backupURL)

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: container,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: backupURL,
            baselineReconstructor: { _, _, _ in
                throw BaselineCaptureFailure()
            }
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenBackupBaselineCaptureFailed])
    }

    @Test("post-open verifier reports target baseline capture diagnostic")
    func postOpenVerifierReportsTargetBaselineCaptureDiagnostic() throws {
        struct TargetBaselineCaptureFailure: Error {}

        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let sourceContainer = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
        let sourceBaseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: sourceContainer.mainContext)
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let targetContainer = try #require(target.container)

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: targetContainer,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: sourceBaseline,
            backupURL: try storeURL(),
            baselineReconstructor: { _, _, _ in sourceBaseline },
            targetBaselineCapture: { _ in
                throw TargetBaselineCaptureFailure()
            }
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes == [.postOpenTargetBaselineCaptureFailed])
    }

    @Test("post-open verifier reports baseline mismatch summary diagnostics")
    func postOpenVerifierReportsBaselineMismatchSummaryDiagnostics() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let sourceContainer = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
        let sourceBaseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: sourceContainer.mainContext)
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let targetContainer = try #require(target.container)

        let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: targetContainer,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: sourceBaseline,
            backupURL: try storeURL()
        )

        #expect(verification.passed == false)
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchCounts))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchStableIdentity))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchRelationship))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchOrdering))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchScore))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchSubstitution))
        #expect(verification.diagnosticCodes.contains(.postOpenBaselineMismatchMedia))
    }

    @Test("orchestrator persists post-open verifier subdiagnostics")
    func orchestratorPersistsPostOpenVerifierSubdiagnostics() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        var diagnostics: [ScoreKeepMigrationJournalDiagnosticCode] = []

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: "v1-v4-post-open-subdiagnostics",
                semanticRestoreVerifier: { restoreURL in
                    _ = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    return true
                },
                postOpenVerifier: { container in
                    let verification = ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
                        container: container,
                        sourceClassification: .proposedV1RecognizableStore,
                        preservedBaseline: nil,
                        backupURL: backupURL,
                        baselineReconstructor: { _, _, _ in
                            throw ScoreKeepStoreFamilyError.backupDirectoryNotFresh
                        }
                    )
                    diagnostics = verification.diagnosticCodes
                    return verification.passed
                },
                postOpenFailureDiagnostics: {
                    diagnostics
                }
            ),
            journalStore: try journalStore()
        )

        #expect(result.disposition == .verificationFailed)
        #expect(result.journal.phase == .recoveryRequired)
        #expect(result.journal.postOpenVerificationDisposition == "failed")
        #expect(result.journal.diagnosticCodes.suffix(2) == [.postOpenVerificationFailed, .postOpenBackupRestoreCopyFailed])
        #expect(result.diagnostics == [.postOpenVerificationFailed, .postOpenBackupRestoreCopyFailed])
    }

    @Test("recovery required verify existing target completes after post-open verifier passes")
    func recoveryRequiredVerifyExistingTargetCompletesAfterPostOpenVerifierPasses() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        let journalStore = try journalStore()
        let identity = "v1-v4-recovery-completion"
        var preservedBaseline: ScoreKeepMigrationBaselineRecord?

        let failed = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                semanticRestoreVerifier: { restoreURL in
                    preservedBaseline = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    return true
                },
                postOpenVerifier: { _ in false }
            ),
            journalStore: journalStore
        )

        #expect(failed.disposition == .verificationFailed)
        #expect(failed.journal.phase == .recoveryRequired)
        #expect(failed.journal.recoveryRequirement == .verifyExistingTarget)
        #expect(failed.journal.retryClassification == .retryRequiresFreshTargetCopy)
        let failedGeneration = failed.journal.transitionGeneration

        let completed = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                semanticRestoreVerifier: { _ in
                    Issue.record("Verified backup should be reused without repeating source preservation")
                    return false
                },
                postOpenVerifier: { container in
                    ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaseline(
                        container: container,
                        sourceClassification: .proposedV1RecognizableStore,
                        preservedBaseline: preservedBaseline,
                        backupURL: backupURL
                    )
                }
            ),
            journalStore: journalStore
        )

        #expect(completed.disposition == .completed)
        #expect(completed.journal.phase == .completionRecorded)
        #expect(completed.journal.operationIdentity == failed.journal.operationIdentity)
        #expect(completed.journal.backupIdentity == failed.journal.backupIdentity)
        #expect(completed.journal.postOpenVerificationDisposition == "passed")
        #expect(completed.journal.recoveryRequirement == .noRecoveryRequired)
        #expect(completed.journal.transitionGeneration == failedGeneration + 3)
    }

    @Test("recovery required verify existing target stays failed when post-open verifier fails")
    func recoveryRequiredVerifyExistingTargetStaysFailedWhenPostOpenVerifierFails() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let backupURL = try storeURL()
        let targetURL = try storeURL()
        let journalStore = try journalStore()
        let identity = "v1-v4-recovery-remains-failed"

        _ = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                semanticRestoreVerifier: { _ in true },
                postOpenVerifier: { _ in false }
            ),
            journalStore: journalStore
        )

        let retried = try ScoreKeepMigrationOrchestrator.run(
            input: v1ToV4Input(
                source: source,
                backupURL: backupURL,
                targetURL: targetURL,
                journalStoreIdentity: identity,
                semanticRestoreVerifier: { _ in
                    Issue.record("Verified backup should be reused without repeating source preservation")
                    return false
                },
                postOpenVerifier: { _ in false }
            ),
            journalStore: journalStore
        )

        #expect(retried.disposition == .verificationFailed)
        #expect(retried.journal.phase == .recoveryRequired)
        #expect(retried.journal.recoveryRequirement == .verifyExistingTarget)
        #expect(retried.journal.phase != .completionRecorded)
    }

    @Test("production resume paths use journal operation identity when source fingerprint changes")
    func productionResumePathsUseJournalOperationIdentityWhenSourceFingerprintChanges() throws {
        let layout = try productionMigrationLayout()
        let journalIdentity = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: "verified-source-identity",
            sourceSchema: .proposedV1RecognizableStore,
            targetSchema: .proposedV4,
            applicationMigrationGeneration: 2,
            operationUUID: UUID(uuidString: "8058AE23-17E1-5020-AA77-3A6F3C0782A9")!
        )
        let recomputedIdentity = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: "changed-current-source-identity",
            sourceSchema: .proposedV1RecognizableStore,
            targetSchema: .proposedV4,
            applicationMigrationGeneration: 2,
            operationUUID: UUID(uuidString: "2020C8BD-3225-57FA-A590-77ECD2985133")!
        )
        var journal = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: journalIdentity,
            sourceStoreDiagnosticIdentity: journalIdentity.sourceStoreIdentity,
            sourceClassification: .proposedV1RecognizableStore,
            disableState: .proposedTransitionExplicitlyAuthorized
        )
        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .backupVerified,
            sourcePreservationDisposition: .backupVerified,
            backupIdentity: journalIdentity.sourceStoreIdentity,
            backupVerificationDisposition: .backupVerified,
            retryClassification: .reuseVerifiedBackup
        )

        let plan = ScoreKeepProductionStartupModel.productionMigrationOperationPlan(
            layout: layout,
            computedOperationIdentity: recomputedIdentity,
            existingJournal: journal
        )

        #expect(plan.resumedFromExistingJournal)
        #expect(plan.operationIdentity == journalIdentity)
        #expect(plan.backupURL == layout.operationBackupStoreURL(operationIdentity: journalIdentity))
        #expect(plan.targetURL == layout.operationTemporaryTargetURL(operationIdentity: journalIdentity))
        #expect(plan.backupURL != layout.operationBackupStoreURL(operationIdentity: recomputedIdentity))
        #expect(plan.targetURL != layout.operationTemporaryTargetURL(operationIdentity: recomputedIdentity))
    }

    @Test("production new migration paths use computed operation identity")
    func productionNewMigrationPathsUseComputedOperationIdentity() throws {
        let layout = try productionMigrationLayout()
        let computedIdentity = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: "new-source-identity",
            sourceSchema: .proposedV1RecognizableStore,
            targetSchema: .proposedV4,
            applicationMigrationGeneration: 2,
            operationUUID: UUID(uuidString: "8FD88A2F-2D87-55D3-9FAD-DF03C8CB9D11")!
        )

        let plan = ScoreKeepProductionStartupModel.productionMigrationOperationPlan(
            layout: layout,
            computedOperationIdentity: computedIdentity,
            existingJournal: nil
        )

        #expect(plan.resumedFromExistingJournal == false)
        #expect(plan.operationIdentity == computedIdentity)
        #expect(plan.backupURL == layout.operationBackupStoreURL(operationIdentity: computedIdentity))
        #expect(plan.targetURL == layout.operationTemporaryTargetURL(operationIdentity: computedIdentity))
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

    private func baselineRestoreDirectoryCount(containing backupURL: URL) throws -> Int {
        let restoreParent = backupURL.deletingLastPathComponent().deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(atPath: restoreParent.path)
            .filter { $0.hasPrefix("baseline-restore-") }
            .count
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

    private func v1ToV4Input(
        source: (url: URL, snapshot: UnversionedStoreSnapshot),
        backupURL: URL,
        targetURL: URL,
        journalStoreIdentity: String,
        interruptionPoint: ScoreKeepMigrationInterruptionPoint? = nil,
        semanticRestoreVerifier: @escaping (URL) throws -> Bool,
        postOpenVerifier: @escaping (ModelContainer) throws -> Bool,
        postOpenFailureDiagnostics: (() -> [ScoreKeepMigrationJournalDiagnosticCode])? = nil,
        semanticDiagnosticContext: ScoreKeepSourcePreservationSemanticDiagnosticContext? = nil,
        semanticDiagnosticSnapshotSink: ((String) -> Void)? = nil
    ) -> ScoreKeepMigrationOrchestratorInput {
        ScoreKeepMigrationOrchestratorInput(
            operationIdentity: operationIdentity(storeIdentity: journalStoreIdentity, source: .proposedV1RecognizableStore, target: .proposedV4),
            sourceStoreURL: source.url,
            backupStoreURL: backupURL,
            targetStoreURL: targetURL,
            sourceClassification: .proposedV1RecognizableStore,
            disableState: .proposedTransitionExplicitlyAuthorized,
            authorizationEvidence: "local-explicit-test-authorization",
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: interruptionPoint,
            factoryInjection: nil,
            semanticRestoreVerifier: semanticRestoreVerifier,
            makeSemanticRestoreCopyWritable: true,
            semanticDiagnosticContext: semanticDiagnosticContext,
            semanticDiagnosticSnapshotSink: semanticDiagnosticSnapshotSink,
            postOpenVerifier: postOpenVerifier,
            postOpenFailureDiagnostics: postOpenFailureDiagnostics
        )
    }

    private func factoryInput(url: URL, source: ScoreKeepSourceStoreClassification) -> ScoreKeepProposedContainerFactoryInput {
        ScoreKeepProposedContainerFactoryInput(
            storeLocation: .disposableTestStore(url: url),
            writabilityMode: .writable,
            startupIntent: .isolatedVerification,
            sourceClassification: source,
            routeChoice: .proposedV4EligibleForIsolatedVerification
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

    private func productionMigrationLayout() throws -> ScoreKeepProductionMigrationLayout {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepMigrationOrchestratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: directory)
    }

    private func restoreCopyDiagnosticVerification(
        backupURL: URL,
        fileManager: FileManager
    ) throws -> ScoreKeepProductionStartupModel.PostOpenMigrationBaselineVerificationResult {
        let target = ScoreKeepProposedContainerFactory.construct(factoryInput(url: try storeURL(), source: .noStoreExists))
        let container = try #require(target.container)
        return ScoreKeepProductionStartupModel.verifyPostOpenMigrationBaselineResult(
            container: container,
            sourceClassification: .proposedV1RecognizableStore,
            preservedBaseline: nil,
            backupURL: backupURL,
            fileManager: fileManager
        )
    }

    private func formerUnversionedReadOnlyBaselineRecord(from url: URL) throws -> ScoreKeepMigrationBaselineRecord {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Lineup.self, Pitcher.self])
        let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: false)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
    }

    private func singleMemberBackupURL(fileName: String) throws -> URL {
        let backupURL = try storeURL(fileName: fileName)
        try Data([0x53, 0x4B, 0x01]).write(to: backupURL)
        return backupURL
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

    private final class RestoreCopyFailureFileManager: FileManager, @unchecked Sendable {
        enum Failure {
            case backupFamilyDiscovery
            case incompleteBackupFamily
            case restoreDirectoryCreate
            case memberCopy
            case restoredFamilyDiscovery
            case restoreValidation
        }

        let failure: Failure

        init(failure: Failure) {
            self.failure = failure
            super.init()
        }

        override func fileExists(atPath path: String) -> Bool {
            switch failure {
            case .backupFamilyDiscovery, .incompleteBackupFamily:
                return true
            case .restoreDirectoryCreate, .memberCopy, .restoredFamilyDiscovery, .restoreValidation:
                return super.fileExists(atPath: path)
            }
        }

        override func contentsOfDirectory(atPath path: String) throws -> [String] {
            switch failure {
            case .backupFamilyDiscovery:
                throw CocoaError(.fileReadNoSuchFile)
            case .incompleteBackupFamily:
                return []
            case .restoredFamilyDiscovery where path.contains("baseline-restore-"):
                throw CocoaError(.fileReadNoSuchFile)
            case .restoreDirectoryCreate, .memberCopy, .restoredFamilyDiscovery, .restoreValidation:
                return try super.contentsOfDirectory(atPath: path)
            }
        }

        override func createDirectory(
            at url: URL,
            withIntermediateDirectories createIntermediates: Bool,
            attributes: [FileAttributeKey: Any]? = nil
        ) throws {
            if failure == .restoreDirectoryCreate, url.lastPathComponent.hasPrefix("baseline-restore-") {
                throw CocoaError(.fileWriteNoPermission)
            }
            try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
        }

        override func copyItem(at srcURL: URL, to dstURL: URL) throws {
            switch failure {
            case .memberCopy:
                throw CocoaError(.fileWriteNoPermission)
            case .restoreValidation:
                try Data([0x00]).write(to: dstURL)
            case .backupFamilyDiscovery, .incompleteBackupFamily, .restoreDirectoryCreate, .restoredFamilyDiscovery:
                try super.copyItem(at: srcURL, to: dstURL)
            }
        }
    }
}
#endif
