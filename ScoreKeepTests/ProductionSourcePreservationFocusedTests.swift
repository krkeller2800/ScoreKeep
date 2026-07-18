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

    private func backupStoreURL(fileName: String = "ScoreKeep.store") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepSourcePreservationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }
}
#endif
