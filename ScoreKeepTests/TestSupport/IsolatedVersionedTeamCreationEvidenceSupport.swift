import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
enum IsolatedVersionedTeamCreationEvidenceSupport {
    static func temporaryStoreURL(_ name: String = UUID().uuidString) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ScoreKeepEvidence-")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Evidence.store")
    }

    static func v2InMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func v1DiskContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V1.self)
        let configuration = ModelConfiguration("ProposedV1", schema: schema, url: url, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func v2DiskContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)
        let configuration = ModelConfiguration("ProposedV2", url: url, allowsSave: true)
        return try ModelContainer(for: schema, migrationPlan: ScoreKeepProposedTeamCreationEvidenceMigrationPlan.self, configurations: [configuration])
    }

    static func request(
        operationIdentity: String = "team-create-swiftdata-op-001",
        teamIdentity: UUID = TeamCreationTransactionVerificationIDs.createdTeam,
        teamName: String = "Isolated Falcons",
        coach: String = "Coach One",
        details: String = "Simple isolated team"
    ) -> CanonicalTeamCreationOperationalRequest {
        CanonicalTeamCreationOperationalRequest(
            operationIdentity: CanonicalTeamCreationOperationIdentity(operationIdentity),
            teamIdentity: teamIdentity,
            teamName: teamName,
            coach: coach,
            details: details
        )
    }

    static func evidence(for request: CanonicalTeamCreationOperationalRequest) -> CanonicalTeamCreationOperationEvidence {
        CanonicalTeamCreationOperationEvidence(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: request.semanticFingerprint
        )
    }

    static func insertRepresentativeGraph(into context: ModelContext) {
        IsolatedTeamCreationTransactionSupport.insertUnrelatedGraph(into: context)
    }

    static func observedTeams(from container: ModelContainer) throws -> [TeamCreationObservedTeam] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Team>()).map {
            TeamCreationObservedTeam(identity: $0.ident, name: $0.name, coach: $0.coach, details: $0.details)
        }
    }

    static func evidenceCount(in container: ModelContainer) throws -> Int {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>()).count
    }

    static func teamCount(in container: ModelContainer) throws -> Int {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Team>()).count
    }

    static func firstTeamLogo(in container: ModelContainer) throws -> Data? {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Team>()).first?.logo
    }
}
