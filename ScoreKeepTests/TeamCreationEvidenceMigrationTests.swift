import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation operation evidence isolated migration")
struct TeamCreationEvidenceMigrationTests {
    @Test("empty proposed V1 store opens as proposed V2 with no evidence records")
    func emptyProposedV1StoreOpensAsProposedV2WithNoEvidenceRecords() throws {
        let url = try IsolatedVersionedTeamCreationEvidenceSupport.temporaryStoreURL()
        do {
            _ = try IsolatedVersionedTeamCreationEvidenceSupport.v1DiskContainer(url: url)
        }

        let migrated = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)

        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: migrated) == 0)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: migrated) == 0)
    }

    @Test("populated proposed V1 store migrates to V2 preserving baseball graph and empty evidence")
    func populatedProposedV1StoreMigratesToV2PreservingBaseballGraphAndEmptyEvidence() throws {
        let url = try IsolatedVersionedTeamCreationEvidenceSupport.temporaryStoreURL()
        do {
            let v1 = try IsolatedVersionedTeamCreationEvidenceSupport.v1DiskContainer(url: url)
            let context = ModelContext(v1)
            IsolatedVersionedTeamCreationEvidenceSupport.insertRepresentativeGraph(into: context)
            try context.save()
            #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: v1) == 1)
        }

        let v2 = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
        let snapshot = try IsolatedTeamCreationTransactionSupport.snapshot(from: v2)

        #expect(snapshot.teams[TeamCreationTransactionVerificationIDs.unrelatedTeam]?.name == "Unrelated Team")
        #expect(snapshot.playerIDs == [TeamCreationTransactionVerificationIDs.unrelatedPlayer])
        #expect(snapshot.gameIDs == [TeamCreationTransactionVerificationIDs.unrelatedGame])
        #expect(snapshot.atbatIDs == [TeamCreationTransactionVerificationIDs.unrelatedAtbat])
        #expect(snapshot.lineupIDs == [TeamCreationTransactionVerificationIDs.unrelatedLineup])
        #expect(snapshot.pitcherIDs == [TeamCreationTransactionVerificationIDs.unrelatedPitcher])
        #expect(snapshot.teamPlayerIDs[TeamCreationTransactionVerificationIDs.unrelatedTeam] == [TeamCreationTransactionVerificationIDs.unrelatedPlayer])
        #expect(snapshot.teamGameIDs[TeamCreationTransactionVerificationIDs.unrelatedTeam] == [TeamCreationTransactionVerificationIDs.unrelatedGame])
        #expect(snapshot.teams[TeamCreationTransactionVerificationIDs.unrelatedTeam]?.logoByteCount == IsolatedMediaPersistenceSupport.smallValidPNG.count)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: v2) == 0)

        let reloaded = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: reloaded) == 1)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: reloaded) == 0)
    }

    @Test("current unversioned production store assessment remains explicit blocker")
    func currentUnversionedProductionStoreAssessmentRemainsExplicitBlocker() {
        #expect(ScoreKeepProposedSchemaAssessment.current.unversionedInstalledStoreAssessment.contains("requires device-copy testing"))
        #expect(ScoreKeepProposedSchemaAssessment.current.unversionedInstalledStoreAssessment.contains("synthetic Proposed V1/V2 stores do not prove"))
    }
}
