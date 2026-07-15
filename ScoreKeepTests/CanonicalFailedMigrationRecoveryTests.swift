import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical failed populated migration recovery verification")
struct CanonicalFailedMigrationRecoveryTests {
    @Test("representative injected failures classify source target retry rollback and uncertainty")
    func representativeInjectedFailuresClassifySourceTargetRetryRollbackAndUncertainty() throws {
        let source = IsolatedPopulatedMigrationSupport.source(.completed)
        let failures: [IsolatedPopulatedMigrationFailure] = [
            .sourceReadFailure,
            .sourceValidationFailure,
            .targetCreationFailure,
            .recordWriteFailure,
            .relationshipWriteFailure,
            .orderingWriteFailure,
            .mediaWriteFailure,
            .saveFailure,
            .reloadFailure,
            .verificationFailure,
            .completionMarkerFailure
        ]

        for failure in failures {
            let result = try IsolatedPopulatedMigrationSupport.migrate(source: source, injectedFailure: failure)

            #expect(result.migration.completionProven == false)
            #expect(result.migration.sourceRemainsUsable)
            #expect(result.migration.reviewOrRepairRequired || result.migration.reloadRequired)
            #expect(result.summary.progress.failureMarker?.contains(failure.rawValue) == true)
            #expect(result.summary.progress.completionMarker == false)
            #expect(result.recoveryStrategy.isEmpty == false)
            #expect(result.migration.purchaseAndAllowanceUnchanged)
        }
    }

    @Test("recovery preserves prior accepted state and can restart from source snapshot")
    func recoveryPreservesPriorAcceptedStateAndCanRestartFromSourceSnapshot() throws {
        let acceptedEnvironment = try IsolatedPersistenceEnvironment()
        let source = IsolatedPopulatedMigrationSupport.source(.completed)

        let accepted = try IsolatedPopulatedMigrationSupport.migrate(source: source, existingContainer: acceptedEnvironment.container)
        let failedRecovery = try IsolatedPopulatedMigrationSupport.migrate(source: source, injectedFailure: .completionMarkerFailure)
        let restarted = try IsolatedPopulatedMigrationSupport.migrate(source: source)
        let acceptedSnapshot = try IsolatedPopulatedMigrationSupport.semanticSnapshot(from: acceptedEnvironment.container)
        let restartedSnapshot = try #require(restarted.semanticSnapshot)

        #expect(accepted.migration.completionProven)
        #expect(failedRecovery.migration.disposition == .recoveryAvailable)
        #expect(failedRecovery.migration.completionProven == false)
        #expect(restarted.migration.disposition == .successWithWarnings)
        #expect(restarted.migration.completionProven)
        #expect(acceptedSnapshot.gameIDs == restartedSnapshot.gameIDs)
        #expect(acceptedSnapshot.eventIDsBySequence == restartedSnapshot.eventIDsBySequence)
        #expect(failedRecovery.migration.sourceRemainsUsable)
        #expect(failedRecovery.migration.retryIsSafe)
        #expect(failedRecovery.migration.purchaseAndAllowanceUnchanged)
    }
}
