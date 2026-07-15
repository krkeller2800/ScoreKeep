import Foundation

/// Side-effect-free cutover-gate review vocabulary for the non-routed team-creation adapter.
/// This type contains readiness evidence only; it does not access persistence, purchases, UI, or app services.
enum CanonicalTeamCreationCutoverGateStatus: String, CaseIterable, Hashable, Sendable {
    case satisfied
    case satisfiedForIsolatedTestingOnly
    case partiallySatisfied
    case notSatisfied
    case notApplicable
    case unsafe
    case unknown

    var blocksProductionReadiness: Bool {
        switch self {
        case .satisfied, .notApplicable:
            return false
        case .satisfiedForIsolatedTestingOnly, .partiallySatisfied, .notSatisfied, .unsafe, .unknown:
            return true
        }
    }
}

enum CanonicalTeamCreationCutoverVerdict: String, Hashable, Sendable {
    case readyForBoundedRoutingPreparation = "Ready for bounded routing preparation."
    case blockedPendingSpecificImplementationOrPolicyWork = "Blocked pending specific implementation or policy work."
    case unsafeForRouting = "Unsafe for routing."
}

enum CanonicalTeamCreationCutoverGateID: String, CaseIterable, Hashable, Sendable {
    case adapterCorrectness
    case productionCallSiteCompatibility
    case dedicatedContext
    case contextCleanliness
    case oneWriter
    case duplicateAndConcurrencySafety
    case durableIdempotency
    case schemaReadiness
    case sourceVersionAndMigrationStateReadiness
    case saveCompletionProof
    case disablePath
    case rollbackAndRecovery
    case userReviewPolicy
    case purchaseAndAllowanceSeparation
    case diagnosticSufficiency
    case testAdequacy
    case outOfScopeRoutes

    var isMandatory: Bool {
        self != .outOfScopeRoutes
    }
}

struct CanonicalTeamCreationCutoverGateFinding: Hashable, Sendable {
    let gateID: CanonicalTeamCreationCutoverGateID
    let status: CanonicalTeamCreationCutoverGateStatus
    let summary: String
    let requiredNextAction: String

    init(
        gateID: CanonicalTeamCreationCutoverGateID,
        status: CanonicalTeamCreationCutoverGateStatus,
        summary: String,
        requiredNextAction: String
    ) {
        self.gateID = gateID
        self.status = status
        self.summary = summary
        self.requiredNextAction = requiredNextAction
    }
}

struct CanonicalTeamCreationCutoverReview: Hashable, Sendable {
    let findings: [CanonicalTeamCreationCutoverGateFinding]
    let boundedScope: Set<String>
    let explicitlyOutOfScopeRoutes: Set<String>
    let legacyWriterReference: String
    let adapterRouted: Bool

    static let current = CanonicalTeamCreationCutoverReview(
        findings: [
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .adapterCorrectness,
                status: .satisfiedForIsolatedTestingOnly,
                summary: "The adapter validates, inserts once, saves once, reloads, verifies, and classifies isolated outcomes, but it rejects production source requests and relies on externally supplied operation evidence.",
                requiredNextAction: "Keep adapter non-routed; add production-route policy and durable operation evidence before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .productionCallSiteCompatibility,
                status: .partiallySatisfied,
                summary: "Named simple team creation maps to identity, name, coach, and details, but production also creates blank editable teams and supports later logo, roster, game, and deletion workflows outside the adapter boundary.",
                requiredNextAction: "Define one bounded simple-team route and exclude blank-edit, import, seed, media, roster, and delete routes."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .dedicatedContext,
                status: .partiallySatisfied,
                summary: "A fresh transaction boundary is feasible in principle, but production currently uses shared environment context values and no routed factory exists for one clean context per submission.",
                requiredNextAction: "Design dedicated transaction-boundary creation and result handoff without returning live stored objects."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .contextCleanliness,
                status: .satisfiedForIsolatedTestingOnly,
                summary: "Dirty incoming state is rejected in isolated tests, but production shared context edits, implicit persistence, and rollback impact are not yet controlled.",
                requiredNextAction: "Require a newly created transaction boundary for every routed request and keep dirty-boundary rejection intact."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .oneWriter,
                status: .partiallySatisfied,
                summary: "The likely routing point is the TeamView plus-button named-team insert; current legacy insert and save remain active and no bypass is implemented.",
                requiredNextAction: "Implement a separate bounded routing task that replaces only that one legacy write with no fallback writer."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .duplicateAndConcurrencySafety,
                status: .notSatisfied,
                summary: "Sequential duplicate checks pass in isolation, but separate simultaneous submissions can race before either save proves the identity exists.",
                requiredNextAction: "Add serialized submission, durable identity policy, and post-save duplicate handling before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .durableIdempotency,
                status: .notSatisfied,
                summary: "Operation identity is request data only and is not preserved across view recreation, app suspension, termination, or uncertain completion retry.",
                requiredNextAction: "Design durable operation evidence or an equivalent cross-launch retry policy before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .schemaReadiness,
                status: .partiallySatisfied,
                summary: "The current Team record can store the accepted team fields, but there is no stored operation evidence and no formal schema-version policy.",
                requiredNextAction: "Decide whether simple routing is no-schema-change and separately resolve operation-evidence storage."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .sourceVersionAndMigrationStateReadiness,
                status: .notSatisfied,
                summary: "Startup can open the current store, but production lacks source-version, migration-progress, unsupported-future, and uncertain-recovery gates for writes.",
                requiredNextAction: "Add source-version and migration-state policy before any routed production write."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .saveCompletionProof,
                status: .partiallySatisfied,
                summary: "Fresh reload proves one matching team identity and supported fields, but without operation evidence it cannot prove which invocation created the record.",
                requiredNextAction: "Keep UI success behind reload proof and add operation-level proof if uncertain completion must be retried."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .disablePath,
                status: .notSatisfied,
                summary: "No production disable mechanism exists; release-level reversion is possible but not an immediate diagnosed route selector.",
                requiredNextAction: "Define a centralized compile-time route choice for the bounded route before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .rollbackAndRecovery,
                status: .partiallySatisfied,
                summary: "Created teams remain readable by legacy code and no schema rollback is needed for record fields, but uncertain completion and route disable recovery are not implemented.",
                requiredNextAction: "Define recovery by identity lookup and route rollback policy; do not use automatic record deletion."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .userReviewPolicy,
                status: .notSatisfied,
                summary: "Adapter outcomes classify conflicts and uncertainty, but production has no mapped user-facing behavior for retry, review, disabled, schema, or migration failures.",
                requiredNextAction: "Design outcome-to-UI policy before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .purchaseAndAllowanceSeparation,
                status: .satisfied,
                summary: "Simple team creation is not allowance-consuming, does not require entitlement, and has no purchase-service or secure-counter side effect in production or adapter evidence.",
                requiredNextAction: "Keep this route independent from game-creation allowance and MLB download allowance."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .diagnosticSufficiency,
                status: .partiallySatisfied,
                summary: "Result values carry useful local classifications, but production cannot yet diagnose writer identity, disable state, durable operation identity, or route-level recovery.",
                requiredNextAction: "Define privacy-preserving local diagnostics before routing."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .testAdequacy,
                status: .partiallySatisfied,
                summary: "The 23 adapter tests cover isolated behavior well, but they do not prove shared-context, cross-launch, production routing, disable, or concurrency behavior.",
                requiredNextAction: "Add focused routing-preparation tests only after the missing policies exist."
            ),
            CanonicalTeamCreationCutoverGateFinding(
                gateID: .outOfScopeRoutes,
                status: .notApplicable,
                summary: "Scoring, correction, import, media, deletion, migration, seed, roster, lineup, player, game, report, export, purchase, and allowance routes are outside this bounded review.",
                requiredNextAction: "Do not broaden the next implementation beyond the named simple-team route."
            )
        ],
        boundedScope: ["simple reusable team creation from TeamView named-team form"],
        explicitlyOutOfScopeRoutes: [
            "scoring",
            "correction",
            "import",
            "media",
            "deletion",
            "migration",
            "seed",
            "roster",
            "lineup",
            "player",
            "game",
            "report",
            "export",
            "purchase",
            "allowance"
        ],
        legacyWriterReference: "TeamView.teamInsertDelete",
        adapterRouted: false
    )

    var verdict: CanonicalTeamCreationCutoverVerdict {
        let mandatoryFindings = findings.filter(\.gateID.isMandatory)
        if mandatoryFindings.contains(where: { $0.status == .unsafe }) {
            return .unsafeForRouting
        }
        if mandatoryFindings.allSatisfy({ !$0.status.blocksProductionReadiness }) {
            return .readyForBoundedRoutingPreparation
        }
        return .blockedPendingSpecificImplementationOrPolicyWork
    }

    var mandatoryGateIDs: Set<CanonicalTeamCreationCutoverGateID> {
        Set(CanonicalTeamCreationCutoverGateID.allCases.filter(\.isMandatory))
    }

    var missingMandatoryGateIDs: Set<CanonicalTeamCreationCutoverGateID> {
        let present = Set(findings.map(\.gateID))
        return mandatoryGateIDs.subtracting(present)
    }

    var orderedBlockers: [CanonicalTeamCreationCutoverGateID] {
        findings
            .filter { $0.gateID.isMandatory && $0.status.blocksProductionReadiness }
            .map(\.gateID)
    }

    func replacingStatus(
        for gateID: CanonicalTeamCreationCutoverGateID,
        with status: CanonicalTeamCreationCutoverGateStatus
    ) -> CanonicalTeamCreationCutoverReview {
        let updatedFindings = findings.map { finding in
            guard finding.gateID == gateID else { return finding }
            return CanonicalTeamCreationCutoverGateFinding(
                gateID: finding.gateID,
                status: status,
                summary: finding.summary,
                requiredNextAction: finding.requiredNextAction
            )
        }
        return CanonicalTeamCreationCutoverReview(
            findings: updatedFindings,
            boundedScope: boundedScope,
            explicitlyOutOfScopeRoutes: explicitlyOutOfScopeRoutes,
            legacyWriterReference: legacyWriterReference,
            adapterRouted: adapterRouted
        )
    }
}
