import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical repeated populated migration verification")
struct CanonicalRepeatedMigrationTests {
    @Test("successful and warning migrations repeat without duplicate records")
    func successfulAndWarningMigrationsRepeatWithoutDuplicateRecords() throws {
        let successEnvironment = try IsolatedPersistenceEnvironment()
        let warningEnvironment = try IsolatedPersistenceEnvironment()
        let successSource = IsolatedPopulatedMigrationSupport.source(.minimal)
        let warningSource = IsolatedPopulatedMigrationSupport.source(.warnings)

        let firstSuccess = try IsolatedPopulatedMigrationSupport.migrate(source: successSource, existingContainer: successEnvironment.container)
        let secondSuccess = try IsolatedPopulatedMigrationSupport.migrate(source: successSource, existingContainer: successEnvironment.container)
        let firstWarning = try IsolatedPopulatedMigrationSupport.migrate(source: warningSource, existingContainer: warningEnvironment.container)
        let secondWarning = try IsolatedPopulatedMigrationSupport.migrate(source: warningSource, existingContainer: warningEnvironment.container)
        let successSnapshot = try IsolatedPopulatedMigrationSupport.semanticSnapshot(from: successEnvironment.container)
        let warningSnapshot = try IsolatedPopulatedMigrationSupport.semanticSnapshot(from: warningEnvironment.container)

        #expect(firstSuccess.migration.disposition == .success)
        #expect(secondSuccess.migration.disposition == .alreadyMigrated)
        #expect(firstWarning.migration.disposition == .successWithWarnings)
        #expect(secondWarning.migration.disposition == .alreadyMigrated)
        #expect(successSnapshot.gameIDs.count == 1)
        #expect(successSnapshot.playerIDs.count == 4)
        #expect(successSnapshot.eventIDsBySequence.count == 1)
        #expect(warningSnapshot.gameIDs.count == 1)
        #expect(warningSnapshot.teamIDs.filter { $0 == PopulatedMigrationVerificationIDs.visitingTeam }.count == 1)
        #expect(warningSnapshot.eventIDsBySequence.count == 3)
        #expect(secondSuccess.migration.purchaseAndAllowanceUnchanged)
        #expect(secondWarning.migration.purchaseAndAllowanceUnchanged)
    }

    @Test("interrupted failed already migrated empty unsupported and conflicting repeats are classified")
    func interruptedFailedAlreadyMigratedEmptyUnsupportedAndConflictingRepeatsAreClassified() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let source = IsolatedPopulatedMigrationSupport.source(.completed)

        let interrupted = try IsolatedPopulatedMigrationSupport.migrate(source: source, existingContainer: environment.container, interruption: .preserveUnsupportedEvidence)
        let retryInterrupted = try IsolatedPopulatedMigrationSupport.migrate(source: source, existingContainer: environment.container)
        let failed = try IsolatedPopulatedMigrationSupport.migrate(source: source, injectedFailure: .recordWriteFailure)
        let retryFailed = try IsolatedPopulatedMigrationSupport.migrate(source: source)
        let empty = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.empty))
        let unsupported = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.malformed))
        let conflicting = try IsolatedPopulatedMigrationSupport.migrate(
            source: source,
            operationIdentity: PopulatedMigrationVerificationIDs.conflictingOperation,
            existingContainer: environment.container
        )

        #expect(interrupted.migration.disposition == .interrupted)
        #expect(retryInterrupted.migration.disposition == .alreadyMigrated)
        #expect(failed.migration.disposition == .partialOrUncertain)
        #expect(retryFailed.migration.disposition == .successWithWarnings)
        #expect(empty.migration.disposition == .success)
        #expect(empty.migration.targetRecordCounts == .empty)
        #expect(unsupported.migration.disposition == .unsupportedSource)
        #expect(conflicting.migration.disposition == .requiresReview)
        #expect(conflicting.migration.completionProven == false)
        #expect(conflicting.migration.reviewOrRepairRequired)
        #expect([interrupted, retryInterrupted, failed, retryFailed, empty, unsupported, conflicting].allSatisfy { $0.migration.purchaseAndAllowanceUnchanged })
    }
}
