import Foundation
import Testing
@testable import ScoreKeep

@Suite("Active transition preparation boundary")
struct ScoreKeepActiveTransitionPreparationBoundaryTests {
    @Test("ScoreKeepApp active startup route remains legacy and unconnected to preparation authorities")
    func scoreKeepAppStartupRemainsLegacy() throws {
        let appSource = try source("ScoreKeep/ScoreKeepApp.swift")
        #expect(appSource.contains(".modelContainer(for: Game.self)"))
        #expect(appSource.contains("ScoreKeepProductionMigrationLayout") == false)
        #expect(appSource.contains("ScoreKeepMigrationCapacityCalculator") == false)
        #expect(appSource.contains("ScoreKeepMigrationFileProtectionApplicator") == false)
        #expect(appSource.contains("ScoreKeepMigrationCleanupExecutor") == false)
        #expect(appSource.contains("ScoreKeepStartupOutcomePolicy") == false)
        #expect(appSource.contains("ScoreKeepContainerStartupSelector") == false)
        #expect(appSource.contains("ScoreKeepProductionTransitionAuthorization") == false)
        #expect(appSource.contains("ScoreKeepMigrationOrchestrator") == false)
        #expect(appSource.contains("ScoreKeepProposedContainerFactory") == false)
        #expect(appSource.contains("ScoreKeepProposedVersionedSchema") == false)
    }

    @Test("TeamView and production writer routes remain unchanged and unrouted")
    func teamViewAndProductionWritersRemainUnrouted() throws {
        let paths = [
            "ScoreKeep/Content Views/TeamContentView.swift",
            "ScoreKeep/Content Views/ScoreContentView.swift",
            "ScoreKeep/Content Views/PlayerContentView.swift",
            "ScoreKeep/Disply graphics/PlayersToScoreView.swift",
            "ScoreKeep/Disply graphics/ScoreGameView.swift"
        ]
        for path in paths {
            let text = try source(path)
            #expect(text.contains("ScoreKeepContainerStartupSelector") == false)
            #expect(text.contains("ScoreKeepProductionTransitionAuthorization") == false)
            #expect(text.contains("ScoreKeepMigrationOrchestrator") == false)
            #expect(text.contains("ScoreKeepProposedContainerFactory") == false)
        }
        #expect(CanonicalTeamCreationCutoverReview.current.adapterRouted == false)
    }

    @Test("preparation defaults retain legacy authority and absent production authorization")
    func preparationDefaultsRetainLegacyAuthority() {
        #expect(ScoreKeepContainerStartupSelection.currentDefault == .legacyActive)
        #expect(ScoreKeepSchemaRouteDisableState.currentDefault == .legacyRouteRequired)
        #expect(ScoreKeepSchemaRouteChoice.currentDefault == .legacyUnversionedProductionStartup)
        #expect(ScoreKeepProductionTransitionAuthorization.absent.isSatisfied == false)
    }

    @Test("new preparation authorities do not use StoreKit Keychain documents UI or production startup")
    func preparationAuthoritiesAvoidUnrelatedProductionSurfaces() throws {
        let paths = [
            "ScoreKeep/Common/ScoreKeepProductionMigrationPaths.swift",
            "ScoreKeep/Common/ScoreKeepMigrationCapacity.swift",
            "ScoreKeep/Common/ScoreKeepMigrationFileProtection.swift",
            "ScoreKeep/Common/ScoreKeepMigrationRetention.swift",
            "ScoreKeep/Common/ScoreKeepStartupOutcomePolicy.swift",
            "ScoreKeep/Common/ScoreKeepContainerActivationControl.swift"
        ]
        for path in paths {
            let text = try source(path)
            #expect(text.contains("StoreKit") == false)
            #expect(text.contains("Keychain") == false)
            #expect(text.contains("PurchaseManager") == false)
            #expect(text.contains("AppStorage") == false)
            #expect(text.contains("SwiftUI") == false)
            #expect(text.contains("documentDirectory") == false)
            #expect(text.contains("TeamView") == false)
            #expect(text.contains("ModelContainer(for: Game.self") == false)
        }
    }

    private func source(_ projectRelativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(projectRelativePath)
    }
}
