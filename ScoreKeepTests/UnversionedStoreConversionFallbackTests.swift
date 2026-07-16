import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Unversioned store conversion fallback assessment")
struct UnversionedStoreConversionFallbackTests {
    @Test("store copy conversion reconstructs representative source into proposed V2 target")
    func storeCopyConversionReconstructsRepresentativeSourceIntoProposedV2Target() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.representative)
        let targetURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let target = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: targetURL)

        try IsolatedUnversionedProductionStoreSupport.reconstruct(source.snapshot, into: target)
        let reloaded = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: targetURL)
        let converted = try IsolatedUnversionedProductionStoreSupport.snapshot(from: reloaded, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)
        let sourceAfter = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
        let sourceAfterSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: sourceAfter, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)

        #expect(converted == source.snapshot)
        #expect(sourceAfterSnapshot == source.snapshot)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: reloaded) == 0)
    }

    @Test("conversion target repeatedly reopens without duplicate baseball or evidence records")
    func conversionTargetRepeatedlyReopensWithoutDuplicateBaseballOrEvidenceRecords() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.edgeEvidence)
        let targetURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let target = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: targetURL)
        try IsolatedUnversionedProductionStoreSupport.reconstruct(source.snapshot, into: target)

        for _ in 1...3 {
            let reloaded = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: targetURL)
            let converted = try IsolatedUnversionedProductionStoreSupport.snapshot(from: reloaded, fixtureIdentity: UnversionedStoreScenario.edgeEvidence.rawValue)

            #expect(converted == source.snapshot)
            #expect(converted.unsupportedEvidence == ["unsupported-maxbase", "unsupported-result"])
            #expect(converted.ambiguousEvidence.contains("ambiguous-substitution-arrays"))
            #expect(converted.ambiguousEvidence.contains("duplicate-event-sequence"))
            #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: reloaded) == 0)
        }
    }

    @Test("conversion write failure preserves original source and discards target")
    func conversionWriteFailurePreservesOriginalSourceAndDiscardsTarget() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let targetURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()

        do {
            let target = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: targetURL)
            try IsolatedUnversionedProductionStoreSupport.reconstruct(source.snapshot, into: target)
            throw CancellationError()
        } catch {
            let sourceAfter = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
            let sourceAfterSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: sourceAfter, fixtureIdentity: UnversionedStoreScenario.minimal.rawValue)
            #expect(sourceAfterSnapshot == source.snapshot)
        }
    }
}
