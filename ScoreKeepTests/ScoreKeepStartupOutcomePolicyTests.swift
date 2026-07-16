import Foundation
import Testing
@testable import ScoreKeep

@Suite("Startup outcome policy")
struct ScoreKeepStartupOutcomePolicyTests {
    @Test("startup presentation values are privacy safe and deterministic")
    func startupPresentationValuesArePrivacySafe() {
        for code in ScoreKeepStartupPresentationCode.allCases {
            let presentation = ScoreKeepStartupOutcomePolicy.presentation(for: code)
            #expect(presentation.stableDiagnosticCode == "startup.\(code.rawValue)")
            #expect(presentation.stableDiagnosticCode.contains("/") == false)
            #expect(presentation.stableDiagnosticCode.contains("ScoreKeep.store") == false)
        }
    }

    @Test("legacy prepared disabled read only retry and recovery workflows map to expected gates")
    func workflowPoliciesMapExpectedGates() {
        let legacy = ScoreKeepStartupOutcomePolicy.workflow(for: .legacyNormal)
        #expect(legacy.mayWriteRecords)
        #expect(legacy.mayBeginScoring)
        #expect(legacy.legacyFallbackProhibited == false)

        let disabled = ScoreKeepStartupOutcomePolicy.workflow(for: .proposedPreparedDisabled)
        #expect(disabled.mayReadRecords)
        #expect(disabled.mayWriteRecords == false)
        #expect(disabled.mayBeginTeamCreation == false)

        let retry = ScoreKeepStartupOutcomePolicy.workflow(for: .retryPermitted)
        #expect(retry.mayOfferRetry)
        #expect(retry.retryMustReuseSameMigrationIdentity)
        #expect(retry.legacyFallbackProhibited)

        let uncertain = ScoreKeepStartupOutcomePolicy.workflow(for: .completionUncertain)
        #expect(uncertain.mustRemainOnStartupOrRecoverySurface)
        #expect(uncertain.backupMustBeRetained)
    }

    @Test("orchestrator dispositions map to startup outcomes")
    func orchestratorDispositionsMap() {
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: .completed) == .migrationCompleted)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: .interrupted) == .migrationInterrupted)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: .sourcePreservationFailed) == .backupVerificationFailed)
        #expect(ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: .verificationFailed) == .recoveryRequired)
    }
}
