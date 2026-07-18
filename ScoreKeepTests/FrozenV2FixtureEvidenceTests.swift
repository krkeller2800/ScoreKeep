import CoreData
import CryptoKit
import Foundation
import Testing
@testable import ScoreKeep

@Suite("Frozen V2 fixture evidence")
struct FrozenV2FixtureEvidenceTests {
    @Test("manifest parses and records the Task 3.22B boundary")
    func manifestParsesAndRecordsTask322BBoundary() throws {
        let manifest = try FrozenV2FixtureTestSupport.loadManifest()

        #expect(manifest.fixtureIdentifier == "frozen-v2-representative-synthetic-001")
        #expect(manifest.provenance.sourceCommit == "91dd5c3fd26301e47f898dfaeedbde9cde35a3d9")
        #expect(manifest.provenance.startingCommit == "50d950b2ecc060b307cf696caf5aa850e12dc0dc")
        #expect(manifest.provenance.generationBoundary.contains("Standalone SwiftData executable"))
        #expect(manifest.syntheticDataDeclaration.isSynthetic)
        #expect(manifest.syntheticDataDeclaration.containsPrivateUserData == false)
        #expect(manifest.limitations.contains { $0.contains("not independent production source semantic opening") })
    }

    @Test("fixture store family is present and immutable by digest")
    func fixtureStoreFamilyIsPresentAndImmutableByDigest() throws {
        let manifest = try FrozenV2FixtureTestSupport.loadManifest()
        let fixtureDirectory = try FrozenV2FixtureTestSupport.fixtureDirectory()
        let expectedFiles = manifest.storeFamily.map(\.fileName).sorted()
        let observedFiles = try FileManager.default.contentsOfDirectory(atPath: fixtureDirectory.path)
            .filter { $0 == "FrozenV2Synthetic.sqlite" || $0.hasPrefix("FrozenV2Synthetic.sqlite-") }
            .sorted()

        #expect(observedFiles == expectedFiles)

        for member in manifest.storeFamily {
            let url = fixtureDirectory.appendingPathComponent(member.fileName)
            let data = try Data(contentsOf: url)
            #expect(UInt64(data.count) == member.byteCount)
            #expect(FrozenV2FixtureTestSupport.sha256Hex(data) == member.sha256Hex)
        }
    }

    @Test("Core Data metadata matches the frozen V2 manifest")
    func coreDataMetadataMatchesFrozenV2Manifest() throws {
        let manifest = try FrozenV2FixtureTestSupport.loadManifest()
        let storeURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL
        )
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        let identifiers = metadata[NSStoreModelVersionIdentifiersKey] as? [Any] ?? []
        let observedHashes = hashes.mapValues(FrozenV2FixtureTestSupport.hex).map {
            FrozenV2ModelVersionHash(entityName: $0.key, versionHashHex: $0.value)
        }.sorted { $0.entityName < $1.entityName }

        #expect(observedHashes == manifest.storeMetadata.modelVersionHashes)
        #expect(identifiers.map(String.init(describing:)) == manifest.storeMetadata.storeVersionIdentifiers)
        #expect(Set(observedHashes.map(\.entityName)) == Set(manifest.declaredModelInventory))
        #expect(Set(observedHashes.map(\.entityName)).intersection(manifest.absentCanonicalModels).isEmpty)
    }

    @Test("production metadata assessment recognizes fixture as Proposed V2")
    func productionMetadataAssessmentRecognizesFixtureAsProposedV2() throws {
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL())

        #expect(assessment.sourceClassification == .existingProposedV2Store)
        #expect(assessment.matchingRegisteredVersions == ["V2"])
        #expect(assessment.hashEntryCount == 7)
        #expect(assessment.hashKeyNames == [
            "Atbat",
            "Game",
            "Lineup",
            "Pitcher",
            "Player",
            "Team",
            "TeamCreationOperationEvidenceRecord"
        ])
        #expect(assessment.primaryPresent)
        #expect(assessment.walPresent)
        #expect(assessment.shmPresent)
    }

    @Test("exact frozen V2 metadata rejects missing altered and extra hashes")
    func exactFrozenV2MetadataRejectsMissingAlteredAndExtraHashes() throws {
        let v2 = try FrozenV2FixtureTestSupport.frozenV2Evidence()
        var missing = v2.entries
        _ = missing.popLast()
        var altered = v2.entries
        altered[0] = .init(entityName: altered[0].entityName, versionHash: Data([0]))
        let extra = v2.entries + [.init(entityName: "ExtraEntity", versionHash: Data([1]))]

        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2, versionIdentifiers: ["2.0.0"]) == ["V2"])
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2, versionIdentifiers: []).isEmpty)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(ScoreKeepCoreDataVersionHashEvidence(entries: missing), versionIdentifiers: ["2.0.0"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(ScoreKeepCoreDataVersionHashEvidence(entries: altered), versionIdentifiers: ["2.0.0"]).isEmpty)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(ScoreKeepCoreDataVersionHashEvidence(entries: extra), versionIdentifiers: ["2.0.0"]).isEmpty)
    }

    @Test("V1 V3 unknown and malformed metadata do not qualify as frozen V2")
    func v1V3UnknownAndMalformedMetadataDoNotQualifyAsFrozenV2() throws {
        let registered = Dictionary(uniqueKeysWithValues: ScoreKeepProductionStoreMetadataAssessment.registeredVersionEvidenceForTesting.map { ($0.0, $0.1) })
        let v1 = try #require(registered["V1"])
        let v3 = try #require(registered["V3"])
        let unknown = ScoreKeepCoreDataVersionHashEvidence.make(entityHashes: [("Unknown", Data([1]))])

        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v1, versionIdentifiers: ["2.0.0"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v3, versionIdentifiers: ["2.0.0"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(unknown, versionIdentifiers: ["2.0.0"]).isEmpty)
        #expect(ScoreKeepCoreDataVersionHashEvidence.make(from: ["Game": "malformed"]) == nil)
    }

    @MainActor
    @Test("copied workspace migration boundary preserves source and backup and stops unpromoted")
    func copiedWorkspaceMigrationBoundaryPreservesSourceAndBackupAndStopsUnpromoted() throws {
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrozenV2CopiedWorkspaceBoundary-\(UUID().uuidString)", isDirectory: true)
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let targetURL = root.appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let journalStore = ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        let operation = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceBefore.diagnosticIdentity,
            sourceSchema: .existingProposedV2Store,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: 322,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000032203")!
        )

        let result = try ScoreKeepMigrationOrchestrator.run(
            input: ScoreKeepMigrationOrchestratorInput(
                operationIdentity: operation,
                sourceStoreURL: sourceURL,
                backupStoreURL: backupURL,
                targetStoreURL: targetURL,
                sourceClassification: .existingProposedV2Store,
                disableState: .proposedTransitionExplicitlyAuthorized,
                authorizationEvidence: "task-3.22c-fixture-boundary",
                sourceClosureEvidence: .closedForDisposableVerification,
                interruptionPoint: nil,
                factoryInjection: nil,
                semanticRestoreVerifier: { restoreURL in
                    ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL).sourceClassification == .existingProposedV2Store
                },
                postOpenVerifier: { _ in
                    Issue.record("Task 3.22C must stop before destination semantic verification")
                    return false
                }
            ),
            journalStore: journalStore
        )

        let sourceAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let backupAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
        let workspaceAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: targetURL)

        #expect(result.disposition == .verificationFailed)
        #expect(result.container == nil)
        #expect(result.journal.phase == .destinationVerificationFailed)
        #expect(result.journal.backupVerificationDisposition == .backupVerified)
        #expect(result.journal.postOpenVerificationDisposition.contains("failure.unsupportedVerificationEvidence"))
        #expect(result.diagnostics == [.destinationUnsupportedVerificationEvidence])
        #expect(result.writeReadiness.permitsBaseballWrites == false)
        #expect(sourceAfter == sourceBefore)
        #expect(try ScoreKeepStoreFamilyDiscovery.validateBackup(source: sourceBefore, backup: backupAfter, sourceURL: sourceURL, backupURL: backupURL))
        #expect(workspaceAfter.isComplete)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: sourceURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL).sourceClassification == .existingProposedV3Store)
    }

    @MainActor
    @Test("retry reuses operation identity and does not duplicate verified backup")
    func retryReusesOperationIdentityAndDoesNotDuplicateVerifiedBackup() throws {
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceFamily = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrozenV2CopiedWorkspaceRetry-\(UUID().uuidString)", isDirectory: true)
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let targetURL = root.appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let journalStore = ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        let operation = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceFamily.diagnosticIdentity,
            sourceSchema: .existingProposedV2Store,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: 322,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000032204")!
        )
        let input = ScoreKeepMigrationOrchestratorInput(
            operationIdentity: operation,
            sourceStoreURL: sourceURL,
            backupStoreURL: backupURL,
            targetStoreURL: targetURL,
            sourceClassification: .existingProposedV2Store,
            disableState: .proposedTransitionExplicitlyAuthorized,
            authorizationEvidence: "task-3.22c-fixture-retry",
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: .afterBackupVerification,
            factoryInjection: nil,
            semanticRestoreVerifier: { restoreURL in
                ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL).sourceClassification == .existingProposedV2Store
            },
            postOpenVerifier: nil
        )

        let interrupted = try ScoreKeepMigrationOrchestrator.run(input: input, journalStore: journalStore)
        let backupIdentity = interrupted.journal.backupIdentity
        let resumed = try ScoreKeepMigrationOrchestrator.run(
            input: ScoreKeepMigrationOrchestratorInput(
                operationIdentity: operation,
                sourceStoreURL: sourceURL,
                backupStoreURL: backupURL,
                targetStoreURL: targetURL,
                sourceClassification: .existingProposedV2Store,
                disableState: .proposedTransitionExplicitlyAuthorized,
                authorizationEvidence: "task-3.22c-fixture-retry",
                sourceClosureEvidence: .closedForDisposableVerification,
                interruptionPoint: nil,
                factoryInjection: nil,
                semanticRestoreVerifier: nil,
                postOpenVerifier: nil
            ),
            journalStore: journalStore
        )
        let backupRootContents = try FileManager.default.contentsOfDirectory(atPath: backupURL.deletingLastPathComponent().path).sorted()

        #expect(interrupted.disposition == .interrupted)
        #expect(interrupted.journal.operationIdentity == operation)
        #expect(resumed.journal.operationIdentity == operation)
        #expect(resumed.journal.backupIdentity == backupIdentity)
        #expect(backupRootContents == sourceFamily.fileNames)
        #expect(resumed.disposition == .verificationFailed)
        #expect(resumed.journal.phase == .destinationVerificationFailed)
        #expect(resumed.diagnostics == [.destinationUnsupportedVerificationEvidence])
    }

    @Test("manifest records expected V2 counts relationships and canonical absence")
    func manifestRecordsExpectedV2CountsRelationshipsAndCanonicalAbsence() throws {
        let manifest = try FrozenV2FixtureTestSupport.loadManifest()

        #expect(manifest.expectedRecordCounts["Game"] == 1)
        #expect(manifest.expectedRecordCounts["Team"] == 2)
        #expect(manifest.expectedRecordCounts["Player"] == 4)
        #expect(manifest.expectedRecordCounts["Atbat"] == 2)
        #expect(manifest.expectedRecordCounts["Lineup"] == 1)
        #expect(manifest.expectedRecordCounts["Pitcher"] == 1)
        #expect(manifest.expectedRecordCounts["TeamCreationOperationEvidenceRecord"] == 1)
        for canonicalModel in manifest.absentCanonicalModels {
            #expect(manifest.expectedRecordCounts[canonicalModel] == 0)
        }
        #expect(manifest.expectedRelationshipFacts.count == 10)
        #expect(manifest.expectedRelationshipFacts.contains { $0.contains("home team and a visiting team") })
        #expect(manifest.expectedRelationshipFacts.contains { $0.contains("team-creation operation evidence") })
    }

    @Test("current hosted tests retain the no V2 plus V3 construction boundary")
    func currentHostedTestsRetainNoV2PlusV3ConstructionBoundary() throws {
        let source = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeepTests/VersionedCanonicalScoringPersistenceTests.swift")
        let factory = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/Common/ScoreKeepProposedContainerFactory.swift")

        #expect(source.contains("func v2ToV3RuntimeMigrationProofRequiresIsolatedV2Boundary"))
        #expect(source.contains("testSource.contains(\"ScoreKeepProposedCanonicalScoringStorageMigrationPlan\") == false"))
        #expect(source.contains("testSource.contains(\"Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)\") == false"))
        #expect(source.contains("testSource.contains(\"ModelContainer(for: v2Schema\") == false"))
        #expect(factory.contains("semanticVerifierUnavailableCurrentTargetV2AndV3DuplicateEffectiveChecksums"))
    }
}

@MainActor
@Suite("Task 3.22E migration acceptance")
struct MigrationAcceptanceTask322ETests {
    @Test("frozen V2 fixture migrates through copied workspace and remains unpromoted")
    func frozenV2FixtureMigratesThroughCopiedWorkspaceAndRemainsUnpromoted() throws {
        let manifest = try FrozenV2FixtureTestSupport.loadManifest()
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: sourceURL)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = temporaryRoot()
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let targetURL = root.appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let journalStore = ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        let operation = operationIdentity(sourceIdentity: sourceBefore.diagnosticIdentity)

        #expect(sourceAssessment.sourceClassification == .existingProposedV2Store)
        #expect(sourceAssessment.matchingRegisteredVersions == ["V2"])
        #expect(sourceAssessment.hashEntryCount == 7)
        #expect(sourceBefore.fileNames == manifest.storeFamily.map(\.fileName).sorted())
        #expect(Set(sourceAssessment.hashKeyNames).intersection(manifest.absentCanonicalModels).isEmpty)

        let interrupted = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                operation: operation,
                sourceURL: sourceURL,
                backupURL: backupURL,
                targetURL: targetURL,
                interruptionPoint: .afterContainerConstructionReturns
            ),
            journalStore: journalStore
        )
        let candidateContainer = try #require(interrupted.container)
        let expected = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: candidateContainer.mainContext)
        let backupBeforeResume = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
        let targetBeforeResume = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: targetURL)

        assertBaseline(expected, matches: manifest)
        #expect(interrupted.disposition == .interrupted)
        #expect(interrupted.journal.phase == .containerConstructed)
        #expect(interrupted.journal.operationIdentity == operation)
        #expect(interrupted.writeReadiness.permitsBaseballWrites == false)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL) == sourceBefore)
        #expect(try ScoreKeepStoreFamilyDiscovery.validateBackup(source: sourceBefore, backup: backupBeforeResume, sourceURL: sourceURL, backupURL: backupURL))
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: sourceURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL).sourceClassification == .existingProposedV3Store)

        let verified = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                operation: operation,
                sourceURL: sourceURL,
                backupURL: backupURL,
                targetURL: targetURL,
                expected: expected,
                expectedSourceIdentity: sourceBefore.diagnosticIdentity,
                expectedBackupIdentity: backupBeforeResume.diagnosticIdentity
            ),
            journalStore: journalStore
        )
        let sourceAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let backupAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
        let targetAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: targetURL)

        #expect(verified.disposition == .destinationVerified)
        #expect(verified.journal.phase == .destinationVerificationSucceeded)
        #expect(verified.journal.operationIdentity == operation)
        #expect(verified.journal.completionDisposition == "candidateEligibleForLaterAcceptance")
        #expect(verified.journal.recoveryRequirement == .restoreFromVerifiedBackup)
        #expect(verified.journal.startupOwnership == .released)
        #expect(verified.container == nil)
        #expect(verified.writeReadiness.permitsBaseballWrites == false)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: verified.disposition) == .recoveryRequired)
        #expect(sourceAfter == sourceBefore)
        #expect(backupAfter == backupBeforeResume)
        #expect(targetAfter.isComplete)
        #expect(targetAfter.diagnosticIdentity == targetBeforeResume.diagnosticIdentity)
        #expect(try ScoreKeepStoreFamilyDiscovery.validateBackup(source: sourceBefore, backup: backupAfter, sourceURL: sourceURL, backupURL: backupURL))
        #expect(try FileManager.default.contentsOfDirectory(atPath: backupURL.deletingLastPathComponent().path).sorted() == sourceBefore.fileNames)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: sourceURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL).sourceClassification == .existingProposedV3Store)
        #expect(ScoreKeepProposedVersionedSchema.productionBoundaryStatement.contains("production scoring remains Legacy"))
    }

    @Test("metadata source failures fail closed before source migration")
    func metadataSourceFailuresFailClosedBeforeSourceMigration() throws {
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let targetURL = temporaryRoot().appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let v2 = try FrozenV2FixtureTestSupport.frozenV2Evidence()
        let registered = Dictionary(uniqueKeysWithValues: ScoreKeepProductionStoreMetadataAssessment.registeredVersionEvidenceForTesting.map { ($0.0, $0.1) })
        let v1 = try #require(registered["V1"])
        let v3 = try #require(registered["V3"])
        let missingHash = ScoreKeepCoreDataVersionHashEvidence(entries: Array(v2.entries.dropLast()))
        let alteredHash = ScoreKeepCoreDataVersionHashEvidence(entries: [
            .init(entityName: v2.entries[0].entityName, versionHash: Data([0]))
        ] + v2.entries.dropFirst())
        let extraEntity = ScoreKeepCoreDataVersionHashEvidence(entries: v2.entries + [
            .init(entityName: "UnexpectedEntity", versionHash: Data([1]))
        ])
        let unknown = ScoreKeepCoreDataVersionHashEvidence.make(entityHashes: [("Unknown", Data([1]))])

        #expect(matchesV2(missingHash) == false)
        #expect(matchesV2(alteredHash) == false)
        #expect(matchesV2(extraEntity) == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2, versionIdentifiers: ["wrong-version"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v1, versionIdentifiers: ["2.0.0"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v3, versionIdentifiers: ["2.0.0"]).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(unknown, versionIdentifiers: ["2.0.0"]).isEmpty)
        #expect(ScoreKeepCoreDataVersionHashEvidence.make(from: ["Game": "malformed"]) == nil)
        #expect(ScoreKeepSourceStoreClassification.existingProposedV3Store.requiresMigration == false)

        for classification in failClosedSourceClassifications {
            let factory = ScoreKeepProposedContainerFactory.construct(ScoreKeepProposedContainerFactoryInput(
                storeLocation: .disposableMigrationTarget(url: targetURL, requiresFreshDestination: false),
                writabilityMode: .writable,
                startupIntent: .isolatedVerification,
                sourceClassification: classification,
                routeChoice: .proposedV3EligibleForIsolatedVerification
            ))
            #expect(factory.container == nil)
            #expect(factory.disposition != .openedCompatibleSourceAndTransitionedToProposedV3)
        }
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL).isComplete)
    }

    @Test("preservation migration and verification failures preserve rollback")
    func preservationMigrationAndVerificationFailuresPreserveRollback() throws {
        try verifyFailure(
            factoryInjection: .containerConstructionFailure,
            expectedDisposition: .constructionFailed,
            expectedPhase: .failedSafely,
            expectedDiagnostics: [.proposedContainerConstructionFailed]
        )
        try verifyFailure(
            interruptionPoint: .afterPostOpenVerificationStarts,
            expectedDisposition: .verificationFailed,
            expectedPhase: .destinationVerificationFailed,
            expectedDiagnostics: [.destinationVerificationInterrupted]
        )

        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = temporaryRoot()
        let result = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                operation: operationIdentity(sourceIdentity: sourceBefore.diagnosticIdentity),
                sourceURL: sourceURL,
                backupURL: root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite"),
                targetURL: root.appendingPathComponent("target/FrozenV2Synthetic.sqlite"),
                semanticRestoreVerifier: { _ in false }
            ),
            journalStore: ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        )

        #expect(result.disposition == .sourcePreservationFailed)
        #expect(result.journal.phase == .recoveryRequired)
        #expect(result.recoveryRequirement == .writesRemainProhibited)
        #expect(result.failureDiagnosticIdentity == "semanticRestoreOpen.semanticBaselineMismatch")
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL) == sourceBefore)
        #expect(result.writeReadiness.permitsBaseballWrites == false)
    }

    @Test("completed journal recovery states remain deterministic and non promotional")
    func completedJournalRecoveryStatesRemainDeterministicAndNonPromotional() throws {
        let phases: [(ScoreKeepMigrationJournalPhase, ScoreKeepMigrationRecoveryRequirement)] = [
            (.destinationVerificationPending, .verifyExistingTarget),
            (.destinationVerificationInProgress, .verifyExistingTarget),
            (.destinationVerificationSucceeded, .restoreFromVerifiedBackup),
            (.destinationVerificationFailed, .verifyExistingTarget),
            (.containerConstructed, .verifyExistingTarget),
            (.backupVerified, .reuseVerifiedBackup)
        ]

        for (phase, recovery) in phases {
            var record = ScoreKeepMigrationJournalRecord.initial(
                operationIdentity: operationIdentity(sourceIdentity: "source-\(phase.rawValue)"),
                sourceStoreDiagnosticIdentity: "source-\(phase.rawValue)",
                sourceClassification: .existingProposedV2Store,
                disableState: .proposedTransitionExplicitlyAuthorized
            )
            record = try ScoreKeepMigrationJournalTransition.advance(
                record,
                to: phase,
                backupVerificationDisposition: .backupVerified,
                recoveryRequirement: recovery
            )
            #expect(ScoreKeepMigrationOrchestrator.reconcile(record) == recovery)
            #expect(ScoreKeepStartupOutcomePolicy.workflow(for: .recoveryRequired).mayWriteRecords == false)
        }

        #expect(recoveryRoute(target: .existingProposedV3Store, active: .existingProposedV2Store, backupVerified: true) == .openCompletedTargetAsV3)
        #expect(recoveryRoute(target: .unknownVersion, active: .existingProposedV2Store, backupVerified: true) == .activeV2RequiresFreshPreparation)
        #expect(recoveryRoute(target: .unknownVersion, active: .existingProposedV3Store, backupVerified: true) == .openActiveStoreAsV3)
        #expect(recoveryRoute(target: .existingProposedV2Store, active: .unknownVersion, backupVerified: true) == .recoverCompletedTargetV2ToFreshV3)
        #expect(recoveryRoute(target: .existingProposedV2Store, active: .unknownVersion, backupVerified: false) == .failClosed)
        #expect(recoveryRoute(target: .unknownVersion, active: .unknownVersion, backupVerified: true) == .failClosed)
    }

    @Test("duplicate checksum safety audit covers selected acceptance paths")
    func duplicateChecksumSafetyAuditCoversSelectedAcceptancePaths() throws {
        let factory = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeep/Common/ScoreKeepProposedContainerFactory.swift")
        let versioned = try StableIdentityAndOrderingTestSupport.repositorySource("ScoreKeepTests/VersionedCanonicalScoringPersistenceTests.swift")
        let candidatePath = try #require(factory.range(of: "private static func constructV3CandidateFromCopiedV2Workspace"))
        let candidateTail = factory[candidatePath.lowerBound...]
        let candidateEnd = try #require(candidateTail.range(of: "private static func successDisposition"))
        let candidateSource = candidateTail[..<candidateEnd.lowerBound]

        #expect(candidateSource.contains("Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)"))
        #expect(candidateSource.contains("migrationPlan: nil"))
        #expect(candidateSource.contains("Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)") == false)
        #expect(factory.contains("semanticVerifierUnavailableCurrentTargetV2AndV3DuplicateEffectiveChecksums"))
        #expect(versioned.contains("testSource.contains(\"ModelContainer(for: v2Schema\") == false"))
        #expect(versioned.contains("testSource.contains(\"Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)\") == false"))
        #expect(versioned.contains("testSource.contains(\"ScoreKeepProposedCanonicalScoringStorageMigrationPlan\") == false"))
    }

    @Test("physical comparison checks V2 backup metadata and opens only V3 target")
    func physicalComparisonChecksV2BackupMetadataAndOpensOnlyV3Target() throws {
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = temporaryRoot()
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let targetURL = root.appendingPathComponent("target/FrozenV2Synthetic.sqlite")
        let journalStore = ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        let operation = operationIdentity(sourceIdentity: sourceBefore.diagnosticIdentity)

        let interrupted = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                operation: operation,
                sourceURL: sourceURL,
                backupURL: backupURL,
                targetURL: targetURL,
                interruptionPoint: .afterContainerConstructionReturns
            ),
            journalStore: journalStore
        )
        let candidateContainer = try #require(interrupted.container)
        let baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: candidateContainer.mainContext)

        let result = try ScoreKeepPhysicalMigrationExecutor.freshProposedComparison(
            targetURL: targetURL,
            backupURL: backupURL,
            baseline: baseline
        )

        #expect(result == "matchesStoredLegacyBaseline")
        #expect(result.contains("currentTargetV2AndV3DuplicateEffectiveChecksums") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL).sourceClassification == .existingProposedV2Store)
        #expect(ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL).sourceClassification == .existingProposedV3Store)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL) == sourceBefore)
    }

    private var failClosedSourceClassifications: [ScoreKeepSourceStoreClassification] {
        [
            .proposedV1RecognizableStore,
            .unknownVersion,
            .unsupportedFutureVersion,
            .unreadableStore,
            .contradictoryMetadata,
            .emptyCurrentUnversionedStore,
            .populatedCurrentUnversionedStore
        ]
    }

    private func verifyFailure(
        interruptionPoint: ScoreKeepMigrationInterruptionPoint? = nil,
        factoryInjection: ScoreKeepProposedContainerFactoryInjection? = nil,
        expectedDisposition: ScoreKeepMigrationOrchestratorDisposition,
        expectedPhase: ScoreKeepMigrationJournalPhase,
        expectedDiagnostics: [ScoreKeepMigrationJournalDiagnosticCode]
    ) throws {
        let sourceURL = try FrozenV2FixtureTestSupport.copiedPrimaryStoreURL()
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let root = temporaryRoot()
        let backupURL = root.appendingPathComponent("backup/StoreFamily/FrozenV2Synthetic.sqlite")
        let result = try ScoreKeepMigrationOrchestrator.run(
            input: input(
                operation: operationIdentity(sourceIdentity: sourceBefore.diagnosticIdentity),
                sourceURL: sourceURL,
                backupURL: backupURL,
                targetURL: root.appendingPathComponent("target/FrozenV2Synthetic.sqlite"),
                interruptionPoint: interruptionPoint,
                factoryInjection: factoryInjection
            ),
            journalStore: ScoreKeepMigrationJournalStore(directory: root.appendingPathComponent("journal", isDirectory: true))
        )

        #expect(result.disposition == expectedDisposition)
        #expect(result.journal.phase == expectedPhase)
        #expect(result.diagnostics == expectedDiagnostics)
        #expect(result.writeReadiness.permitsBaseballWrites == false)
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL) == sourceBefore)
        if FileManager.default.fileExists(atPath: backupURL.path) {
            let backup = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)
            #expect(try ScoreKeepStoreFamilyDiscovery.validateBackup(source: sourceBefore, backup: backup, sourceURL: sourceURL, backupURL: backupURL))
        }
    }

    private func input(
        operation: ScoreKeepMigrationOperationIdentity,
        sourceURL: URL,
        backupURL: URL,
        targetURL: URL,
        interruptionPoint: ScoreKeepMigrationInterruptionPoint? = nil,
        factoryInjection: ScoreKeepProposedContainerFactoryInjection? = nil,
        semanticRestoreVerifier: ((URL) throws -> Bool)? = nil,
        expected: ScoreKeepMigrationBaselineRecord? = nil,
        expectedSourceIdentity: String? = nil,
        expectedBackupIdentity: String? = nil
    ) -> ScoreKeepMigrationOrchestratorInput {
        ScoreKeepMigrationOrchestratorInput(
            operationIdentity: operation,
            sourceStoreURL: sourceURL,
            backupStoreURL: backupURL,
            targetStoreURL: targetURL,
            sourceClassification: .existingProposedV2Store,
            disableState: .proposedTransitionExplicitlyAuthorized,
            authorizationEvidence: "task-3.22e-acceptance",
            sourceClosureEvidence: .closedForDisposableVerification,
            interruptionPoint: interruptionPoint,
            factoryInjection: factoryInjection,
            semanticRestoreVerifier: semanticRestoreVerifier ?? { restoreURL in
                ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL).sourceClassification == .existingProposedV2Store
            },
            postOpenVerifier: nil,
            expectedSourceBaseline: expected,
            expectedSourceFamilyIdentity: expectedSourceIdentity,
            expectedBackupFamilyIdentity: expectedBackupIdentity
        )
    }

    private func operationIdentity(sourceIdentity: String) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceIdentity,
            sourceSchema: .existingProposedV2Store,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: 322,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-00000003220e")!
        )
    }

    private func assertBaseline(_ baseline: ScoreKeepMigrationBaselineRecord, matches manifest: FrozenV2FixtureManifest) {
        #expect(baseline.gameCount == manifest.expectedRecordCounts["Game"])
        #expect(baseline.teamCount == manifest.expectedRecordCounts["Team"])
        #expect(baseline.playerCount == manifest.expectedRecordCounts["Player"])
        #expect(baseline.lineupCount == manifest.expectedRecordCounts["Lineup"])
        #expect(baseline.atbatCount == manifest.expectedRecordCounts["Atbat"])
        #expect(baseline.pitcherCount == manifest.expectedRecordCounts["Pitcher"])
        #expect(baseline.teamCreationOperationEvidenceCount == manifest.expectedRecordCounts["TeamCreationOperationEvidenceRecord"])
        #expect(baseline.canonicalHistoryCount == 0)
        #expect(baseline.canonicalEventCount == 0)
        #expect(baseline.canonicalPayloadCount == 0)
        #expect(baseline.canonicalOperationCount == 0)
        #expect(baseline.canonicalCorrectionCount == 0)
        #expect(baseline.stableIdentityFingerprint.isEmpty == false)
        #expect(baseline.relationshipFingerprint.isEmpty == false)
        #expect(baseline.orderingFingerprint.isEmpty == false)
        #expect(baseline.scoreEvidence.isEmpty == false)
        #expect(baseline.substitutionEvidence.isEmpty == false)
        #expect(baseline.mediaOwnershipFingerprint.isEmpty == false)
    }

    private func matchesV2(_ evidence: ScoreKeepCoreDataVersionHashEvidence) -> Bool {
        ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(evidence, versionIdentifiers: ["2.0.0"]).contains("V2")
    }

    private func recoveryRoute(
        target: ScoreKeepSourceStoreClassification,
        active: ScoreKeepSourceStoreClassification,
        backupVerified: Bool
    ) -> ScoreKeepCompletedJournalRecoveryRoute {
        ScoreKeepCompletedJournalRecoveryRouter.route(
            target: assessment(classification: target),
            active: assessment(classification: active),
            journalSourceClassification: .existingProposedV2Store,
            backupVerified: backupVerified
        )
    }

    private func assessment(classification: ScoreKeepSourceStoreClassification) -> ScoreKeepProductionStoreMetadataAssessment {
        ScoreKeepProductionStoreMetadataAssessment(
            sourceClassification: classification,
            hashEntryCount: 0,
            versionIdentifierCount: 0,
            matchingRegisteredVersions: [],
            selectedStartupRoute: "acceptance-\(classification.rawValue)",
            hashKeyNames: [],
            versionHashEvidence: nil,
            versionHashEvidenceDigestPrefix: "none",
            versionHashEvidenceMalformed: false,
            familyDiagnosticIdentity: "family.acceptance",
            primaryStoreDiagnosticIdentity: "primary.acceptance",
            primaryPresent: classification != .noStoreExists,
            walPresent: false,
            shmPresent: false
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepTask322EAcceptance-\(UUID().uuidString)", isDirectory: true)
    }
}

private enum FrozenV2FixtureTestSupport {
    static func loadManifest() throws -> FrozenV2FixtureManifest {
        let data = try Data(contentsOf: manifestURL())
        return try JSONDecoder().decode(FrozenV2FixtureManifest.self, from: data)
    }

    static func manifestURL() throws -> URL {
        try fixtureDirectory().appendingPathComponent("FrozenV2SyntheticEvidence.json")
    }

    static func primaryStoreURL() throws -> URL {
        try fixtureDirectory().appendingPathComponent("FrozenV2Synthetic.sqlite")
    }

    static func copiedPrimaryStoreURL() throws -> URL {
        let manifest = try loadManifest()
        let sourceDirectory = try fixtureDirectory()
        let copyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrozenV2FixtureMetadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: copyDirectory, withIntermediateDirectories: true)
        for member in manifest.storeFamily {
            try FileManager.default.copyItem(
                at: sourceDirectory.appendingPathComponent(member.fileName),
                to: copyDirectory.appendingPathComponent(member.fileName)
            )
        }
        return copyDirectory.appendingPathComponent("FrozenV2Synthetic.sqlite")
    }

    static func frozenV2Evidence() throws -> ScoreKeepCoreDataVersionHashEvidence {
        let manifest = try loadManifest()
        return ScoreKeepCoreDataVersionHashEvidence.make(entityHashes: manifest.storeMetadata.modelVersionHashes.map {
            ($0.entityName, data(hex: $0.versionHashHex))
        })
    }

    static func fixtureDirectory() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryURL(
            "ScoreKeep/Docs/Verification/Fixtures/FrozenV2/RepresentativeSyntheticV2"
        )
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func data(hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        return data
    }
}

private struct FrozenV2FixtureManifest: Decodable {
    let fixtureIdentifier: String
    let provenance: FrozenV2FixtureProvenance
    let declaredModelInventory: [String]
    let absentCanonicalModels: [String]
    let storeMetadata: FrozenV2StoreMetadata
    let storeFamily: [FrozenV2StoreFamilyMember]
    let expectedRecordCounts: [String: Int]
    let expectedRelationshipFacts: [String]
    let syntheticDataDeclaration: FrozenV2SyntheticDataDeclaration
    let limitations: [String]
}

private struct FrozenV2FixtureProvenance: Decodable {
    let sourceCommit: String
    let startingCommit: String
    let generationBoundary: String
}

private struct FrozenV2StoreMetadata: Decodable {
    let storeVersionIdentifiers: [String]
    let modelVersionHashes: [FrozenV2ModelVersionHash]
}

private struct FrozenV2ModelVersionHash: Decodable, Equatable {
    let entityName: String
    let versionHashHex: String
}

private struct FrozenV2StoreFamilyMember: Decodable {
    let fileName: String
    let byteCount: UInt64
    let sha256Hex: String
}

private struct FrozenV2SyntheticDataDeclaration: Decodable {
    let isSynthetic: Bool
    let containsPrivateUserData: Bool
}
