import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Unversioned production store schema recognition")
struct UnversionedStoreSchemaRecognitionTests {
    @Test("exact unversioned producer creates on disk source stores and baselines")
    func exactUnversionedProducerCreatesOnDiskSourceStoresAndBaselines() throws {
        for scenario in UnversionedStoreScenario.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let family = try IsolatedUnversionedProductionStoreSupport.storeFamilyURLs(for: source.url)
            let reopened = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
            let reloadedSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: reopened, fixtureIdentity: scenario.rawValue)

            #expect(family.isEmpty == false)
            #expect(reloadedSnapshot == source.snapshot)
            #expect(source.snapshot.allowanceProbe == IsolatedUnversionedProductionStoreSupport.allowanceProbe)
        }
    }

    @Test("proposed V1 recognizes exact current unversioned source stores")
    func proposedV1RecognizesExactCurrentUnversionedSourceStores() throws {
        for scenario in UnversionedStoreScenario.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let originalFingerprint = try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url)
            let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)

            let v1 = try IsolatedUnversionedProductionStoreSupport.proposedV1Container(url: copy)
            let recognized = try IsolatedUnversionedProductionStoreSupport.snapshot(from: v1, fixtureIdentity: scenario.rawValue)
            let sourceAfter = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
            let sourceAfterSnapshot = try IsolatedUnversionedProductionStoreSupport.snapshot(from: sourceAfter, fixtureIdentity: scenario.rawValue)

            #expect(recognized == source.snapshot)
            #expect(sourceAfterSnapshot == source.snapshot)
            #expect(try IsolatedUnversionedProductionStoreSupport.storeFamilyFingerprint(for: source.url) == originalFingerprint)
        }
    }

    @Test("proposed V1 recognition is stable across repeated fresh opens")
    func proposedV1RecognitionIsStableAcrossRepeatedFreshOpens() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.representative)
        let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)

        for _ in 1...2 {
            let v1 = try IsolatedUnversionedProductionStoreSupport.proposedV1Container(url: copy)
            let recognized = try IsolatedUnversionedProductionStoreSupport.snapshot(from: v1, fixtureIdentity: UnversionedStoreScenario.representative.rawValue)
            #expect(recognized == source.snapshot)
        }
    }

    @Test("classification records direct recognition as current isolated evidence")
    func classificationRecordsDirectRecognitionAsCurrentIsolatedEvidence() {
        let assessment = UnversionedStoreCompatibilityAssessment.isolatedCurrentRun

        #expect(assessment.evidenceLevel == .provenCompatible)
        #expect(assessment.recommendedDirection == .directV1ToV2TransitionProven)
        #expect(assessment.proposedV1Recognition == .openedAndPreservedEvidence)
        #expect(assessment.productionRoutingChanged == false)
    }
}
