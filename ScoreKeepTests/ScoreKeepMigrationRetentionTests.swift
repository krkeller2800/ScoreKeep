import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Migration retention and cleanup")
struct ScoreKeepMigrationRetentionTests {
    @Test("retention categories protect active completed uncertain recovery and verified backup evidence")
    func retentionCategoriesProtectRequiredEvidence() {
        #expect(ScoreKeepMigrationRetentionPolicy.category(for: .journal, journalPhase: .preflightStarted, verificationStatus: .pending) == .activeMigrationJournal)
        #expect(ScoreKeepMigrationRetentionPolicy.category(for: .journal, journalPhase: .completionRecorded, verificationStatus: .verified) == .completedMigrationJournal)
        #expect(ScoreKeepMigrationRetentionPolicy.category(for: .journal, journalPhase: .completionUncertain, verificationStatus: .uncertain) == .uncertainMigrationJournal)
        #expect(ScoreKeepMigrationRetentionPolicy.category(for: .journal, journalPhase: .recoveryRequired, verificationStatus: .failed) == .recoveryRequiredJournal)
        #expect(ScoreKeepMigrationRetentionPolicy.category(for: .verifiedBackup, journalPhase: .completionRecorded, verificationStatus: .verified) == .verifiedSourceBackup)
    }

    @Test("cleanup assessment prohibits source target backup unknown wrong identity and recovery evidence")
    func cleanupAssessmentProhibitsRequiredEvidence() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        try environment.createControlDirectories()
        let url = environment.layout.temporaryTargetsRoot.appendingPathComponent("operation", isDirectory: true)
        let activeSource = assessment(environment: environment, url: url, role: .activeSource)
        #expect(activeSource.disposition == .activeSource)
        #expect(assessment(environment: environment, url: url, role: .activeTarget).disposition == .activeTarget)
        #expect(assessment(environment: environment, url: url, role: .verifiedBackup).disposition == .verifiedBackupStillRequired)
        #expect(assessment(environment: environment, url: url, role: .unknown).disposition == .unknownArtifactProhibited)
        #expect(assessment(environment: environment, url: url, role: .recoveryCopy).disposition == .manualReviewRequired)
        let wrongIdentity = ScoreKeepMigrationOperationIdentity(sourceStoreIdentity: "other", sourceSchema: .populatedCurrentUnversionedStore, targetSchema: .proposedV2, applicationMigrationGeneration: 1, operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000009102")!)
        #expect(assessment(environment: environment, url: url, role: .temporaryTarget, artifactIdentity: wrongIdentity).disposition == .wrongOperationIdentityProhibited)
    }

    @Test("authorized test owned incomplete target can be removed but uncertain run removes nothing important")
    func authorizedTestOwnedCleanupIsNarrow() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        try environment.createControlDirectories()
        let targetDirectory = environment.layout.incompleteTargetsRoot.appendingPathComponent("operation", isDirectory: true)
        try environment.createSmallFile(targetDirectory.appendingPathComponent("ScoreKeep.store"))
        let removable = assessment(environment: environment, url: targetDirectory, role: .incompleteTarget)
        #expect(removable.disposition == .incompleteTestOwnedArtifactRemovable)
        let removed = ScoreKeepMigrationCleanupExecutor.removeAssessedArtifact(url: targetDirectory, assessment: removable)
        #expect(removed.disposition == .removed)
        #expect(FileManager.default.fileExists(atPath: targetDirectory.path) == false)

        let uncertainDirectory = environment.layout.temporaryTargetsRoot.appendingPathComponent("uncertain", isDirectory: true)
        try environment.createSmallFile(uncertainDirectory.appendingPathComponent("ScoreKeep.store"))
        let uncertain = assessment(environment: environment, url: uncertainDirectory, role: .temporaryTarget, phase: .completionUncertain)
        #expect(uncertain.disposition == .manualReviewRequired)
        #expect(ScoreKeepMigrationCleanupExecutor.removeAssessedArtifact(url: uncertainDirectory, assessment: uncertain).disposition == .prohibited)
        #expect(FileManager.default.fileExists(atPath: uncertainDirectory.path))
    }

    private func assessment(
        environment: IsolatedProductionTransitionEnvironment,
        url: URL,
        role: ScoreKeepMigrationArtifactRole,
        phase: ScoreKeepMigrationJournalPhase = .failedSafely,
        artifactIdentity: ScoreKeepMigrationOperationIdentity? = nil
    ) -> ScoreKeepMigrationCleanupAssessment {
        ScoreKeepMigrationCleanupAssessor.assess(ScoreKeepMigrationCleanupAssessmentInput(
            artifactURL: url,
            artifactRole: role,
            retentionCategory: .incompleteTarget,
            journalPhase: phase,
            disableState: .proposedTransitionExplicitlyAuthorized,
            startupOwnership: .released,
            verificationStatus: .failed,
            retentionGeneration: 1,
            authorization: .testOwnedExplicit,
            activeOperationIdentity: environment.operationIdentity,
            artifactOperationIdentity: artifactIdentity ?? environment.operationIdentity,
            authorizedMigrationRoot: environment.layout.migrationControlRoot,
            testOwnedRoot: environment.root
        ))
    }
}
