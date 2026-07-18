import Foundation
import SwiftData
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@MainActor
@Suite("V3 destination verification and rollback reconciliation")
struct V3DestinationVerificationRollbackTests {
    @Test("valid migrated fixture candidate verifies as V3 and remains unpromoted")
    func validMigratedFixtureCandidateVerifiesAsV3AndRemainsUnpromoted() throws {
        let fixture = try makeMigratedFixture()
        let expected = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: fixture.container.mainContext)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: fixture.sourceURL)
        let backupBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: fixture.backupURL)

        let verified = try ScoreKeepMigrationOrchestrator.run(
            input: input(fixture: fixture, expected: expected, sourceIdentity: sourceBefore.diagnosticIdentity, backupIdentity: backupBefore.diagnosticIdentity),
            journalStore: fixture.journalStore
        )

        #expect(verified.disposition == .destinationVerified)
        #expect(verified.journal.phase == .destinationVerificationSucceeded)
        #expect(verified.journal.completionDisposition == "candidateEligibleForLaterAcceptance")
        #expect(verified.journal.recoveryRequirement == .restoreFromVerifiedBackup)
        #expect(verified.container == nil)
        #expect(verified.writeReadiness.permitsBaseballWrites == false)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: fixture.sourceURL) == sourceBefore)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: fixture.backupURL) == backupBefore)
    }

    @Test("missing baseline and metadata mismatch fail closed")
    func missingBaselineAndMetadataMismatchFailClosed() throws {
        let fixture = try makeMigratedFixture()
        let missing = ScoreKeepDestinationVerifier.verify(
            container: fixture.container,
            input: verifierInput(fixture: fixture, expected: nil)
        )
        #expect(missing.passed == false)
        #expect(missing.evidence.failure == .unsupportedVerificationEvidence)
        #expect(missing.diagnosticCode == .destinationUnsupportedVerificationEvidence)

        let expected = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: fixture.container.mainContext)
        var badAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: fixture.targetURL)
        badAssessment = ScoreKeepProductionStoreMetadataAssessment(
            sourceClassification: .unknownVersion,
            hashEntryCount: badAssessment.hashEntryCount,
            versionIdentifierCount: badAssessment.versionIdentifierCount,
            matchingRegisteredVersions: [],
            selectedStartupRoute: badAssessment.selectedStartupRoute,
            hashKeyNames: badAssessment.hashKeyNames,
            versionHashEvidence: badAssessment.versionHashEvidence,
            versionHashEvidenceDigestPrefix: badAssessment.versionHashEvidenceDigestPrefix,
            versionHashEvidenceMalformed: badAssessment.versionHashEvidenceMalformed,
            familyDiagnosticIdentity: badAssessment.familyDiagnosticIdentity,
            primaryStoreDiagnosticIdentity: badAssessment.primaryStoreDiagnosticIdentity,
            primaryPresent: badAssessment.primaryPresent,
            walPresent: badAssessment.walPresent,
            shmPresent: badAssessment.shmPresent
        )
        let metadata = ScoreKeepDestinationVerifier.verify(
            container: fixture.container,
            input: verifierInput(fixture: fixture, expected: expected, assessment: badAssessment)
        )
        #expect(metadata.passed == false)
        #expect(metadata.evidence.failure == .metadataMismatch)
    }

    @Test("count identity relationship and canonical mismatches fail closed")
    func countIdentityRelationshipAndCanonicalMismatchesFailClosed() throws {
        let fixture = try makeMigratedFixture()
        let expected = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: fixture.container.mainContext)

        var wrongCounts = expected
        wrongCounts = ScoreKeepMigrationBaselineRecord(
            schemaVersion: expected.schemaVersion,
            schemaClassification: expected.schemaClassification,
            gameCount: expected.gameCount + 1,
            teamCount: expected.teamCount,
            playerCount: expected.playerCount,
            lineupCount: expected.lineupCount,
            atbatCount: expected.atbatCount,
            pitcherCount: expected.pitcherCount,
            teamCreationOperationEvidenceCount: expected.teamCreationOperationEvidenceCount,
            canonicalHistoryCount: expected.canonicalHistoryCount,
            canonicalEventCount: expected.canonicalEventCount,
            canonicalPayloadCount: expected.canonicalPayloadCount,
            canonicalOperationCount: expected.canonicalOperationCount,
            canonicalCorrectionCount: expected.canonicalCorrectionCount,
            legacyScoringOperationEvidenceCount: expected.legacyScoringOperationEvidenceCount,
            stableIdentityFingerprint: expected.stableIdentityFingerprint,
            relationshipFingerprint: expected.relationshipFingerprint,
            orderingFingerprint: expected.orderingFingerprint,
            scoreEvidence: expected.scoreEvidence,
            substitutionEvidence: expected.substitutionEvidence,
            mediaOwnershipFingerprint: expected.mediaOwnershipFingerprint,
            importSourceClassification: expected.importSourceClassification,
            difficultRunnerSequence: expected.difficultRunnerSequence,
            capturedAt: expected.capturedAt,
            status: expected.status,
            diagnosticCodes: expected.diagnosticCodes
        )
        #expect(ScoreKeepDestinationVerifier.verify(container: fixture.container, input: verifierInput(fixture: fixture, expected: wrongCounts)).evidence.failure == .countMismatch)

        var wrongIdentity = expected
        wrongIdentity = clone(expected, stableIdentityFingerprint: "different")
        #expect(ScoreKeepDestinationVerifier.verify(container: fixture.container, input: verifierInput(fixture: fixture, expected: wrongIdentity)).evidence.failure == .identifierMismatch)

        var wrongRelationship = expected
        wrongRelationship = clone(expected, relationshipFingerprint: "different")
        #expect(ScoreKeepDestinationVerifier.verify(container: fixture.container, input: verifierInput(fixture: fixture, expected: wrongRelationship)).evidence.failure == .relationshipMismatch)

        var wrongCanonical = expected
        wrongCanonical = clone(expected, canonicalHistoryCount: 1)
        #expect(ScoreKeepDestinationVerifier.verify(container: fixture.container, input: verifierInput(fixture: fixture, expected: wrongCanonical)).evidence.failure == .countMismatch)

        let context = fixture.container.mainContext
        let game = try #require(try context.fetch(FetchDescriptor<Game>()).first)
        context.insert(CanonicalGameHistoryRecord(gameIdentity: game.ident))
        #expect(ScoreKeepDestinationVerifier.verify(container: fixture.container, input: verifierInput(fixture: fixture, expected: expected)).evidence.failure == .countMismatch)
    }

    @Test("source or backup identity mismatch fails closed")
    func sourceOrBackupIdentityMismatchFailsClosed() throws {
        let fixture = try makeMigratedFixture()
        let expected = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: fixture.container.mainContext)
        let result = ScoreKeepDestinationVerifier.verify(
            container: fixture.container,
            input: verifierInput(fixture: fixture, expected: expected, sourceIdentity: "changed")
        )

        #expect(result.passed == false)
        #expect(result.evidence.failure == .sourceOrBackupImmutabilityMismatch)
    }

    private func makeMigratedFixture() throws -> MigratedFixture {
        let sourceURL = try FrozenV2FixtureTestSupport322D.copiedPrimaryStoreURL()
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("V3DestinationVerification-\(UUID().uuidString)", isDirectory: true)
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let targetURL = root.appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let journalStore = ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        let operation = operationIdentity(sourceIdentity: sourceBefore.diagnosticIdentity)
        let pending = try ScoreKeepMigrationOrchestrator.run(
            input: ScoreKeepMigrationOrchestratorInput(
                operationIdentity: operation,
                sourceStoreURL: sourceURL,
                backupStoreURL: backupURL,
                targetStoreURL: targetURL,
                sourceClassification: .existingProposedV2Store,
                disableState: .proposedTransitionExplicitlyAuthorized,
                authorizationEvidence: "task-3.22d-fixture-boundary",
                sourceClosureEvidence: .closedForDisposableVerification,
                interruptionPoint: .afterContainerConstructionReturns,
                factoryInjection: nil,
                semanticRestoreVerifier: { restoreURL in
                    ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL).sourceClassification == .existingProposedV2Store
                },
                postOpenVerifier: nil
            ),
            journalStore: journalStore
        )
        let container = try #require(pending.container)
        return MigratedFixture(sourceURL: sourceURL, backupURL: backupURL, targetURL: targetURL, journalStore: journalStore, operation: operation, container: container)
    }

    private func input(
        fixture: MigratedFixture,
        expected: ScoreKeepMigrationBaselineRecord?,
        sourceIdentity: String? = nil,
        backupIdentity: String? = nil
    ) -> ScoreKeepMigrationOrchestratorInput {
        ScoreKeepMigrationOrchestratorInput(
            operationIdentity: fixture.operation,
            sourceStoreURL: fixture.sourceURL,
            backupStoreURL: fixture.backupURL,
            targetStoreURL: fixture.targetURL,
            sourceClassification: .existingProposedV2Store,
            disableState: .proposedTransitionExplicitlyAuthorized,
            authorizationEvidence: "task-3.22d-fixture-boundary",
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: nil,
            factoryInjection: nil,
            semanticRestoreVerifier: nil,
            postOpenVerifier: nil,
            expectedSourceBaseline: expected,
            expectedSourceFamilyIdentity: sourceIdentity,
            expectedBackupFamilyIdentity: backupIdentity
        )
    }

    private func verifierInput(
        fixture: MigratedFixture,
        expected: ScoreKeepMigrationBaselineRecord?,
        sourceIdentity: String? = nil,
        assessment: ScoreKeepProductionStoreMetadataAssessment? = nil
    ) -> ScoreKeepDestinationVerificationInput {
        ScoreKeepDestinationVerificationInput(
            operationIdentity: fixture.operation,
            candidateStoreURL: fixture.targetURL,
            sourceStoreURL: fixture.sourceURL,
            backupStoreURL: fixture.backupURL,
            expectedSourceBaseline: expected,
            expectedSourceFamilyIdentity: sourceIdentity,
            expectedBackupFamilyIdentity: nil,
            candidateAssessmentOverride: assessment
        )
    }

    private func operationIdentity(sourceIdentity: String) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceIdentity,
            sourceSchema: .existingProposedV2Store,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: 322,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-00000003220d")!
        )
    }

    private func clone(
        _ record: ScoreKeepMigrationBaselineRecord,
        canonicalHistoryCount: Int? = nil,
        stableIdentityFingerprint: String? = nil,
        relationshipFingerprint: String? = nil
    ) -> ScoreKeepMigrationBaselineRecord {
        ScoreKeepMigrationBaselineRecord(
            schemaVersion: record.schemaVersion,
            schemaClassification: record.schemaClassification,
            gameCount: record.gameCount,
            teamCount: record.teamCount,
            playerCount: record.playerCount,
            lineupCount: record.lineupCount,
            atbatCount: record.atbatCount,
            pitcherCount: record.pitcherCount,
            teamCreationOperationEvidenceCount: record.teamCreationOperationEvidenceCount,
            canonicalHistoryCount: canonicalHistoryCount ?? record.canonicalHistoryCount,
            canonicalEventCount: record.canonicalEventCount,
            canonicalPayloadCount: record.canonicalPayloadCount,
            canonicalOperationCount: record.canonicalOperationCount,
            canonicalCorrectionCount: record.canonicalCorrectionCount,
            legacyScoringOperationEvidenceCount: record.legacyScoringOperationEvidenceCount,
            stableIdentityFingerprint: stableIdentityFingerprint ?? record.stableIdentityFingerprint,
            relationshipFingerprint: relationshipFingerprint ?? record.relationshipFingerprint,
            orderingFingerprint: record.orderingFingerprint,
            scoreEvidence: record.scoreEvidence,
            substitutionEvidence: record.substitutionEvidence,
            mediaOwnershipFingerprint: record.mediaOwnershipFingerprint,
            importSourceClassification: record.importSourceClassification,
            difficultRunnerSequence: record.difficultRunnerSequence,
            capturedAt: record.capturedAt,
            status: record.status,
            diagnosticCodes: record.diagnosticCodes
        )
    }
}

private struct MigratedFixture {
    let sourceURL: URL
    let backupURL: URL
    let targetURL: URL
    let journalStore: ScoreKeepMigrationJournalStore
    let operation: ScoreKeepMigrationOperationIdentity
    let container: ModelContainer
}

private enum FrozenV2FixtureTestSupport322D {
    static func copiedPrimaryStoreURL() throws -> URL {
        let sourceDirectory = try fixtureDirectory()
        let copyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrozenV2FixtureDestinationVerification-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: copyDirectory, withIntermediateDirectories: true)
        for name in ["FrozenV2Synthetic.sqlite", "FrozenV2Synthetic.sqlite-shm", "FrozenV2Synthetic.sqlite-wal"] {
            try FileManager.default.copyItem(
                at: sourceDirectory.appendingPathComponent(name),
                to: copyDirectory.appendingPathComponent(name)
            )
        }
        return copyDirectory.appendingPathComponent("FrozenV2Synthetic.sqlite")
    }

    private static func fixtureDirectory() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryURL(
            "ScoreKeep/Docs/Verification/Fixtures/FrozenV2/RepresentativeSyntheticV2"
        )
    }
}
#endif
