import Foundation
import Testing
@testable import ScoreKeep

@Suite("Proposed startup active production boundary")
struct ScoreKeepProposedStartupBoundaryTests {
    @Test("ScoreKeepApp uses startup host with bounded production route activation")
    func scoreKeepAppUsesStartupHostWithBoundedProductionActivation() throws {
        let source = try repositorySource("ScoreKeep/ScoreKeepApp.swift")
        let startup = try repositorySource("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift")

        #expect(source.contains("ScoreKeepProductionStartupHost"))
        #expect(source.contains("ScoreKeepProposedContainerFactory") == false)
        #expect(source.contains("ScoreKeepProposedVersionedSchema") == false)
        #expect(source.contains("ScoreKeepProposedTeamCreationEvidenceMigrationPlan") == false)
        #expect(source.contains("ScoreKeepMigrationOperationEvidenceAuthority") == false)
        #expect(source.contains("TeamCreationSwiftDataEvidenceStore") == false)
        #expect(startup.contains("simpleTeamCreationProductionEnabled = true"))
        #expect(startup.contains("sourcePreservationAuthorizationScope: .productionTransitionExplicitlyAuthorized"))
        #expect(startup.contains("disposableProposedNormalUIRehearsalEnabled = true"))
    }

    @Test("TeamView and content routes remain legacy writer routes")
    func teamViewAndContentRoutesRemainLegacyWriterRoutes() throws {
        let teamView = try repositorySource("ScoreKeep/List Data/TeamView.swift")
        let teamContentView = try repositorySource("ScoreKeep/Content Views/TeamContentView.swift")
        let route = CanonicalPersistenceCutoverRouteManifest.route(for: .teamCreationAndEditing)

        #expect(teamView.contains("ScoreKeepProposedContainerFactory") == false)
        #expect(teamView.contains("CanonicalTeamCreationTransactionAdapter") == false)
        #expect(teamView.contains("modelContext.insert(theTeam)"))
        #expect(teamView.contains("try? self.modelContext.save()"))
        #expect(teamContentView.contains("ScoreKeepProposedContainerFactory") == false)
        #expect(route.currentAuthority == .legacySwiftData)
        #expect(route.proposedFutureAuthority == .proposedPersistenceAuthority)
        #expect(route.canBeRoutedIndependently == true)
    }

    @Test("team adapter coordinator and evidence store remain non routed")
    func teamAdapterCoordinatorAndEvidenceStoreRemainNonRouted() throws {
        let coordinator = try repositorySource("ScoreKeep/Common/CanonicalTeamCreationCoordinator.swift")
        let transaction = try repositorySource("ScoreKeep/Common/CanonicalTeamCreationTransaction.swift")
        let evidenceStore = try repositorySource("ScoreKeep/Common/TeamCreationSwiftDataEvidenceStore.swift")

        #expect(coordinator.contains("@main") == false)
        #expect(coordinator.contains("ScoreKeepApp") == false)
        #expect(transaction.contains("@main") == false)
        #expect(transaction.contains("ScoreKeepApp") == false)
        #expect(evidenceStore.contains("@main") == false)
        #expect(evidenceStore.contains("ScoreKeepApp") == false)
        #expect(ScoreKeepSchemaRouteChoice.currentDefault == .legacyUnversionedProductionStartup)
    }

    @Test("StoreKit Keychain allowances entitlements UI and generated outputs are not referenced by factory")
    func unrelatedBoundariesAreNotReferencedByFactory() throws {
        let factory = try repositorySource("ScoreKeep/Common/ScoreKeepProposedContainerFactory.swift")
        let evidence = try repositorySource("ScoreKeep/Common/ScoreKeepMigrationOperationEvidence.swift")

        for forbidden in ["StoreKit", "Keychain", "PurchaseManager", "Allowance", "Entitlement", "SwiftUI", "PDF", "ImportService", "Export"] {
            #expect(factory.contains(forbidden) == false)
            #expect(evidence.contains(forbidden) == false)
        }
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }
}

enum ScoreKeepProposedStartupBoundaryTestError: Error {
    case repositoryRootNotFound
}
