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

        #expect(result.disposition == .destinationVerificationPending)
        #expect(result.container == nil)
        #expect(result.journal.phase == .destinationVerificationPending)
        #expect(result.journal.backupVerificationDisposition == .backupVerified)
        #expect(result.journal.postOpenVerificationDisposition == "pendingTask3.22D")
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
        #expect(resumed.disposition == .destinationVerificationPending)
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
