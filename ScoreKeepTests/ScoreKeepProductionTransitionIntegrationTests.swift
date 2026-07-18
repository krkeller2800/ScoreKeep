import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Production layout simulation integration")
struct ScoreKeepProductionTransitionIntegrationTests {
    @Test("orchestrator in injected production layout fails closed before hosted V2 plus V3 construction")
    func orchestratorInInjectedLayoutFailsClosedBeforeHostedV2PlusV3Construction() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        try environment.createControlDirectories()
        let source = try environment.createUnversionedSource(.representative)
        let family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: source.url)
        let totalBytes = family.members.reduce(UInt64(0)) { $0 + $1.byteCount }
        let capacityInput = ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: totalBytes)
        let required = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: capacityInput))
        let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(input: capacityInput, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: required, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: false))
        #expect(capacity.mayProceed)

        let backupURL = environment.layout.operationBackupStoreURL(operationIdentity: environment.operationIdentity, storeFileName: source.url.lastPathComponent)
        let targetURL = environment.layout.operationTemporaryTargetURL(operationIdentity: environment.operationIdentity, storeFileName: source.url.lastPathComponent)
        let result = try ScoreKeepMigrationOrchestrator.run(input: ScoreKeepMigrationOrchestratorInput(
            operationIdentity: environment.operationIdentity,
            sourceStoreURL: source.url,
            backupStoreURL: backupURL,
            targetStoreURL: targetURL,
            sourceClassification: .populatedCurrentUnversionedStore,
            disableState: .proposedTransitionExplicitlyAuthorized,
            authorizationEvidence: "test-only-production-layout-authorization",
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: nil,
            factoryInjection: nil,
            semanticRestoreVerifier: { restoreURL in
                let restored = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: restoreURL)
                return try IsolatedUnversionedProductionStoreSupport.snapshot(from: restored, fixtureIdentity: source.snapshot.fixtureIdentity) == source.snapshot
            },
            postOpenVerifier: { container in
                try IsolatedUnversionedProductionStoreSupport.snapshot(from: container, fixtureIdentity: source.snapshot.fixtureIdentity) == source.snapshot
            }
        ), journalStore: try environment.journalStore())

        #expect(result.disposition == .constructionFailed)
        #expect(result.journal.phase == .failedSafely)
        #expect(result.journal.containerConstructionDisposition == .unsafe)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: result.disposition) == .retryProhibited)
        let backupAssessment = ScoreKeepMigrationCleanupAssessor.assess(ScoreKeepMigrationCleanupAssessmentInput(
            artifactURL: backupURL.deletingLastPathComponent(),
            artifactRole: .verifiedBackup,
            retentionCategory: .verifiedSourceBackup,
            journalPhase: .completionRecorded,
            disableState: result.journal.disableState,
            startupOwnership: result.journal.startupOwnership,
            verificationStatus: .failed,
            retentionGeneration: result.journal.transitionGeneration,
            authorization: .testOwnedExplicit,
            activeOperationIdentity: environment.operationIdentity,
            artifactOperationIdentity: environment.operationIdentity,
            authorizedMigrationRoot: environment.layout.migrationControlRoot,
            testOwnedRoot: environment.root
        ))
        #expect(backupAssessment.disposition == .verifiedBackupStillRequired)
        #expect(ScoreKeepContainerStartupSelection.currentDefault == .legacyActive)
    }

    @Test("empty unversioned and existing proposed v2 simulations remain test owned")
    func additionalSimulationShapesAreTestOwned() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        let empty = try environment.createUnversionedSource(.empty)
        let proposed = environment.layout.operationTemporaryTargetURL(operationIdentity: environment.operationIdentity)
        try FileManager.default.createDirectory(at: proposed.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: proposed)
        #expect(empty.url.path.contains("ScoreKeepUnversionedCompatibility"))
        #expect(ScoreKeepProductionPathValidator.contains(environment.root, proposed))
    }
}
