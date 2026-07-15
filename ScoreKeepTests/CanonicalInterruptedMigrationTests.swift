import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical interrupted populated migration verification")
struct CanonicalInterruptedMigrationTests {
    @Test("deterministic interruption points preserve source and do not prove completion")
    func deterministicInterruptionPointsPreserveSourceAndDoNotProveCompletion() throws {
        let source = IsolatedPopulatedMigrationSupport.source(.completed)
        let phases: [CanonicalPopulatedMigrationPhase] = [
            .createIsolatedTarget,
            .writeSupportedTargetRecords,
            .preserveUnsupportedEvidence,
            .saveTarget,
            .reloadTarget,
            .interpretTargetCanonically,
            .markCompletion
        ]

        for phase in phases {
            let result = try IsolatedPopulatedMigrationSupport.migrate(source: source, interruption: phase)

            #expect(result.migration.disposition == .interrupted)
            #expect(result.migration.completionProven == false)
            #expect(result.migration.sourceRemainsUsable)
            #expect(result.migration.reloadRequired)
            #expect(result.migration.reviewOrRepairRequired)
            #expect(result.migration.purchaseAndAllowanceUnchanged)
            #expect(result.summary.progress.interruptionMarker?.contains(phase.rawValue) == true)
            #expect(result.summary.progress.completionMarker == false)
        }
    }

    @Test("interruption after partial writes leaves target classified and retryable without source duplicates")
    func interruptionAfterPartialWritesLeavesTargetClassifiedAndRetryableWithoutSourceDuplicates() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let source = IsolatedPopulatedMigrationSupport.source(.completed)

        let interrupted = try IsolatedPopulatedMigrationSupport.migrate(
            source: source,
            existingContainer: environment.container,
            interruption: .preserveUnsupportedEvidence
        )
        let retry = try IsolatedPopulatedMigrationSupport.migrate(
            source: source,
            existingContainer: environment.container
        )
        let snapshot = try IsolatedPopulatedMigrationSupport.semanticSnapshot(from: environment.container)

        #expect(interrupted.migration.disposition == .interrupted)
        #expect(interrupted.migration.completionProven == false)
        #expect(interrupted.migration.targetIsUsable == false)
        #expect(retry.migration.disposition == .alreadyMigrated)
        #expect(retry.migration.retryIsSafe)
        #expect(snapshot.gameIDs == [PopulatedMigrationVerificationIDs.gameOne])
        #expect(snapshot.teamIDs.filter { $0 == PopulatedMigrationVerificationIDs.visitingTeam }.count == 1)
        #expect(retry.migration.purchaseAndAllowanceUnchanged)
    }
}
