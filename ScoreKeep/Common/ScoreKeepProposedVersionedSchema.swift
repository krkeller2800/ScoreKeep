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

    enum V3: VersionedSchema {
        static var versionIdentifier = Schema.Version(3, 0, 0)
        static var models: [any PersistentModel.Type] {
            [
                Game.self,
                Team.self,
                Player.self,
                Atbat.self,
                Lineup.self,
                Pitcher.self,
                TeamCreationOperationEvidenceRecord.self,
                CanonicalGameHistoryRecord.self,
                CanonicalScoringOperationEvidenceRecord.self,
                CanonicalScoringEventEnvelopeRecord.self,
                CanonicalScoringEventPayloadRecord.self,
                CanonicalScoringCorrectionRecord.self
            ]
        }
    }

    static let v1ModelNames = ["Game", "Team", "Player", "Atbat", "Lineup", "Pitcher"]
    static let v2AddedModelNames = ["TeamCreationOperationEvidenceRecord"]
    static let v3AddedModelNames = CanonicalScoringPersistenceModelBoundary.implementationModelNames

    static var productionBoundaryStatement: String {
        "Proposed V3 is the production schema target for storage only; production scoring remains Legacy and canonical scoring storage has no production writer."
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

enum ScoreKeepProposedCanonicalScoringStorageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            ScoreKeepProposedVersionedSchema.V2.self,
            ScoreKeepProposedVersionedSchema.V3.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: ScoreKeepProposedVersionedSchema.V2.self,
                toVersion: ScoreKeepProposedVersionedSchema.V3.self
            )
        ]
    }
}

struct ScoreKeepProposedSchemaAssessment: Hashable, Sendable {
    let proposedV1RepresentsCurrentKnownModelSet: Bool
    let proposedV2AddsOnlyOperationEvidence: Bool
    let proposedV3AddsOnlyCanonicalScoringStorage: Bool
    let productionContainerTargetsProposedV3: Bool
    let unversionedInstalledStoreAssessment: String

    static let current = ScoreKeepProposedSchemaAssessment(
        proposedV1RepresentsCurrentKnownModelSet: true,
        proposedV2AddsOnlyOperationEvidence: true,
        proposedV3AddsOnlyCanonicalScoringStorage: true,
        productionContainerTargetsProposedV3: true,
        unversionedInstalledStoreAssessment: "requires device-copy testing or archive-built prior-app verification; synthetic Proposed V1/V2 stores do not prove installed unversioned production stores carry compatible explicit schema metadata"
    )
}
