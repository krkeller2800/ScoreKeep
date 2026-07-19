import Foundation
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@Suite("Migration production boundary")
struct ScoreKeepMigrationProductionBoundaryTests {
    @Test("active app startup delegates to host with bounded production activation")
    func activeAppStartupDelegatesToHostWithBoundedProductionActivation() throws {
        let appSource = try source("ScoreKeep/ScoreKeepApp.swift")
        let startupSource = try source("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift")

        #expect(appSource.contains("ScoreKeepProductionStartupHost"))
        #expect(appSource.contains("ScoreKeepProposedContainerFactory") == false)
        #expect(appSource.contains("ScoreKeepSourcePreservationExecutor") == false)
        #expect(appSource.contains("ScoreKeepMigrationOrchestrator") == false)
        #expect(startupSource.contains("simpleTeamCreationProductionEnabled = true"))
        #expect(startupSource.contains("runProductionMigration"))
    }

    @Test("proposed V4 schema is current while scoring stays Legacy")
    func proposedV4SchemaIsCurrentWhileScoringStaysLegacy() throws {
        let schemaSource = try source("ScoreKeep/Common/ScoreKeepProposedVersionedSchema.swift")

        #expect(schemaSource.contains("enum V3"))
        #expect(schemaSource.contains("enum V4"))
        #expect(schemaSource.contains("TeamCreationOperationEvidenceRecord.self"))
        #expect(schemaSource.contains("CanonicalGameHistoryRecord.self"))
        #expect(schemaSource.contains("LegacyScoringOperationEvidenceRecord.self"))
        #expect(ScoreKeepProposedVersionedSchema.v2AddedModelNames == ["TeamCreationOperationEvidenceRecord"])
        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(ScoreKeepProposedVersionedSchema.productionBoundaryStatement.contains("Proposed V4 is the production startup schema target"))
        #expect(ScoreKeepProposedVersionedSchema.productionBoundaryStatement.contains("Proposed V3 remains the frozen compatibility source"))
    }

    @Test("TeamView and production writers remain unrouted")
    func teamViewAndProductionWritersRemainUnrouted() throws {
        let teamView = try source("ScoreKeep/Content Views/TeamContentView.swift")
        let playerView = try source("ScoreKeep/Content Views/PlayerContentView.swift")
        let scoreView = try source("ScoreKeep/Content Views/ScoreContentView.swift")

        for source in [teamView, playerView, scoreView] {
            #expect(source.contains("ScoreKeepMigrationOrchestrator") == false)
            #expect(source.contains("ScoreKeepMigrationJournalStore") == false)
            #expect(source.contains("ScoreKeepSourcePreservationExecutor") == false)
            #expect(source.contains("ScoreKeepProposedContainerFactory") == false)
        }
    }

    @Test("new migration foundation does not reference StoreKit Keychain allowances UI or production app support")
    func newMigrationFoundationDoesNotReferenceProtectedProductionAuthorities() throws {
        let files = [
            "ScoreKeep/ScoreKeep/Common/ScoreKeepMigrationJournal.swift",
            "ScoreKeep/ScoreKeep/Common/ScoreKeepStoreFamily.swift",
            "ScoreKeep/ScoreKeep/Common/ScoreKeepSourcePreservation.swift",
            "ScoreKeep/ScoreKeep/Common/ScoreKeepMigrationOrchestrator.swift"
        ]

        for path in files {
            let text = try source(path)
            #expect(text.contains("StoreKit") == false)
            #expect(text.contains("Keychain") == false)
            #expect(text.contains("PurchaseManager") == false)
            #expect(text.contains("Allowance") == false)
            #expect(text.contains("AppStorage") == false)
            #expect(text.contains("SwiftUI") == false)
            #expect(text.contains("applicationSupportDirectory") == false)
            #expect(text.contains("documentDirectory") == false)
        }
    }

    private func source(_ projectRelativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(projectRelativePath)
    }
}
#endif
