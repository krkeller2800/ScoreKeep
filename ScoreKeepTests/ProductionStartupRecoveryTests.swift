import Foundation
import Testing
@testable import ScoreKeep

@Suite("Production startup recovery")
struct ProductionStartupRecoveryTests {
    @Test("recovery presentations are deterministic privacy safe and action scoped")
    func recoveryPresentationsArePrivacySafeAndActionScoped() {
        for code in ScoreKeepProductionStartupDiagnosticCode.allCases {
            let presentation = ScoreKeepProductionStartupRecoveryPresentation.make(
                diagnosticCode: code,
                protectedDataState: .available,
                capacityStatus: "capacity.sufficient",
                sourceStatus: "populatedCurrentUnversionedStore",
                backupStatus: "present",
                migrationPhase: "backupVerified",
                targetVerification: "notRun",
                retryAllowed: code == .migrationInterruptedRetryable || code == .capacityInsufficient
            )

            #expect(presentation.supportSummary.contains("/") == false)
            #expect(presentation.supportSummary.contains(".store") == false)
            #expect(presentation.supportSummary.contains("Proposed V2") == false)
            #expect(presentation.supportSummary.contains("00000000-0000-0000-0000") == false)
            #expect(presentation.title.contains("Proposed") == false)
            #expect(presentation.explanation.contains("journal") == false)
            #expect(presentation.actions.contains(.copySupportSummary))
        }
    }

    @Test("protected data capacity recovery and retry states expose only safe actions")
    func blockedStatesExposeOnlySafeActions() {
        let protected = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .protectedDataUnavailable,
            protectedDataState: .unavailable,
            capacityStatus: "notAssessed",
            sourceStatus: "notAssessed",
            backupStatus: "uncertain",
            migrationPhase: "protectedDataUnavailable",
            targetVerification: "notRun",
            retryAllowed: false
        )
        #expect(protected.actions.contains(.unlockDevice))
        #expect(protected.actions.contains(.retry) == false)
        #expect(protected.retryAllowed == false)

        let capacity = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .capacityInsufficient,
            protectedDataState: .available,
            capacityStatus: "capacity.insufficient",
            sourceStatus: "populatedCurrentUnversionedStore",
            backupStatus: "absent",
            migrationPhase: "notStarted",
            targetVerification: "notRun",
            retryAllowed: true
        )
        #expect(capacity.actions.contains(.freeUpStorage))
        #expect(capacity.actions.contains(.retry))
        #expect(capacity.retryAllowed)

        let retrying = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .migrationInterruptedRetryable,
            protectedDataState: .available,
            capacityStatus: "reassessing",
            sourceStatus: "reassessing",
            backupStatus: "reassessing",
            migrationPhase: "retrying",
            targetVerification: "notRun",
            retryAllowed: false,
            retryInProgress: true
        )
        #expect(retrying.diagnosticCode == .retryInProgress)
        #expect(retrying.actions.contains(.retry) == false)
        #expect(retrying.retryAllowed == false)
    }

    @Test("journal and orchestrator outcomes fail closed without writable UI")
    func startupOutcomeMappingsFailClosed() {
        for disposition in ScoreKeepMigrationOrchestratorDisposition.allCases {
            let code = ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: disposition)
            let workflow = ScoreKeepStartupOutcomePolicy.workflow(for: code)
            if disposition != .completed && disposition != .disabled {
                #expect(workflow.mayWriteRecords == false)
            }
        }

        let corrupt = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .journalCorrupt,
            protectedDataState: .available,
            capacityStatus: "notAssessed",
            sourceStatus: "uncertain",
            backupStatus: "uncertain",
            migrationPhase: "journalUnreadable",
            targetVerification: "notRun",
            retryAllowed: false
        )
        #expect(corrupt.retryAllowed == false)
        #expect(corrupt.actions.contains(.retry) == false)
        #expect(corrupt.actions == [.copySupportSummary])
    }
}
