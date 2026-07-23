import Foundation
import Testing
@testable import ScoreKeep

@Suite("Task 8.13 Existing-Data Access Suite")
struct Task813ExistingDataAccessSuite {
    @Test("Existing-record review proceeds from source-data ownership with inactive entitlement")
    func existingRecordReviewProceedsFromSourceDataOwnershipWithInactiveEntitlement() {
        let action = PurchaseGatedAction.existingRecordReview
        let workflow = workflowState(for: action)
        let decision = PurchaseGatingPolicy.decide(
            action: action,
            entitlement: .inactive,
            workflow: workflow
        )

        #expect(decision.action == action)
        #expect(decision.disposition == .proceed(.sourceDataOwnership))
        #expect(decision.permitsAction)
        #expect(!decision.requiresPaywall)
        #expect(decision.pendingWorkflow == nil)
    }

    @Test("Compatible source-data export proceeds from source-data ownership with inactive entitlement")
    func compatibleSourceDataExportProceedsFromSourceDataOwnershipWithInactiveEntitlement() {
        let action = PurchaseGatedAction.compatibleSourceDataExport
        let workflow = workflowState(for: action)
        let decision = PurchaseGatingPolicy.decide(
            action: action,
            entitlement: .inactive,
            workflow: workflow
        )

        #expect(decision.action == action)
        #expect(decision.disposition == .proceed(.sourceDataOwnership))
        #expect(decision.permitsAction)
        #expect(!decision.requiresPaywall)
        #expect(decision.pendingWorkflow == nil)
    }

    @Test("Existing-data lifecycle performs immediately clears state and remains deterministic")
    func existingDataLifecyclePerformsImmediatelyClearsStateAndRemainsDeterministic() {
        for action in existingDataActions {
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let workflow = workflowState(for: action)

            let firstTransition = lifecycle.request(
                action: action,
                entitlement: .inactive,
                workflow: workflow
            )
            let stateAfterFirstRequest = lifecycle.state
            let secondTransition = lifecycle.request(
                action: action,
                entitlement: .inactive,
                workflow: workflow
            )
            let stateAfterSecondRequest = lifecycle.state

            #expect(firstTransition == .perform(action))
            #expect(stateAfterFirstRequest == .none)
            #expect(secondTransition == .perform(action))
            #expect(stateAfterSecondRequest == .none)
        }
    }

    @Test("Inactive generated-output comparison still requires paywall and pending workflow")
    func inactiveGeneratedOutputComparisonStillRequiresPaywallAndPendingWorkflow() {
        for action in generatedOutputActions {
            let workflow = workflowState(for: action)
            let decision = PurchaseGatingPolicy.decide(
                action: action,
                entitlement: .inactive,
                workflow: workflow
            )
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let transition = lifecycle.request(
                action: action,
                entitlement: .inactive,
                workflow: workflow
            )

            #expect(decision.disposition == .requiresPaywall)
            #expect(!decision.permitsAction)
            #expect(decision.requiresPaywall)
            #expect(decision.pendingWorkflow == workflow)
            #expect(transition == .presentPaywall)
            #expect(lifecycle.state == .awaitingActivePurchaseFlow(workflow))
        }
    }

    @Test("Current-season entitlement comparison still allows generated output")
    func currentSeasonEntitlementComparisonStillAllowsGeneratedOutput() {
        for action in generatedOutputActions {
            let decision = PurchaseGatingPolicy.decide(
                action: action,
                entitlement: .activeCurrentSeason,
                workflow: workflowState(for: action)
            )
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let transition = lifecycle.request(
                action: action,
                entitlement: .activeCurrentSeason,
                workflow: workflowState(for: action)
            )

            #expect(decision.disposition == .proceed(.currentSeasonEntitlement))
            #expect(decision.permitsAction)
            #expect(!decision.requiresPaywall)
            #expect(decision.pendingWorkflow == nil)
            #expect(transition == .perform(action))
            #expect(lifecycle.state == .none)
        }
    }

    private var existingDataActions: [PurchaseGatedAction] {
        [.existingRecordReview, .compatibleSourceDataExport]
    }

    private var generatedOutputActions: [PurchaseGatedAction] {
        [.scorecardPDF, .hittingStatistics, .pitchingStatistics]
    }

    private func workflowState(for action: PurchaseGatedAction) -> PurchaseGatedWorkflowState {
        PurchaseGatedWorkflowState(
            action: action,
            gameIdentity: UUID(uuidString: "81300000-0000-0000-0000-000000000001"),
            teamIdentity: UUID(uuidString: "81300000-0000-0000-0000-000000000002"),
            scopeDescription: "Task 8.13 owned source-data scope",
            idempotencyKey: "task-813-\(action.rawValue)"
        )
    }
}
