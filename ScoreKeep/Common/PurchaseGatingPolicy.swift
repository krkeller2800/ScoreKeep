import Foundation

/// Pure policy for purchase-gated generated-output decisions. It does not call
/// StoreKit, touch allowance counters, generate output, or own baseball records.
struct PurchaseGatingPolicy {
    static func decide(
        action: PurchaseGatedAction,
        entitlement: EntitlementState,
        workflow: PurchaseGatedWorkflowState
    ) -> PurchaseGatingDecision {
        decide(
            action: action,
            entitlement: PurchaseDecisionAuthority().purchaseEntitlementState(for: entitlement),
            workflow: workflow
        )
    }

    static func decide(
        action: PurchaseGatedAction,
        entitlement: PurchaseEntitlementState,
        workflow: PurchaseGatedWorkflowState
    ) -> PurchaseGatingDecision {
        guard action.requiresCurrentSeasonEntitlement else {
            return PurchaseGatingDecision(
                action: action,
                disposition: .proceed(.sourceDataOwnership),
                pendingWorkflow: nil
            )
        }

        switch entitlement {
        case .activeCurrentSeason:
            return PurchaseGatingDecision(
                action: action,
                disposition: .proceed(.currentSeasonEntitlement),
                pendingWorkflow: nil
            )
        case .inactive:
            return PurchaseGatingDecision(
                action: action,
                disposition: .requiresPaywall,
                pendingWorkflow: workflow
            )
        }
    }
}

struct PurchaseGatedWorkflowLifecycle: Hashable, Sendable {
    private(set) var state: PurchaseGatedWorkflowLifecycleState = .none

    mutating func request(
        action: PurchaseGatedAction,
        entitlement: PurchaseEntitlementState,
        workflow: PurchaseGatedWorkflowState
    ) -> PurchaseGatedWorkflowTransition {
        let decision = PurchaseGatingPolicy.decide(
            action: action,
            entitlement: entitlement,
            workflow: workflow
        )

        switch decision.disposition {
        case .proceed:
            state = .none
            return .perform(action)
        case .requiresPaywall:
            if let pendingWorkflow = decision.pendingWorkflow {
                state = .awaitingActivePurchaseFlow(pendingWorkflow)
            } else {
                state = .none
            }
            return .presentPaywall
        }
    }

    mutating func entitlementBecameActive() -> PurchaseGatedWorkflowTransition {
        guard case .awaitingActivePurchaseFlow(let workflow) = state else {
            return .none
        }

        state = .consumed(workflow)
        let action = workflow.action
        state = .none
        return .perform(action)
    }

    mutating func purchaseFlowDismissedOrAbandoned() -> PurchaseGatedWorkflowTransition {
        guard case .awaitingActivePurchaseFlow(let workflow) = state else {
            return .none
        }

        state = .canceled(workflow)
        state = .none
        return .none
    }
}

enum PurchaseGatedWorkflowLifecycleState: Hashable, Sendable {
    case none
    case awaitingActivePurchaseFlow(PurchaseGatedWorkflowState)
    case consumed(PurchaseGatedWorkflowState)
    case canceled(PurchaseGatedWorkflowState)
}

enum PurchaseGatedWorkflowTransition: Hashable, Sendable {
    case none
    case presentPaywall
    case perform(PurchaseGatedAction)
}

enum PurchaseGatedAction: String, CaseIterable, Hashable, Sendable {
    case scorecardPDF
    case hittingStatistics
    case pitchingStatistics
    case existingRecordReview
    case compatibleSourceDataExport

    var requiresCurrentSeasonEntitlement: Bool {
        switch self {
        case .scorecardPDF, .hittingStatistics, .pitchingStatistics:
            return true
        case .existingRecordReview, .compatibleSourceDataExport:
            return false
        }
    }
}

enum PurchaseEntitlementState: Hashable, Sendable {
    case activeCurrentSeason
    case inactive
}

struct PurchaseGatedWorkflowState: Hashable, Sendable {
    let action: PurchaseGatedAction
    let gameIdentity: UUID?
    let teamIdentity: UUID?
    let scopeDescription: String
    let idempotencyKey: String

    init(
        action: PurchaseGatedAction,
        gameIdentity: UUID?,
        teamIdentity: UUID?,
        scopeDescription: String,
        idempotencyKey: String
    ) {
        self.action = action
        self.gameIdentity = gameIdentity
        self.teamIdentity = teamIdentity
        self.scopeDescription = scopeDescription
        self.idempotencyKey = idempotencyKey
    }
}

struct PurchaseGatingDecision: Hashable, Sendable {
    let action: PurchaseGatedAction
    let disposition: PurchaseGatingDisposition
    let pendingWorkflow: PurchaseGatedWorkflowState?

    var permitsAction: Bool {
        if case .proceed = disposition { return true }
        return false
    }

    var requiresPaywall: Bool {
        if case .requiresPaywall = disposition { return true }
        return false
    }
}

enum PurchaseGatingDisposition: Hashable, Sendable {
    case proceed(PurchaseGateAccessBasis)
    case requiresPaywall
}

enum PurchaseGateAccessBasis: Hashable, Sendable {
    case currentSeasonEntitlement
    case sourceDataOwnership
}

struct PurchaseDecisionAuthority: Equatable, Sendable {
    func decision(for entitlement: EntitlementState) -> PurchaseAccessDecision {
        switch entitlement {
        case .entitled:
            return .currentSeasonEntitled
        case .notEntitled, .priorSeason, .futureSeason, .statusUnavailable:
            return .notCurrentSeasonEntitled(entitlement)
        }
    }

    func purchaseEntitlementState(for entitlement: EntitlementState) -> PurchaseEntitlementState {
        decision(for: entitlement).permitsCurrentSeasonAccess ? .activeCurrentSeason : .inactive
    }
}

enum PurchaseAccessDecision: Hashable, Sendable {
    case currentSeasonEntitled
    case notCurrentSeasonEntitled(EntitlementState)

    var permitsCurrentSeasonAccess: Bool {
        switch self {
        case .currentSeasonEntitled:
            return true
        case .notCurrentSeasonEntitled:
            return false
        }
    }
}

struct AllowanceWriterRoutingAuthority: Equatable, Sendable {
    func writerRoute(for action: QualifyingAllowanceAction) -> AllowanceWriterRoute {
        switch action {
        case .successfulGameCreation:
            return .task922GameCreationTransaction
        case .successfulMLBRosterDownloadImport:
            return .task923RosterDownloadTransaction
        }
    }

    func legacyMutationDecision(for action: NonQualifyingAllowanceAction) -> LegacyAllowanceMutationDecision {
        .retired(action)
    }

    func resetDecision(buildConfiguration: FreeGameAllowanceBuildConfiguration) -> AllowanceResetDecision {
        switch FreeGameAllowanceDebugResetPolicy.classify(buildConfiguration: buildConfiguration) {
        case .debugOnlyResetToDefault:
            return .debugOnly
        case .noProductionReset:
            return .notPermittedInProduction
        }
    }
}

enum AllowanceWriterRoute: Hashable, Sendable {
    case task922GameCreationTransaction
    case task923RosterDownloadTransaction
}

enum LegacyAllowanceMutationDecision: Hashable, Sendable {
    case retired(NonQualifyingAllowanceAction)
}

enum AllowanceResetDecision: Hashable, Sendable {
    case debugOnly
    case notPermittedInProduction
}
