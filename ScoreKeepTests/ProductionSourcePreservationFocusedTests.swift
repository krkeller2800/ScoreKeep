import Foundation
import SwiftData
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Source store family preservation")
struct ScoreKeepSourcePreservationTests {
    @Test("store family discovery classifies primary optional sidecars and unexpected related files")
    func storeFamilyDiscoveryClassifiesPrimaryOptionalSidecarsAndUnexpectedRelatedFiles() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.empty)
        let directory = source.url.deletingLastPathComponent()
        let unexpected = directory.appendingPathComponent("\(source.url.lastPathComponent)-unexpected")
        try Data([1, 2, 3]).write(to: unexpected)

        let family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url)

        #expect(family.missingPrimary == false)
        #expect(family.members.contains { $0.role == .primary })
        #expect(family.missingOptionalSidecars.contains("\(source.url.lastPathComponent)-wal") || family.members.contains { $0.role == .wal })
        #expect(family.missingOptionalSidecars.contains("\(source.url.lastPathComponent)-shm") || family.members.contains { $0.role == .shm })
        #expect(family.unexpectedRelatedFiles == ["\(source.url.lastPathComponent)-unexpected"])
    }

    @Test("missing primary store is incomplete")
    func missingPrimaryStoreIsIncomplete() throws {
        let storeURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: storeURL)
        #expect(family.missingPrimary)
        #expect(family.isComplete == false)
    }

    @Test("source preservation verifies file family semantic restore and source immutability")
    func sourcePreservationVerifiesFileFamilySemanticRestoreAndSourceImmutability() throws {
        for scenario in [UnversionedStoreScenario.empty, .minimal, .representative] {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let originalFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url)
            let backupURL = try backupStoreURL()

            let evidence = try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: backupURL,
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: { restoreURL in
                        let restored = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: restoreURL)
                        let restoredSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: restored, fixtureIdentity: scenario.rawValue)
                        return restoredSnapshot == source.snapshot
                    }
                )
            )

            #expect(evidence.fileVerificationPassed)
            #expect(evidence.semanticVerificationPassed)
            #expect(evidence.disposition == .backupVerified)
            #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == originalFingerprint)
            #expect(evidence.sourceBefore == evidence.sourceAfter)
        }
    }

    @Test("media bearing source restore preserves photos and logos")
    func mediaBearingSourceRestorePreservesPhotosAndLogos() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let backupURL = try backupStoreURL()

        let evidence = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: source.url,
                backupStoreURL: backupURL,
                sourceLocation: .disposableTestStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: true,
                semanticRestoreVerifier: { restoreURL in
                    let restored = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: restoreURL)
                    let restoredSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: restored, fixtureIdentity: UnversionedStoreScenario.minimal.rawValue)
                    return restoredSnapshot.playerPhotoFingerprints == source.snapshot.playerPhotoFingerprints
                        && restoredSnapshot.teamLogoFingerprints == source.snapshot.teamLogoFingerprints
                }
            )
        )

        #expect(evidence.semanticVerificationPassed)
    }

    @Test("preservation rejects production paths active sources and non fresh destinations")
    func preservationRejectsProductionPathsActiveSourcesAndNonFreshDestinations() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let backupURL = try backupStoreURL()

        #expect(throws: ScoreKeepSourcePreservationError.productionPathRejected) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: backupURL,
                    sourceLocation: .productionIntendedApplicationStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: nil
                )
            )
        }

        let authorizedProductionBackupURL = try backupStoreURL()
        let authorized = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: source.url,
                backupStoreURL: authorizedProductionBackupURL,
                sourceLocation: .productionIntendedApplicationStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: false,
                semanticRestoreVerifier: nil,
                authorizationScope: .productionTransitionExplicitlyAuthorized
            )
        )
        #expect(authorized.fileVerificationPassed)
        #expect(authorized.disposition == .backupVerified)

        #expect(throws: ScoreKeepSourcePreservationError.sourceNotClosed) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: try backupStoreURL(),
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: ScoreKeepSourceClosureEvidence(
                        sourceContainerReleased: false,
                        sourceContextReleased: true,
                        testAuthorityReleasedSourceAccess: true,
                        noOtherKnownSourceAuthorityOpen: true
                    ),
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: nil
                )
            )
        }

        let nonFresh = try backupStoreURL()
        try Data([1]).write(to: nonFresh.deletingLastPathComponent().appendingPathComponent("existing"))
        #expect(throws: ScoreKeepSourcePreservationError.destinationNotFresh) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: nonFresh,
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: nil
                )
            )
        }
    }

    @Test("preservation reports mismatched copied family inventory when backup basename differs")
    func preservationReportsMismatchedCopiedFamilyInventoryWhenBackupBasenameDiffers() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let backupURL = try backupStoreURL(fileName: "Different.store")

        #expect(throws: ScoreKeepSourcePreservationError.backupVerificationFailed(.memberInventoryMismatch)) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: backupURL,
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: nil
                )
            )
        }
    }

    @Test("semantic restore verification distinguishes open failure from baseline mismatch")
    func semanticRestoreVerificationDistinguishesOpenFailureFromBaselineMismatch() throws {
        let throwingSource = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        do {
            _ = try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: throwingSource.url,
                    backupStoreURL: try backupStoreURL(fileName: throwingSource.url.lastPathComponent),
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: { _ in
                        throw ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError(diagnostic: "containerOpenFailed.incompatibleModel")
                    }
                )
            )
            Issue.record("Semantic restore open failure unexpectedly succeeded.")
        } catch ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticRestoreOpen(let diagnostic)) {
            #expect(diagnostic == "containerOpenFailed.incompatibleModel")
            #expect(ScoreKeepSourcePreservationErrorIdentity.make(ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticRestoreOpen(diagnostic))) == "semanticRestoreOpen.containerOpenFailed.incompatibleModel")
        } catch {
            Issue.record("Unexpected semantic restore error: \(error)")
        }

        let mismatchSource = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        #expect(throws: ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticBaselineMismatch)) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: mismatchSource.url,
                    backupStoreURL: try backupStoreURL(fileName: mismatchSource.url.lastPathComponent),
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: { _ in false }
                )
            )
        }
    }

    @Test("semantic baseline mismatch persists bounded baseline difference diagnostics")
    func semanticBaselineMismatchPersistsBoundedBaselineDifferenceDiagnostics() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let context = ScoreKeepSourcePreservationSemanticDiagnosticContext(
            sourceClassification: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
            operationIdentity: "migration-2-baseline-mismatch",
            configurationName: "ScoreKeepProposedV1BackupSemanticVerification",
            allowsSave: true,
            automaticMigrationOptionPresent: true,
            inferredMigrationOptionPresent: true,
            requestedModelVersion: "ScoreKeepProposedVersionedSchema.V1:1.0.0",
            requestedModelEntityHashes: ["Game:hash-a"]
        )
        let expected = diagnosticBaseline(identity: "expected Private Player /tmp/leak", countOffset: 0, runnerStatus: "candidateThirdOutSequenceCaptured")
        let actual = diagnosticBaseline(identity: "actual Private Team /tmp/leak", countOffset: 1, runnerStatus: "thirdOutBoundaryCapturedWithAmbiguity")
        var persistedSnapshots: [String] = []

        #expect(throws: ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticBaselineMismatch)) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: try backupStoreURL(fileName: source.url.lastPathComponent),
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: { _ in false },
                    semanticDiagnosticContext: context,
                    semanticDiagnosticSnapshotSink: { persistedSnapshots.append($0) },
                    semanticBaselineMismatchDiagnosticLines: {
                        ScoreKeepMigrationBaselineCapture.baselineMismatchDiagnosticLines(expected: expected, actual: actual)
                    }
                )
            )
        }

        #expect(persistedSnapshots.count == 2)
        #expect(persistedSnapshots.first?.contains("phase=beforeOpen") == true)
        let snapshot = try #require(persistedSnapshots.last)
        #expect(snapshot.contains("phase=afterOpenBaselineMismatch"))
        #expect(snapshot.contains("underlyingError=domain=ScoreKeep.ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError;code=1"))
        #expect(snapshot.contains("baselineMismatch.field=gameCount"))
        #expect(snapshot.contains("baselineMismatch.field=stableIdentityFingerprint"))
        #expect(snapshot.contains("baselineMismatch.field=relationshipFingerprint"))
        #expect(snapshot.contains("baselineMismatch.field=orderingFingerprint"))
        #expect(snapshot.contains("baselineMismatch.field=scoreEvidence"))
        #expect(snapshot.contains("baselineMismatch.field=substitutionEvidence"))
        #expect(snapshot.contains("baselineMismatch.field=mediaOwnershipFingerprint"))
        #expect(snapshot.contains("baselineMismatch.field=importSourceClassification"))
        #expect(snapshot.contains("baselineMismatch.field=difficultRunnerSequence.status"))
        #expect(snapshot.contains(FileManager.default.temporaryDirectory.path) == false)
        #expect(snapshot.contains(source.url.deletingLastPathComponent().path) == false)
        #expect(snapshot.contains("Private Player") == false)
        #expect(snapshot.contains("Private Team") == false)
        #expect(snapshot.contains("/tmp/leak") == false)
        #expect(snapshot.split(separator: "\n").count <= 80)
    }

    @Test("semantic restore open failure captures bounded redacted diagnostics")
    func semanticRestoreOpenFailureCapturesBoundedRedactedDiagnostics() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let backupURL = try backupStoreURL(fileName: source.url.lastPathComponent)
        let context = ScoreKeepSourcePreservationSemanticDiagnosticContext(
            sourceClassification: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
            operationIdentity: "migration-2-12345678",
            configurationName: "ScoreKeepProposedV1BackupSemanticVerification",
            allowsSave: true,
            automaticMigrationOptionPresent: true,
            inferredMigrationOptionPresent: true,
            requestedModelVersion: "ScoreKeepProposedVersionedSchema.V1:1.0.0",
            requestedModelEntityHashes: ["Game:hash-a", "Team:hash-b"]
        )
        var persistedSnapshots: [String] = []

        do {
            _ = try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: source.url,
                    backupStoreURL: backupURL,
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: { restoreURL in
                        let createdMember = restoreURL.deletingLastPathComponent()
                            .appendingPathComponent(restoreURL.lastPathComponent + "-diagnostic")
                        try Data([0x56, 0x31]).write(to: createdMember)
                        throw NSError(
                            domain: "com.scorekeep.test/core-data",
                            code: 134110,
                            userInfo: [
                                NSLocalizedFailureReasonErrorKey: "attempted write at \(restoreURL.path)"
                            ]
                        )
                    },
                    semanticDiagnosticContext: context,
                    semanticDiagnosticSnapshotSink: { persistedSnapshots.append($0) }
                )
            )
            Issue.record("Semantic restore open failure unexpectedly succeeded.")
        } catch ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticRestoreOpen(let diagnostic)) {
            #expect(diagnostic.contains("V1 Backup Semantic Verification Diagnostics"))
            #expect(diagnostic.contains("sourceClassification=proposedV1RecognizableStore"))
            #expect(diagnostic.contains("operationIdentity=migration-2-12345678"))
            #expect(diagnostic.contains("configurationName=ScoreKeepProposedV1BackupSemanticVerification"))
            #expect(diagnostic.contains("allowsSave=true"))
            #expect(diagnostic.contains("automaticMigrationOptionPresent=true"))
            #expect(diagnostic.contains("inferredMigrationOptionPresent=true"))
            #expect(diagnostic.contains("requestedModelVersion=ScoreKeepProposedVersionedSchema.V1:1.0.0"))
            #expect(diagnostic.contains("requestedModelEntityHashes=Game:hash-a,Team:hash-b"))
            #expect(diagnostic.contains("underlyingError=domain=com.scorekeep.test_core-data;code=134110"))
            #expect(diagnostic.contains("restoreFamilyChanged=\(source.url.lastPathComponent)-diagnostic:created"))
            #expect(diagnostic.contains("sourceUnchanged=true"))
            #expect(diagnostic.contains("verifiedBackupUnchanged=true"))
            #expect(diagnostic.contains("persistentStoreMetadata."))
            #expect(diagnostic.contains(FileManager.default.temporaryDirectory.path) == false)
            #expect(diagnostic.contains(source.url.deletingLastPathComponent().path) == false)
            #expect(diagnostic.contains(backupURL.deletingLastPathComponent().path) == false)
            #expect(diagnostic.split(separator: "\n").count <= 80)
            #expect(persistedSnapshots.count == 2)
            #expect(persistedSnapshots.first?.contains("phase=beforeOpen") == true)
            #expect(persistedSnapshots.last?.contains("phase=afterOpenFailure") == true)
            #expect(persistedSnapshots.last?.contains("restoreFamilyChanged=\(source.url.lastPathComponent)-diagnostic:created") == true)
            #expect(persistedSnapshots.last?.contains(FileManager.default.temporaryDirectory.path) == false)
        } catch {
            Issue.record("Unexpected semantic restore error: \(error)")
        }
    }

    @Test("writable V1 restore copy semantic verification succeeds and preserves source and backup")
    func writableV1RestoreCopySemanticVerificationSucceedsAndPreservesSourceAndBackup() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal)
        let backupURL = try backupStoreURL(fileName: source.url.lastPathComponent)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url)
        let context = ScoreKeepSourcePreservationSemanticDiagnosticContext(
            sourceClassification: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
            operationIdentity: "migration-2-v1-writable-copy",
            configurationName: "ScoreKeepProposedV1BackupSemanticVerification",
            allowsSave: true,
            automaticMigrationOptionPresent: true,
            inferredMigrationOptionPresent: true,
            requestedModelVersion: "ScoreKeepProposedVersionedSchema.V1:1.0.0",
            requestedModelEntityHashes: ["Game:diagnostic-only"]
        )
        var persistedSnapshots: [String] = []

        let evidence = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: source.url,
                backupStoreURL: backupURL,
                sourceLocation: .disposableTestStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: true,
                semanticRestoreVerifier: { restoreURL in
                    let record = try ScoreKeepProductionStartupModel.proposedV1BackupBaselineRecord(from: restoreURL)
                    let diagnosticMember = restoreURL.deletingLastPathComponent()
                        .appendingPathComponent(restoreURL.lastPathComponent + "-diagnostic-success")
                    try Data([0x56, 0x31]).write(to: diagnosticMember)
                    return record.matchesRecordCounts(source.snapshot.counts)
                },
                makeSemanticRestoreCopyWritable: true,
                semanticDiagnosticContext: context,
                semanticDiagnosticSnapshotSink: { persistedSnapshots.append($0) }
            )
        )

        let backupAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
        #expect(evidence.disposition == .backupVerified)
        #expect(evidence.semanticVerificationPassed)
        #expect(evidence.sourceBefore == sourceBefore)
        #expect(evidence.sourceAfter == sourceBefore)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url) == sourceBefore)
        #expect(backupAfter == evidence.backupAfter)
        #expect(backupAfter.diagnosticIdentity == sourceBefore.diagnosticIdentity)
        #expect(persistedSnapshots.count == 2)
        #expect(persistedSnapshots.first?.contains("phase=beforeOpen") == true)
        let finalSnapshot = try #require(persistedSnapshots.last)
        #expect(finalSnapshot.contains("phase=afterOpenSuccess"))
        #expect(finalSnapshot.contains("sourceUnchanged=true"))
        #expect(finalSnapshot.contains("verifiedBackupUnchanged=true"))
        #expect(finalSnapshot.contains("restoreFamilyChanged=\(source.url.lastPathComponent)-diagnostic-success:created"))
        #expect(finalSnapshot.contains(FileManager.default.temporaryDirectory.path) == false)
    }

    @Test("verified backup family can be preserved into a distinct fresh fallback family")
    func verifiedBackupFamilyCanBePreservedIntoDistinctFreshFallbackFamily() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let verifiedBackupURL = try backupStoreURL()
        let verifiedBackup = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: source.url,
                backupStoreURL: verifiedBackupURL,
                sourceLocation: .disposableTestStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: true,
                semanticRestoreVerifier: nil
            )
        )
        let operationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepSourcePreservationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: operationDirectory, withIntermediateDirectories: true)
        try Data([1]).write(to: operationDirectory.appendingPathComponent("v2-intermediate.store"))

        let sameDirectoryFallbackURL = operationDirectory.appendingPathComponent(verifiedBackupURL.lastPathComponent)
        #expect(throws: ScoreKeepSourcePreservationError.destinationNotFresh) {
            try ScoreKeepSourcePreservationExecutor.preserve(
                ScoreKeepSourcePreservationRequest(
                    sourceStoreURL: verifiedBackupURL,
                    backupStoreURL: sameDirectoryFallbackURL,
                    sourceLocation: .disposableTestStore,
                    sourceClosureEvidence: .closedForDisposableVerification,
                    allowIncompleteTestOwnedBackupRemoval: true,
                    semanticRestoreVerifier: nil
                )
            )
        }

        let fallbackURL = operationDirectory
            .appendingPathComponent("V2FallbackStoreFamily-v1", isDirectory: true)
            .appendingPathComponent(verifiedBackupURL.lastPathComponent, isDirectory: false)
        let fallback = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: verifiedBackupURL,
                backupStoreURL: fallbackURL,
                sourceLocation: .disposableTestStore,
                sourceClosureEvidence: .closedForDisposableVerification,
                allowIncompleteTestOwnedBackupRemoval: true,
                semanticRestoreVerifier: nil
            )
        )

        #expect(verifiedBackup.backupAfter == fallback.sourceBefore)
        #expect(fallback.sourceBefore == fallback.sourceAfter)
        #expect(fallback.backupAfter.storeFileName == verifiedBackupURL.lastPathComponent)
        #expect(fallback.fileVerificationPassed)
        #expect(fallback.backupIdentity == fallback.backupAfter.diagnosticIdentity)
        #expect(fallbackURL.deletingLastPathComponent().standardizedFileURL != verifiedBackupURL.deletingLastPathComponent().standardizedFileURL)
    }

    private func diagnosticBaseline(identity: String, countOffset: Int, runnerStatus: String) -> ScoreKeepMigrationBaselineRecord {
        ScoreKeepMigrationBaselineRecord(
            schemaVersion: 1,
            schemaClassification: "schema-\(identity)",
            gameCount: 1 + countOffset,
            teamCount: 2 + countOffset,
            playerCount: 3 + countOffset,
            lineupCount: 4 + countOffset,
            atbatCount: 5 + countOffset,
            pitcherCount: 6 + countOffset,
            teamCreationOperationEvidenceCount: 7 + countOffset,
            canonicalHistoryCount: 8 + countOffset,
            canonicalEventCount: 9 + countOffset,
            canonicalPayloadCount: 10 + countOffset,
            canonicalOperationCount: 11 + countOffset,
            canonicalCorrectionCount: 12 + countOffset,
            legacyScoringOperationEvidenceCount: 13 + countOffset,
            stableIdentityFingerprint: "stable-\(identity)",
            relationshipFingerprint: "relationships-\(identity)",
            orderingFingerprint: "ordering-\(identity)",
            scoreEvidence: "scores-\(identity)",
            substitutionEvidence: "substitutions-\(identity)",
            mediaOwnershipFingerprint: "media-\(identity)",
            importSourceClassification: "import-\(identity)",
            difficultRunnerSequence: ScoreKeepDifficultRunnerSequenceEvidence(
                status: runnerStatus,
                runnerIdentityFingerprint: "runner-\(identity)",
                originatingAtbatFingerprint: "origin-\(identity)",
                interveningAtbatOrderFingerprint: "intervening-\(identity)",
                runnerOutEvidence: "runnerOut-\(identity)",
                thirdOutClassification: "thirdOut-\(identity)",
                inningBoundary: "inning-\(identity)",
                nextBatterEvidence: "next-\(identity)",
                scoreBeforeBoundary: "before-\(identity)",
                scoreAfterBoundary: "after-\(identity)",
                unsupportedFacts: ["unsupported-\(identity)"]
            ),
            capturedAt: Date(timeIntervalSince1970: TimeInterval(countOffset)),
            status: "status-\(identity)",
            diagnosticCodes: ["diagnostic-\(identity)"]
        )
    }

    private func backupStoreURL(fileName: String = "ScoreKeep.store") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepSourcePreservationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }
}
#endif
