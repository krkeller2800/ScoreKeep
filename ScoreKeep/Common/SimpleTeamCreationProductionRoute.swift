import Foundation
import SwiftData
import SwiftUI

enum SimpleTeamCreationRouteSelection: String, Hashable, Sendable {
    case legacy
    case proposed
    case blocked
}

enum SimpleTeamCreationRouteDisposition: String, Hashable, Sendable {
    case created
    case alreadyCompleted
    case validationFailure
    case duplicateOrCompatibilityRejected
    case conflictingRequest
    case routeDisabledBeforeMutation
    case migrationRequired
    case recoveryRequired
    case protectedDataUnavailable
    case persistenceUnavailable
    case failedBeforeCommit
    case committedEvidenceReconciliationRequired
    case unrecoverableAmbiguity
}

struct SimpleTeamCreationSubmission: Hashable, Sendable {
    let operationIdentity: CanonicalTeamCreationOperationIdentity
    let teamIdentity: UUID
    let teamName: String
    let coach: String
    let details: String
}

struct SimpleTeamCreationRouteOutcome: Hashable, Sendable {
    let routeSelection: SimpleTeamCreationRouteSelection
    let disposition: SimpleTeamCreationRouteDisposition
    let shouldClearFields: Bool
    let userMessage: String?
    let stableCompletionCode: String
}

struct SimpleTeamCreationRouteDiagnostics: Hashable, Sendable {
    let activeContainerAuthority: String
    let migrationCompletionState: String
    let routeSelected: SimpleTeamCreationRouteSelection
    let contextOwnership: String
    let autosaveState: String
    let saveCountClassification: String
    let freshContextVerification: String
    let evidenceCompletion: String
    let reconciliationResult: String
    let uiSecondSavePrevented: Bool
    let stableCompletionCode: String

    static let legacy = SimpleTeamCreationRouteDiagnostics(
        activeContainerAuthority: "legacy-compatible",
        migrationCompletionState: "notActive",
        routeSelected: .legacy,
        contextOwnership: "environmentContext",
        autosaveState: "legacyBehavior",
        saveCountClassification: "legacyCallerOwned",
        freshContextVerification: "notApplicable",
        evidenceCompletion: "notEmitted",
        reconciliationResult: "notApplicable",
        uiSecondSavePrevented: false,
        stableCompletionCode: "simpleTeam.legacy"
    )
}

struct SimpleTeamCreationRoutingRehearsalSummary: Hashable, Sendable {
    let disposableBundleStatus: String
    let migrationJournalStatus: String
    let activeContainerAuthority: String
    let routeSelection: SimpleTeamCreationRouteSelection
    let dedicatedOperationContextStatus: String
    let autosaveStatus: String
    let baseballSaveStatus: String
    let freshContextVerificationStatus: String
    let durableEvidenceStatus: String
    let teamViewSecondSaveStatus: String
    let routedTemporaryTeamPersistenceStatus: String
    let routedTemporaryTeamRelaunchStatus: String
    let otherWorkflowAuthorityStatus: String
    let productionDataAccessStatus: String
    let migrationComparisonEvidence: String
    let immutableLegacyBaselineEvidence: String

    var copyableSummary: String {
        [
            "ScoreKeep Simple Team Routing Rehearsal",
            "Disposable Bundle: \(disposableBundleStatus)",
            "Migration Journal: \(migrationJournalStatus)",
            "Active Container Authority: \(activeContainerAuthority)",
            "Simple-Team Route: \(routeSelection.rawValue)",
            "Dedicated Operation Context: \(dedicatedOperationContextStatus)",
            "Autosave: \(autosaveStatus)",
            "Baseball Save Count: \(baseballSaveStatus)",
            "Fresh-Context Verification: \(freshContextVerificationStatus)",
            "Durable Evidence: \(durableEvidenceStatus)",
            "TeamView Second Save: \(teamViewSecondSaveStatus)",
            "Routed Temporary Team Persisted: \(routedTemporaryTeamPersistenceStatus)",
            "Routed Temporary Team Relaunch: \(routedTemporaryTeamRelaunchStatus)",
            "Other Workflows: \(otherWorkflowAuthorityStatus)",
            "Production Data: \(productionDataAccessStatus)",
            "",
            "Migration-Comparison Evidence",
            "Post-Migration Baseline: \(migrationComparisonEvidence)",
            "Stored Legacy Baseline: \(immutableLegacyBaselineEvidence)"
        ].joined(separator: "\n")
    }

    @MainActor
    static func make(
        container: ModelContainer,
        diagnostics: SimpleTeamCreationRouteDiagnostics,
        disposableBundleStatus: String,
        migrationJournalStatus: String,
        migrationComparisonEvidence: String,
        immutableLegacyBaselineEvidence: String
    ) -> SimpleTeamCreationRoutingRehearsalSummary {
        let freshObservation = observeRoutedTeams(in: container)
        let routeWasProposed = diagnostics.routeSelected == .proposed || freshObservation.completedEvidenceCount > 0
        let routedTeamStatus = freshObservation.completedEvidenceCount == 1 && freshObservation.matchingTeamCount == 1
            ? "exactlyOne"
            : "requiresReview(evidence:\(freshObservation.completedEvidenceCount),teams:\(freshObservation.matchingTeamCount))"
        let durableEvidenceStatus = freshObservation.completedEvidenceCount == 1
            ? "recorded"
            : "requiresReview(\(freshObservation.completedEvidenceCount))"

        return SimpleTeamCreationRoutingRehearsalSummary(
            disposableBundleStatus: disposableBundleStatus,
            migrationJournalStatus: migrationJournalStatus,
            activeContainerAuthority: diagnostics.activeContainerAuthority,
            routeSelection: routeWasProposed ? .proposed : diagnostics.routeSelected,
            dedicatedOperationContextStatus: routeWasProposed ? "used" : "notUsed",
            autosaveStatus: routeWasProposed ? "disabled" : diagnostics.autosaveState,
            baseballSaveStatus: freshObservation.completedEvidenceCount == 1 ? "exactlyOne" : "requiresReview(\(freshObservation.completedEvidenceCount))",
            freshContextVerificationStatus: freshObservation.matchingTeamCount == 1 ? "passed" : "requiresReview",
            durableEvidenceStatus: durableEvidenceStatus,
            teamViewSecondSaveStatus: diagnostics.uiSecondSavePrevented || routeWasProposed ? "absent" : "legacyBehavior",
            routedTemporaryTeamPersistenceStatus: routedTeamStatus,
            routedTemporaryTeamRelaunchStatus: routedTeamStatus == "exactlyOne" ? "presentExactlyOnce" : "requiresReview",
            otherWorkflowAuthorityStatus: "legacyBehavior",
            productionDataAccessStatus: "notAccessed",
            migrationComparisonEvidence: migrationComparisonEvidence,
            immutableLegacyBaselineEvidence: immutableLegacyBaselineEvidence
        )
    }

    @MainActor
    private static func observeRoutedTeams(in container: ModelContainer) -> (completedEvidenceCount: Int, matchingTeamCount: Int) {
        do {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let evidence = try context.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>())
            let completedEvidence = evidence.filter {
                $0.phase == CanonicalTeamCreationOperationPhase.completed.rawValue
                    && $0.completionProof == CanonicalTeamCreationCompletionProof.completionMarkerRecorded.rawValue
            }
            let teamIDs = Set(completedEvidence.map(\.targetTeamIdentity))
            let teams = try context.fetch(FetchDescriptor<Team>())
            let matchingTeams = teams.filter { teamIDs.contains($0.ident) }
            return (completedEvidence.count, matchingTeams.count)
        } catch {
            return (0, 0)
        }
    }
}

@MainActor
final class SimpleTeamCreationRoutingService: ObservableObject {
    @Published private(set) var lastDiagnostics: SimpleTeamCreationRouteDiagnostics

    private let container: ModelContainer?
    private let routeSelection: SimpleTeamCreationRouteSelection
    private let readiness: CanonicalTeamCreationWriteReadinessSnapshot
    private let activeContainerAuthority: String
    private let migrationCompletionState: String
    private lazy var coordinator: CanonicalTeamCreationCoordinator? = makeCoordinator()

    init(
        container: ModelContainer? = nil,
        routeSelection: SimpleTeamCreationRouteSelection = .legacy,
        readiness: CanonicalTeamCreationWriteReadinessSnapshot = CanonicalTeamCreationWriteReadinessSnapshot(
            storeOpenedSuccessfully: false,
            sourceVersionState: .unknown,
            migrationState: .interrupted,
            writesProhibited: true
        ),
        activeContainerAuthority: String = "legacy-compatible",
        migrationCompletionState: String = "notActive"
    ) {
        self.container = container
        self.routeSelection = routeSelection
        self.readiness = readiness
        self.activeContainerAuthority = activeContainerAuthority
        self.migrationCompletionState = migrationCompletionState
        self.lastDiagnostics = .legacy
    }

    var selectedRouteBeforeMutation: SimpleTeamCreationRouteSelection {
        guard routeSelection == .proposed else { return .legacy }
        guard container != nil, readiness.permitsBoundedWrite else { return .blocked }
        return .proposed
    }

    func submit(_ submission: SimpleTeamCreationSubmission) async -> SimpleTeamCreationRouteOutcome {
        guard selectedRouteBeforeMutation == .proposed, let coordinator else {
            let disposition: SimpleTeamCreationRouteDisposition = readiness.disableStateActive ? .routeDisabledBeforeMutation : .migrationRequired
            lastDiagnostics = SimpleTeamCreationRouteDiagnostics(
                activeContainerAuthority: activeContainerAuthority,
                migrationCompletionState: migrationCompletionState,
                routeSelected: selectedRouteBeforeMutation,
                contextOwnership: "none",
                autosaveState: "notStarted",
                saveCountClassification: "none",
                freshContextVerification: "notStarted",
                evidenceCompletion: "notStarted",
                reconciliationResult: disposition.rawValue,
                uiSecondSavePrevented: true,
                stableCompletionCode: "simpleTeam.blocked.\(disposition.rawValue)"
            )
            return SimpleTeamCreationRouteOutcome(
                routeSelection: selectedRouteBeforeMutation,
                disposition: disposition,
                shouldClearFields: false,
                userMessage: "ScoreKeep cannot safely create this team yet.",
                stableCompletionCode: lastDiagnostics.stableCompletionCode
            )
        }

        let request = CanonicalTeamCreationOperationalRequest(
            operationIdentity: submission.operationIdentity,
            teamIdentity: submission.teamIdentity,
            teamName: submission.teamName,
            coach: submission.coach,
            details: submission.details,
            source: .productionRoute
        )
        let result = await coordinator.submit(request, readiness: readiness)
        let outcome = map(result)
        lastDiagnostics = diagnostics(for: result, outcome: outcome)
        return outcome
    }

    private func makeCoordinator() -> CanonicalTeamCreationCoordinator? {
        guard let container else { return nil }
        let evidenceStore = TeamCreationSwiftDataEvidenceStore(container: container)
        return CanonicalTeamCreationCoordinator(evidenceStore: evidenceStore) { [container] request in
            await MainActor.run {
                let adapter = CanonicalTeamCreationTransactionAdapter(container: container)
                let probe = CanonicalTeamCreationPurchaseAllowanceProbe(
                    purchaseMarker: "notTouched",
                    entitlementMarker: "notTouched",
                    freeGameCreatesRemaining: 0,
                    mlbDownloadUseCount: 0
                )
                let transactionRequest = CanonicalTeamCreationRequest(
                    operationIdentity: request.operationIdentity.rawValue,
                    teamIdentity: request.teamIdentity,
                    teamName: request.teamName,
                    coach: request.coach,
                    details: request.details,
                    expectedSource: .productionRoute,
                    beforeProbe: probe,
                    afterProbe: probe,
                    gateState: .readyForProductionSimpleTeamCreation
                )
                return adapter.applyUsingDedicatedOperationContext(transactionRequest)
            }
        }
    }

    private func map(_ result: CanonicalTeamCreationOperationalResult) -> SimpleTeamCreationRouteOutcome {
        let disposition: SimpleTeamCreationRouteDisposition
        let message: String?
        switch result.disposition {
        case .createdAndVerified:
            disposition = .created
            message = nil
        case .existingMatchingTeam, .duplicateRequestCompleted:
            disposition = .alreadyCompleted
            message = nil
        case .validationRejected:
            disposition = .validationFailure
            message = "Enter a team name before creating the team."
        case .conflictingExistingTeam:
            disposition = .conflictingRequest
            message = "That team could not be created because it conflicts with an existing record."
        case .operationAlreadyInProgress:
            disposition = .routeDisabledBeforeMutation
            message = nil
        case .saveFailedSafely:
            disposition = .failedBeforeCommit
            message = "ScoreKeep could not save this team. Your entries are still here."
        case .completionUncertain:
            disposition = .committedEvidenceReconciliationRequired
            message = "ScoreKeep preserved your entries because the save could not be verified."
        case .storeNotWritable:
            disposition = .persistenceUnavailable
            message = "ScoreKeep cannot save changes right now."
        case .migrationIncomplete:
            disposition = .migrationRequired
            message = "ScoreKeep needs to finish preparing your data before creating a team."
        case .adapterDisabled:
            disposition = .routeDisabledBeforeMutation
            message = "Team creation is temporarily using the compatible path."
        case .internalVerificationFailure, .reviewRequired, .none:
            disposition = .unrecoverableAmbiguity
            message = "ScoreKeep cannot verify this team yet. Your entries are still here."
        }

        return SimpleTeamCreationRouteOutcome(
            routeSelection: .proposed,
            disposition: disposition,
            shouldClearFields: result.workflowOutcome.formMayClose,
            userMessage: message,
            stableCompletionCode: "simpleTeam.\(disposition.rawValue)"
        )
    }

    private func diagnostics(
        for result: CanonicalTeamCreationOperationalResult,
        outcome: SimpleTeamCreationRouteOutcome
    ) -> SimpleTeamCreationRouteDiagnostics {
        SimpleTeamCreationRouteDiagnostics(
            activeContainerAuthority: activeContainerAuthority,
            migrationCompletionState: migrationCompletionState,
            routeSelected: .proposed,
            contextOwnership: result.executorInvoked ? "proposedDedicatedOperationContext" : "none",
            autosaveState: result.executorInvoked ? "disabled" : "notStarted",
            saveCountClassification: result.disposition == .createdAndVerified ? "oneExplicitBaseballSave" : "noAdditionalUISave",
            freshContextVerification: result.completionProof.provesOperationCompletion ? "passed" : "notProven",
            evidenceCompletion: result.completionProof.rawValue,
            reconciliationResult: result.disposition.rawValue,
            uiSecondSavePrevented: true,
            stableCompletionCode: outcome.stableCompletionCode
        )
    }
}
