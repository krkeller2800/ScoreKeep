import Foundation
import Testing
@testable import ScoreKeep

@Suite("Startup readiness classification verification")
struct ScoreKeepStartupReadinessTests {
    @Test("source classifications cover required startup states")
    func sourceClassificationsCoverRequiredStartupStates() {
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.noStoreExists))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.emptyCurrentUnversionedStore))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.populatedCurrentUnversionedStore))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.proposedV1RecognizableStore))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.existingProposedV2Store))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.unknownVersion))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.unsupportedFutureVersion))
        #expect(ScoreKeepSourceStoreClassification.allCases.contains(.migrationEvidenceUncertain))
        #expect(ScoreKeepSourceStoreClassification.populatedCurrentUnversionedStore.requiresMigration)
        #expect(ScoreKeepSourceStoreClassification.existingProposedV2Store.requiresMigration == false)
    }

    @Test("migration snapshot is shallow immutable startup authority")
    func migrationSnapshotIsShallow() {
        let identity = startupMigrationIdentity()
        let snapshot = ScoreKeepStartupMigrationSnapshot(
            phase: .postOpenVerificationRequired,
            sourceClassification: .populatedCurrentUnversionedStore,
            routeChoice: .proposedV2EligibleForIsolatedVerification,
            operationIdentity: identity,
            diagnosticsRequired: true
        )

        #expect(snapshot.phase == .postOpenVerificationRequired)
        #expect(snapshot.operationIdentity?.diagnosticToken == "migration-1-00000000")
        #expect(ScoreKeepStartupMigrationPhase.allCases.contains(.writesProhibited))
    }

    @Test("all mandatory gates permit write readiness only when satisfied")
    func allMandatoryGatesPermitWriteReadinessOnlyWhenSatisfied() {
        let ready = ScoreKeepWriteReadinessInput(
            sourceClassification: .existingProposedV2Store,
            constructionSucceeded: true,
            requiredMigrationCompleted: true,
            postOpenVerificationPassed: true,
            completionEvidenceReconciled: true,
            hasUncertainty: false,
            recoveryRequired: false,
            routeChoice: .proposedV2Active,
            proposedSchemaActive: true,
            storeIsWritable: true,
            oneWriterPolicyAvailable: true,
            diagnosticsIdentifyAuthority: true,
            productionCutoverApprovalSupplied: true
        )

        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(ready).permitsBaseballWrites)

        var missingApproval = ready
        missingApproval.productionCutoverApprovalSupplied = false
        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(missingApproval).blockingReasons.contains("productionCutoverApprovalMissing"))

        var uncertain = ready
        uncertain.hasUncertainty = true
        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(uncertain).permitsBaseballWrites == false)

        var recovery = ready
        recovery.recoveryRequired = true
        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(recovery).blockingReasons.contains("recoveryRequired"))

        var disabled = ready
        disabled.routeChoice = .proposedV2PreparedButDisabled
        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(disabled).blockingReasons.contains("routeNotActive"))

        var readOnly = ready
        readOnly.storeIsWritable = false
        #expect(ScoreKeepWriteReadinessEvaluator.evaluate(readOnly).blockingReasons.contains("storeReadOnly"))
    }

    @Test("startup outcomes and current route default remain deterministic")
    func startupOutcomesAndCurrentRouteDefaultRemainDeterministic() {
        #expect(ScoreKeepSchemaRouteChoice.currentDefault == .legacyUnversionedProductionStartup)

        let legacy = ScoreKeepStartupOutcome.outcome(for: .legacyStartupActive)
        #expect(legacy.mayUseLegacyStartup)
        #expect(legacy.mayWriteBaseballRecords)

        let disabled = ScoreKeepStartupOutcome.outcome(for: .proposedStartupPreparedButDisabled)
        #expect(disabled.mayShowAppContent)
        #expect(disabled.mayWriteBaseballRecords == false)

        let uncertain = ScoreKeepStartupOutcome.outcome(for: .migrationCompletionUncertain)
        #expect(uncertain.automaticFallbackProhibited)
        #expect(uncertain.sourcePreservationMustRemain)
        #expect(uncertain.diagnosticsRequired)
    }

    @Test("privacy diagnostics omit paths and baseball contents")
    func privacyDiagnosticsOmitPathsAndBaseballContents() {
        let diagnostic = ScoreKeepStartupDiagnosticSummary(
            factoryPath: "ScoreKeepProposedContainerFactory.construct",
            routeChoice: .proposedV2EligibleForIsolatedVerification,
            storeLocationKind: .disposableTestStore,
            sourceClassification: .populatedCurrentUnversionedStore,
            migrationDiagnosticToken: "migration-1-token",
            targetSchema: .proposedV2,
            constructionDisposition: .containerCreatedVerificationPending,
            verificationDisposition: "notRun",
            writeReadinessDisposition: "writesProhibited",
            disableState: .proposedV2PreparedButDisabled,
            recoveryRequired: false,
            stableDiagnosticCodes: ["startup.factory.containerCreatedVerificationPending"]
        )

        #expect(diagnostic.storeLocationKind == .disposableTestStore)
        #expect(diagnostic.stableDiagnosticCodes.allSatisfy { !$0.contains("/") })
    }
}
