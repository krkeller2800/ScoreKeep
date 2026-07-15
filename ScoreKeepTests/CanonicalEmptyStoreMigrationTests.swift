import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical empty-store migration verification")
struct CanonicalEmptyStoreMigrationTests {
    @Test("truly empty source initializes current empty target without baseball records")
    func trulyEmptySourceInitializesCurrentEmptyTargetWithoutBaseballRecords() throws {
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "empty-source")

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input)

        #expect(result.disposition == .emptySourceInitialized)
        #expect(result.targetRecordCounts == .empty)
        #expect(result.producedRecords == false)
        #expect(result.targetIsUsable)
        #expect(result.completionProven)
        #expect(result.purchaseAndAllowanceUnchanged)
        #expect(result.transactionResult.disposition == .success)
    }

    @Test("same initialized empty target can be migrated repeatedly without duplicates")
    func sameInitializedEmptyTargetCanBeMigratedRepeatedlyWithoutDuplicates() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let firstInput = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "empty-source",
            operationIdentity: "empty-store-repeat-001",
            sourceClassification: .trulyEmptyNewStore
        )
        let secondInput = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "empty-source",
            operationIdentity: "empty-store-repeat-001",
            sourceClassification: .previouslyInitializedEmptyStore,
            mode: .verifyEmptyStoreIdempotency
        )

        let first = try IsolatedMigrationSupport.migrateEmptyStore(input: firstInput, existingContainer: environment.container)
        let second = try IsolatedMigrationSupport.migrateEmptyStore(input: secondInput, existingContainer: environment.container)
        let reloadCounts = try IsolatedMigrationSupport.recordCounts(from: environment.container)

        #expect(first.disposition == .emptySourceInitialized)
        #expect(second.disposition == .noChange)
        #expect(first.targetRecordCounts == .empty)
        #expect(second.targetRecordCounts == .empty)
        #expect(reloadCounts == .empty)
        #expect(first.producedRecords == false)
        #expect(second.producedRecords == false)
        #expect(second.noOp)
        #expect(second.purchaseAndAllowanceUnchanged)
    }

    @Test("empty migration preserves preference purchase entitlement and allowance probes")
    func emptyMigrationPreservesPreferencePurchaseEntitlementAndAllowanceProbes() throws {
        let probe = CanonicalMigrationPurchaseAllowanceProbe(
            freeGameCreatesRemaining: 1,
            mlbDownloadUseCount: 3,
            entitlementMarker: "entitlement-known-before",
            purchaseMarker: "purchase-known-before"
        )
        let input = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "purchase-allowance-probes",
            sourceClassification: .purchaseOrAllowanceOnlyNoBaseballRecords,
            probe: probe
        )

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input)

        #expect(result.disposition == .emptySourceInitialized)
        #expect(result.purchaseAllowanceProbeBefore == probe)
        #expect(result.purchaseAllowanceProbeAfter == probe)
        #expect(result.purchaseAndAllowanceUnchanged)
        #expect(result.targetRecordCounts == .empty)
        #expect(result.producedRecords == false)
    }

    @Test("preference-only and metadata-only empty sources remain distinct")
    func preferenceOnlyAndMetadataOnlyEmptySourcesRemainDistinct() throws {
        let preferenceInput = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "preferences-only-empty",
            sourceClassification: .preferencesOnlyNoBaseballRecords
        )
        let metadataInput = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "metadata-only-empty",
            sourceClassification: .metadataOnlyNoBaseballRecords
        )

        let preferenceResult = try IsolatedMigrationSupport.migrateEmptyStore(input: preferenceInput)
        let metadataResult = try IsolatedMigrationSupport.migrateEmptyStore(input: metadataInput)

        #expect(preferenceResult.sourceClassification == .preferencesOnlyNoBaseballRecords)
        #expect(metadataResult.sourceClassification == .metadataOnlyNoBaseballRecords)
        #expect(preferenceResult.disposition == .emptySourceInitialized)
        #expect(metadataResult.disposition == .emptySourceInitialized)
        #expect(preferenceResult.targetRecordCounts == .empty)
        #expect(metadataResult.targetRecordCounts == .empty)
    }

    @Test("fresh context reload after empty migration remains loadable and seed free")
    func freshContextReloadAfterEmptyMigrationRemainsLoadableAndSeedFree() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "fresh-reload-empty")

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input, existingContainer: environment.container)
        let freshCounts = try IsolatedMigrationSupport.recordCounts(from: environment.container)

        #expect(result.targetIsUsable)
        #expect(freshCounts == .empty)
    }

    @Test("unsupported and unknown source versions reject without changing probes")
    func unsupportedAndUnknownSourceVersionsRejectWithoutChangingProbes() throws {
        let unsupported = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "unsupported-source",
            sourceClassification: .unsupportedSource
        )
        let unknown = IsolatedMigrationSupport.emptyStoreInput(
            fixtureIdentity: "unknown-version",
            sourceClassification: .unknownSourceVersion
        )

        let unsupportedResult = try IsolatedMigrationSupport.migrateEmptyStore(input: unsupported)
        let unknownResult = try IsolatedMigrationSupport.migrateEmptyStore(input: unknown)

        #expect(unsupportedResult.disposition == .unsupportedSource)
        #expect(unknownResult.disposition == .unknownSourceVersion)
        #expect(unsupportedResult.purchaseAndAllowanceUnchanged)
        #expect(unknownResult.purchaseAndAllowanceUnchanged)
        #expect(unsupportedResult.reviewOrRepairRequired)
        #expect(unknownResult.reviewOrRepairRequired)
        #expect(unsupportedResult.producedRecords == false)
        #expect(unknownResult.producedRecords == false)
    }

    @Test("unexpected target records require review and do not claim empty success")
    func unexpectedTargetRecordsRequireReviewAndDoNotClaimEmptySuccess() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(
            into: environment.context,
            includeSecondEvent: false,
            includeSubstitution: false
        )
        try environment.save()
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "unexpected-records")

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input, existingContainer: environment.container)

        #expect(result.disposition == .requiresReview)
        #expect(result.targetRecordCounts.containsBaseballRecords)
        #expect(result.producedRecords)
        #expect(result.reviewOrRepairRequired)
        #expect(result.completionProven)
        #expect(result.purchaseAndAllowanceUnchanged)
    }

    @Test("purchase separation failure blocks success classification")
    func purchaseSeparationFailureBlocksSuccessClassification() throws {
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "purchase-probe-change")
        let changedProbe = CanonicalMigrationPurchaseAllowanceProbe(
            freeGameCreatesRemaining: 0,
            mlbDownloadUseCount: 3,
            entitlementMarker: "changed-entitlement",
            purchaseMarker: "changed-purchase"
        )

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input, probeAfter: changedProbe)

        #expect(result.disposition == .purchaseSeparationFailure)
        #expect(result.purchaseAndAllowanceUnchanged == false)
        #expect(result.reviewOrRepairRequired)
        #expect(result.completionProven)
        #expect(result.producedRecords == false)
    }

    @Test("injected initialization failure preserves prior state and is retry classified")
    func injectedInitializationFailurePreservesPriorStateAndIsRetryClassified() throws {
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "injected-failure")

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input, injectedFailure: .containerCreationFailed)

        #expect(result.disposition == .recoveryAvailable)
        #expect(result.sourceRemainsUsable)
        #expect(result.retryIsSafe)
        #expect(result.reloadRequired)
        #expect(result.reviewOrRepairRequired)
        #expect(result.completionProven == false)
        #expect(result.purchaseAndAllowanceUnchanged)
    }

    @Test("interrupted empty initialization is uncertain and leaves retry evidence")
    func interruptedEmptyInitializationIsUncertainAndLeavesRetryEvidence() throws {
        let input = IsolatedMigrationSupport.emptyStoreInput(fixtureIdentity: "interrupted-empty")

        let result = try IsolatedMigrationSupport.migrateEmptyStore(input: input, interrupted: true)

        #expect(result.disposition == .interrupted)
        #expect(result.completionProven == false)
        #expect(result.sourceRemainsUsable)
        #expect(result.reloadRequired)
        #expect(result.reviewOrRepairRequired)
        #expect(result.purchaseAndAllowanceUnchanged)
        #expect(result.producedRecords == false)
    }
}
