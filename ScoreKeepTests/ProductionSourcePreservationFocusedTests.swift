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

    private func backupStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepSourcePreservationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ScoreKeep.store")
    }
}
#endif
