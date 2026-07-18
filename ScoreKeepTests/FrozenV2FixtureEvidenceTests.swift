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
