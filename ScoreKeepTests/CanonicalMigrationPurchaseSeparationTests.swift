import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical migration purchase separation verification")
struct CanonicalMigrationPurchaseSeparationTests {
    @Test("success warning interruption repetition failure and recovery preserve purchase allowance probes")
    func successWarningInterruptionRepetitionFailureAndRecoveryPreservePurchaseAllowanceProbes() throws {
        let probe = IsolatedPopulatedMigrationSupport.nonDefaultProbe
        let environment = try IsolatedPersistenceEnvironment()
        let source = IsolatedPopulatedMigrationSupport.source(.completed)

        let success = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.minimal), probe: probe)
        let warning = try IsolatedPopulatedMigrationSupport.migrate(source: source, probe: probe)
        let interrupted = try IsolatedPopulatedMigrationSupport.migrate(source: source, interruption: .saveTarget, probe: probe)
        let firstRepeat = try IsolatedPopulatedMigrationSupport.migrate(source: source, existingContainer: environment.container, probe: probe)
        let secondRepeat = try IsolatedPopulatedMigrationSupport.migrate(source: source, existingContainer: environment.container, probe: probe)
        let failed = try IsolatedPopulatedMigrationSupport.migrate(source: source, injectedFailure: .saveFailure, probe: probe)
        let recovery = try IsolatedPopulatedMigrationSupport.migrate(source: source, injectedFailure: .completionMarkerFailure, probe: probe)
        let empty = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.empty), probe: probe)

        let results = [success, warning, interrupted, firstRepeat, secondRepeat, failed, recovery, empty]
        #expect(results.allSatisfy { $0.migration.purchaseAllowanceProbeBefore == probe })
        #expect(results.allSatisfy { $0.migration.purchaseAllowanceProbeAfter == probe })
        #expect(results.allSatisfy { $0.migration.purchaseAndAllowanceUnchanged })
        #expect(results.allSatisfy { $0.receiptOrSignedTransactionDataPresent == false })
        #expect(secondRepeat.migration.disposition == .alreadyMigrated)
        #expect(empty.migration.targetRecordCounts == .empty)
    }

    @Test("purchase separation failure blocks migration success and does not repair entitlement state")
    func purchaseSeparationFailureBlocksMigrationSuccessAndDoesNotRepairEntitlementState() throws {
        let probe = IsolatedPopulatedMigrationSupport.nonDefaultProbe
        let changedProbe = CanonicalMigrationPurchaseAllowanceProbe(
            freeGameCreatesRemaining: 0,
            mlbDownloadUseCount: 4,
            entitlementMarker: "changed-entitlement-probe",
            purchaseMarker: "changed-purchase-probe"
        )

        let result = try IsolatedPopulatedMigrationSupport.migrate(
            source: IsolatedPopulatedMigrationSupport.source(.completed),
            probe: probe,
            probeAfter: changedProbe
        )

        #expect(result.migration.disposition == .purchaseSeparationFailure)
        #expect(result.migration.purchaseAndAllowanceUnchanged == false)
        #expect(result.migration.completionProven == false)
        #expect(result.migration.reviewOrRepairRequired)
        #expect(result.migration.sourceRemainsUsable)
        #expect(result.recoveryStrategy.contains("source") || result.recoveryStrategy.contains("Source"))
        #expect(result.receiptOrSignedTransactionDataPresent == false)
    }

    @Test("migration values contain no receipt or signed transaction markers")
    func migrationValuesContainNoReceiptOrSignedTransactionMarkers() throws {
        let result = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.warnings))
        let searchableValues = [
            result.migration.purchaseAllowanceProbeBefore.entitlementMarker,
            result.migration.purchaseAllowanceProbeBefore.purchaseMarker,
            result.migration.purchaseAllowanceProbeAfter.entitlementMarker,
            result.migration.purchaseAllowanceProbeAfter.purchaseMarker,
            result.summary.sourceIdentity,
            result.summary.targetIdentity,
            result.physicalSchemaAssessment
        ]

        #expect(searchableValues.allSatisfy { $0.localizedCaseInsensitiveContains("receipt") == false })
        #expect(searchableValues.allSatisfy { $0.localizedCaseInsensitiveContains("signed transaction") == false })
        #expect(result.receiptOrSignedTransactionDataPresent == false)
    }
}
