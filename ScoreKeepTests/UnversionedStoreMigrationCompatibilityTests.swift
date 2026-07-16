import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Unversioned store direct migration compatibility")
struct UnversionedStoreMigrationCompatibilityTests {
    @Test("direct proposed V2 migration opens unversioned copies preserving evidence")
    func directProposedV2MigrationOpensUnversionedCopiesPreservingEvidence() throws {
        for scenario in UnversionedStoreScenario.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let originalFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url)
            let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)

            let v2 = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: copy)
            let migrated = try IsolatedUnversionedProductionStoreSupport.snapshot(from: v2, fixtureIdentity: scenario.rawValue)
            let evidenceCount = try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: v2)
            let sourceAfter = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
            let sourceAfterSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: sourceAfter, fixtureIdentity: scenario.rawValue)

            #expect(migrated == source.snapshot)
            #expect(evidenceCount == 0)
            #expect(sourceAfterSnapshot == source.snapshot)
            #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == originalFingerprint)
        }
    }

    @Test("minimal direct proposed V2 transition is repeatable on fresh copies")
    func minimalDirectProposedV2TransitionIsRepeatableOnFreshCopies() throws {
        var seenURLs: Set<URL> = []
        for attempt in 1...2 {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal, name: "minimal-direct-\(attempt)-\(UUID().uuidString)")
            let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url, name: "minimal-direct-copy-\(attempt)-\(UUID().uuidString)")
            #expect(source.url != copy)
            #expect(seenURLs.insert(source.url).inserted)
            #expect(seenURLs.insert(copy).inserted)

            let v2 = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: copy)
            let migrated = try IsolatedUnversionedProductionStoreSupport.snapshot(from: v2, fixtureIdentity: UnversionedStoreScenario.minimal.rawValue)

            #expect(migrated == source.snapshot)
            #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: v2) == 0)
        }
    }

    @Test("automatic current model plus evidence opens copied unversioned source")
    func automaticCurrentModelPlusEvidenceOpensCopiedUnversionedSource() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.representative)
        let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)

        let evolved = try IsolatedUnversionedProductionStoreSupport.automaticCurrentModelsPlusEvidenceContainer(url: copy)
        let snapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: evolved, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)
        let evidenceCount = try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: evolved)

        #expect(snapshot == source.snapshot)
        #expect(evidenceCount == 0)
    }

    @Test("automatic evolution result is later recognizable through proposed V2")
    func automaticEvolutionResultIsLaterRecognizableThroughProposedV2() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.representative)
        let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)
        let evolved = try IsolatedUnversionedProductionStoreSupport.automaticCurrentModelsPlusEvidenceContainer(url: copy)
        let evolvedSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: evolved, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)
        #expect(evolvedSnapshot == source.snapshot)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: evolved) == 0)

        let proposedV2 = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: copy)
        let recognized = try IsolatedUnversionedProductionStoreSupport.snapshot(from: proposedV2, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)
        #expect(recognized == source.snapshot)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: proposedV2) == 0)
    }

    @Test("direct migration classification records empty evidence storage")
    func directMigrationClassificationRecordsEmptyEvidenceStorage() {
        let assessment = UnversionedStoreCompatibilityAssessment.isolatedCurrentRun

        #expect(assessment.directProposedV2Migration == .openedWithEmptyEvidenceStorage)
        #expect(assessment.automaticModelAddition == .openedWithEmptyEvidenceStorage)
        #expect(assessment.conversionFallback == .notAttempted)
    }
}
