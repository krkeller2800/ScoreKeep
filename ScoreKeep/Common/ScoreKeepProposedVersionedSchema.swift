import Foundation
import SwiftData

enum ScoreKeepProposedVersionedSchema {
    enum V1: VersionedSchema {
        static var versionIdentifier = Schema.Version(1, 0, 0)
        static var models: [any PersistentModel.Type] {
            [
                Game.self,
                Team.self,
                Player.self,
                Atbat.self,
                Lineup.self,
                Pitcher.self
            ]
        }
    }

    enum V2: VersionedSchema {
        static var versionIdentifier = Schema.Version(2, 0, 0)
        static var models: [any PersistentModel.Type] {
            [
                Game.self,
                Team.self,
                Player.self,
                Atbat.self,
                Lineup.self,
                Pitcher.self,
                TeamCreationOperationEvidenceRecord.self
            ]
        }
    }

    static let v1ModelNames = ["Game", "Team", "Player", "Atbat", "Lineup", "Pitcher"]
    static let v2AddedModelNames = ["TeamCreationOperationEvidenceRecord"]

    static var productionBoundaryStatement: String {
        "Proposed V1 and V2 are isolated verification schemas only; ScoreKeepApp.modelContainer remains the active unversioned production container."
    }
}

enum ScoreKeepProposedTeamCreationEvidenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            ScoreKeepProposedVersionedSchema.V1.self,
            ScoreKeepProposedVersionedSchema.V2.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: ScoreKeepProposedVersionedSchema.V1.self,
                toVersion: ScoreKeepProposedVersionedSchema.V2.self
            )
        ]
    }
}

struct ScoreKeepProposedSchemaAssessment: Hashable, Sendable {
    let proposedV1RepresentsCurrentKnownModelSet: Bool
    let proposedV2AddsOnlyOperationEvidence: Bool
    let productionContainerIsUnchanged: Bool
    let unversionedInstalledStoreAssessment: String

    static let current = ScoreKeepProposedSchemaAssessment(
        proposedV1RepresentsCurrentKnownModelSet: true,
        proposedV2AddsOnlyOperationEvidence: true,
        productionContainerIsUnchanged: true,
        unversionedInstalledStoreAssessment: "requires device-copy testing or archive-built prior-app verification; synthetic Proposed V1 stores do not prove installed unversioned production stores carry compatible explicit schema metadata"
    )
}
