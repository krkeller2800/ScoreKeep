import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation proposed versioned schema")
struct TeamCreationVersionedSchemaTests {
    @Test("proposed schemas describe current model set and add only operation evidence")
    func proposedSchemasDescribeCurrentModelSetAndAddOnlyOperationEvidence() {
        #expect(ScoreKeepProposedVersionedSchema.V1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.V2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.v1ModelNames == ["Game", "Team", "Player", "Atbat", "Lineup", "Pitcher"])
        #expect(ScoreKeepProposedVersionedSchema.v2AddedModelNames == ["TeamCreationOperationEvidenceRecord"])
        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV1RepresentsCurrentKnownModelSet)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV2AddsOnlyOperationEvidence)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV3AddsOnlyCanonicalScoringStorage)
        #expect(ScoreKeepProposedSchemaAssessment.current.productionContainerTargetsProposedV4)
    }

    @Test("operation evidence model stores only scalar operation metadata")
    func operationEvidenceModelStoresOnlyScalarOperationMetadata() {
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("operationIdentity"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("targetTeamIdentity"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("requestFingerprint"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("phase"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("completionProof"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("retryClassification"))
        #expect(TeamCreationOperationEvidenceModelBoundary.hasTeamRelationship == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.hasPurchaseOrAllowanceFields == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.hasMediaFields == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("teamName"))
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("receipts"))
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("logo"))
    }

    @Test("production startup is hosted and bounded activation is enabled")
    func productionStartupIsHostedAndBoundedActivationIsEnabled() throws {
        let source = try repositorySource("ScoreKeep/ScoreKeepApp.swift")
        let startup = try repositorySource("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift")

        #expect(source.contains("ScoreKeepProductionStartupHost"))
        #expect(source.contains("ScoreKeepProposedVersionedSchema") == false)
        #expect(source.contains("ScoreKeepProposedTeamCreationEvidenceMigrationPlan") == false)
        #expect(source.contains("TeamCreationOperationEvidenceRecord") == false)
        #expect(source.contains("TeamCreationSwiftDataEvidenceStore") == false)
        #expect(startup.contains("simpleTeamCreationProductionEnabled = true"))
        #expect(startup.contains("runProductionMigration"))
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }
}

enum TeamCreationVersionedSchemaTestError: Error {
    case repositoryRootNotFound
}
