import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Simple team production routing")
struct SimpleTeamProductionRoutingTests {
    @Test("proposed service creates one team through adapter evidence and dedicated context")
    func proposedServiceCreatesOneTeamThroughAdapterEvidenceAndDedicatedContext() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = SimpleTeamCreationRoutingService(
            container: container,
            routeSelection: .proposed,
            readiness: CanonicalTeamCreationWriteReadinessSnapshot(
                storeOpenedSuccessfully: true,
                sourceVersionState: .supportedCurrent,
                migrationState: .complete,
                cutoverApprovalPresent: true
            ),
            activeContainerAuthority: "proposedV2",
            migrationCompletionState: "completed"
        )
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("ui-simple-team-op-001"),
            teamIdentity: UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!,
            teamName: "Manual Route Team",
            coach: "Coach Route",
            details: "Created from value request"
        )

        let outcome = await service.submit(submission)
        let teams = try IsolatedVersionedTeamCreationEvidenceSupport.observedTeams(from: container)

        #expect(outcome.disposition == .created)
        #expect(outcome.shouldClearFields)
        #expect(teams == [TeamCreationObservedTeam(identity: submission.teamIdentity, name: submission.teamName, coach: submission.coach, details: submission.details)])
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: container) == 1)
        #expect(service.lastDiagnostics.contextOwnership == "proposedDedicatedOperationContext")
        #expect(service.lastDiagnostics.autosaveState == "disabled")
        #expect(service.lastDiagnostics.saveCountClassification == "oneExplicitBaseballSave")
        #expect(service.lastDiagnostics.uiSecondSavePrevented)
    }

    @Test("repeat submission returns completed outcome without duplicate team")
    func repeatSubmissionReturnsCompletedOutcomeWithoutDuplicateTeam() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = proposedService(container: container)
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("ui-simple-team-op-repeat"),
            teamIdentity: UUID(uuidString: "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff")!,
            teamName: "Repeat Route Team",
            coach: "",
            details: ""
        )

        _ = await service.submit(submission)
        let repeatOutcome = await service.submit(submission)

        #expect(repeatOutcome.disposition == .alreadyCompleted)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 1)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: container) == 1)
    }

    @Test("blocked service does not create team or evidence")
    func blockedServiceDoesNotCreateTeamOrEvidence() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = SimpleTeamCreationRoutingService(
            container: container,
            routeSelection: .proposed,
            readiness: CanonicalTeamCreationWriteReadinessSnapshot(
                storeOpenedSuccessfully: true,
                sourceVersionState: .supportedCurrent,
                migrationState: .interrupted,
                cutoverApprovalPresent: true
            ),
            activeContainerAuthority: "proposedV2",
            migrationCompletionState: "interrupted"
        )
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("ui-simple-team-op-blocked"),
            teamIdentity: UUID(uuidString: "cccccccc-dddd-4eee-8fff-aaaaaaaaaaaa")!,
            teamName: "Blocked Route Team",
            coach: "",
            details: ""
        )

        let outcome = await service.submit(submission)

        #expect(outcome.disposition == .migrationRequired)
        #expect(outcome.shouldClearFields == false)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.teamCount(in: container) == 0)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: container) == 0)
    }

    @Test("production activation is enabled after disposable rehearsal")
    func productionActivationIsEnabledAfterDisposableRehearsal() {
        #expect(ScoreKeepProductionStartupRouteApproval.simpleTeamCreationProductionEnabled)
        #expect(ScoreKeepProductionStartupRouteApproval.disposableProposedNormalUIRehearsalEnabled)
    }

    @Test("routing summary uses current routed team evidence separate from immutable baseline")
    func routingSummaryUsesCurrentRoutedTeamEvidenceSeparateFromImmutableBaseline() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let service = proposedService(container: container)
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("ui-simple-team-op-summary"),
            teamIdentity: UUID(uuidString: "dddddddd-eeee-4fff-8aaa-bbbbbbbbbbbb")!,
            teamName: "Summary Route Team",
            coach: "",
            details: ""
        )

        _ = await service.submit(submission)
        let summary = SimpleTeamCreationRoutingRehearsalSummary.make(
            container: container,
            diagnostics: service.lastDiagnostics,
            disposableBundleStatus: "disposableMigrationTest",
            migrationJournalStatus: "completedMigrationJournalRecognized",
            migrationComparisonEvidence: "matchesStoredLegacyBaseline",
            immutableLegacyBaselineEvidence: "loaded immutable Legacy baseline count: four teams"
        )
        let copyableSummary = summary.copyableSummary
        let sections = copyableSummary.components(separatedBy: "\n\nMigration-Comparison Evidence\n")

        #expect(summary.routeSelection == .proposed)
        #expect(summary.routedTemporaryTeamPersistenceStatus == "exactlyOne")
        #expect(summary.routedTemporaryTeamRelaunchStatus == "presentExactlyOnce")
        #expect(sections.first?.contains("four teams") == false)
        #expect(sections.last?.contains("Stored Legacy Baseline: loaded immutable Legacy baseline count: four teams") == true)
        #expect(copyableSummary.contains("Prepared Proposed V2, disabled") == false)
        #expect(copyableSummary.contains("Migration Phase: notStarted") == false)
        #expect(copyableSummary.contains("Proposed Writes: prohibited") == false)
    }

    @Test("routing summary survives relaunch-style diagnostics reset from durable evidence")
    func routingSummarySurvivesRelaunchStyleDiagnosticsResetFromDurableEvidence() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let serviceBeforeRelaunch = proposedService(container: container)
        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity("ui-simple-team-op-relaunch-summary"),
            teamIdentity: UUID(uuidString: "eeeeeeee-ffff-4000-8bbb-cccccccccccc")!,
            teamName: "Relaunch Summary Team",
            coach: "",
            details: ""
        )

        _ = await serviceBeforeRelaunch.submit(submission)
        let serviceAfterRelaunch = proposedService(container: container)
        let summary = SimpleTeamCreationRoutingRehearsalSummary.make(
            container: container,
            diagnostics: serviceAfterRelaunch.lastDiagnostics,
            disposableBundleStatus: "disposableMigrationTest",
            migrationJournalStatus: "completedMigrationJournalRecognized",
            migrationComparisonEvidence: "matchesStoredLegacyBaseline",
            immutableLegacyBaselineEvidence: "loaded immutable Legacy baseline count: four teams"
        )

        #expect(serviceAfterRelaunch.lastDiagnostics.routeSelected == .legacy)
        #expect(summary.routeSelection == .proposed)
        #expect(summary.durableEvidenceStatus == "recorded")
        #expect(summary.dedicatedOperationContextStatus == "used")
        #expect(summary.autosaveStatus == "disabled")
        #expect(summary.baseballSaveStatus == "exactlyOne")
        #expect(summary.freshContextVerificationStatus == "passed")
        #expect(summary.teamViewSecondSaveStatus == "absent")
    }

    private func proposedService(container: ModelContainer) -> SimpleTeamCreationRoutingService {
        SimpleTeamCreationRoutingService(
            container: container,
            routeSelection: .proposed,
            readiness: CanonicalTeamCreationWriteReadinessSnapshot(
                storeOpenedSuccessfully: true,
                sourceVersionState: .supportedCurrent,
                migrationState: .complete,
                cutoverApprovalPresent: true
            ),
            activeContainerAuthority: "proposedV2",
            migrationCompletionState: "completed"
        )
    }
}
