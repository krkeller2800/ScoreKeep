import Foundation
import Testing
@testable import ScoreKeep

@Suite("Task 8.12 Purchase Gating Suite")
struct Task812PurchaseGatingSuite {
    @Test("Entitled generated-output requests proceed immediately")
    func entitledGeneratedOutputRequestsProceedImmediately() {
        for action in generatedOutputActions {
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let transition = lifecycle.request(
                action: action,
                entitlement: .activeCurrentSeason,
                workflow: workflowState(for: action)
            )

            #expect(transition == .perform(action))
            #expect(lifecycle.state == .none)
        }
    }

    @Test("Inactive generated-output requests require paywall and preserve the action")
    func inactiveGeneratedOutputRequestsRequirePaywallAndPreserveAction() {
        for action in generatedOutputActions {
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let workflow = workflowState(for: action)
            let transition = lifecycle.request(
                action: action,
                entitlement: .inactive,
                workflow: workflow
            )

            #expect(transition == .presentPaywall)
            #expect(lifecycle.state == .awaitingActivePurchaseFlow(workflow))
        }
    }

    @Test("Active entitlement during current pending flow resumes once and clears before execution")
    func activeEntitlementDuringCurrentPendingFlowResumesOnceAndClearsBeforeExecution() {
        var lifecycle = PurchaseGatedWorkflowLifecycle()
        let workflow = workflowState(for: .scorecardPDF)
        var performedActions: [PurchaseGatedAction] = []
        var observedStateBeforeExecution: PurchaseGatedWorkflowLifecycleState?

        apply(
            lifecycle.request(action: .scorecardPDF, entitlement: .inactive, workflow: workflow),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )
        apply(
            lifecycle.entitlementBecameActive(),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )
        apply(
            lifecycle.entitlementBecameActive(),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )

        #expect(performedActions == [.scorecardPDF])
        #expect(observedStateBeforeExecution == Optional.some(.none))
        #expect(lifecycle.state == .none)
    }

    @Test("Paywall dismissal clears pending request and later entitlement does not execute abandoned action")
    func paywallDismissalClearsPendingRequestAndLaterEntitlementDoesNotExecuteAbandonedAction() {
        var lifecycle = PurchaseGatedWorkflowLifecycle()
        let workflow = workflowState(for: .pitchingStatistics)
        var performedActions: [PurchaseGatedAction] = []
        var observedStateBeforeExecution: PurchaseGatedWorkflowLifecycleState?

        apply(
            lifecycle.request(action: .pitchingStatistics, entitlement: .inactive, workflow: workflow),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )
        apply(
            lifecycle.purchaseFlowDismissedOrAbandoned(),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )
        apply(
            lifecycle.entitlementBecameActive(),
            lifecycle: lifecycle,
            performedActions: &performedActions,
            observedStateBeforeExecution: &observedStateBeforeExecution
        )

        #expect(performedActions.isEmpty)
        #expect(observedStateBeforeExecution == nil)
        #expect(lifecycle.state == .none)
    }

    @Test("A new request after dismissal can establish a new pending workflow")
    func newRequestAfterDismissalCanEstablishNewPendingWorkflow() {
        var lifecycle = PurchaseGatedWorkflowLifecycle()
        let firstWorkflow = workflowState(for: .hittingStatistics)
        let secondWorkflow = PurchaseGatedWorkflowState(
            action: .scorecardPDF,
            gameIdentity: UUID(uuidString: "33333333-3333-3333-3333-333333333333"),
            teamIdentity: UUID(uuidString: "44444444-4444-4444-4444-444444444444"),
            scopeDescription: "Task 8.12 second request scope",
            idempotencyKey: "task-812-second-scorecardPDF"
        )

        let firstTransition = lifecycle.request(
            action: .hittingStatistics,
            entitlement: .inactive,
            workflow: firstWorkflow
        )
        let dismissalTransition = lifecycle.purchaseFlowDismissedOrAbandoned()
        let secondTransition = lifecycle.request(
            action: .scorecardPDF,
            entitlement: .inactive,
            workflow: secondWorkflow
        )

        #expect(firstTransition == .presentPaywall)
        #expect(dismissalTransition == .none)
        #expect(secondTransition == .presentPaywall)
        #expect(lifecycle.state == .awaitingActivePurchaseFlow(secondWorkflow))
    }

    @Test("Existing record review and compatible source-data export remain outside generated-output purchase gates")
    func existingDataAccessRemainsOutsideGeneratedOutputPurchaseGates() {
        for action in [PurchaseGatedAction.existingRecordReview, .compatibleSourceDataExport] {
            var lifecycle = PurchaseGatedWorkflowLifecycle()
            let transition = lifecycle.request(
                action: action,
                entitlement: .inactive,
                workflow: workflowState(for: action)
            )

            #expect(transition == .perform(action))
            #expect(lifecycle.state == .none)
        }
    }

    @Test("Policy uses only production-supported active and inactive entitlement states")
    func policyUsesOnlyProductionSupportedActiveAndInactiveEntitlementStates() {
        let activeDecision = PurchaseGatingPolicy.decide(
            action: .scorecardPDF,
            entitlement: .activeCurrentSeason,
            workflow: workflowState(for: .scorecardPDF)
        )
        let inactiveWorkflow = workflowState(for: .scorecardPDF)
        let inactiveDecision = PurchaseGatingPolicy.decide(
            action: .scorecardPDF,
            entitlement: .inactive,
            workflow: inactiveWorkflow
        )

        #expect(activeDecision.disposition == .proceed(.currentSeasonEntitlement))
        #expect(activeDecision.pendingWorkflow == nil)
        #expect(inactiveDecision.disposition == .requiresPaywall)
        #expect(inactiveDecision.pendingWorkflow == inactiveWorkflow)
    }

    private var generatedOutputActions: [PurchaseGatedAction] {
        [.scorecardPDF, .hittingStatistics, .pitchingStatistics]
    }

    private func workflowState(for action: PurchaseGatedAction) -> PurchaseGatedWorkflowState {
        PurchaseGatedWorkflowState(
            action: action,
            gameIdentity: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            teamIdentity: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
            scopeDescription: "Task 8.12 preserved report scope",
            idempotencyKey: "task-812-\(action.rawValue)"
        )
    }

    private func apply(
        _ transition: PurchaseGatedWorkflowTransition,
        lifecycle: PurchaseGatedWorkflowLifecycle,
        performedActions: inout [PurchaseGatedAction],
        observedStateBeforeExecution: inout PurchaseGatedWorkflowLifecycleState?
    ) {
        if case .perform(let action) = transition {
            observedStateBeforeExecution = lifecycle.state
            performedActions.append(action)
        }
    }
}
