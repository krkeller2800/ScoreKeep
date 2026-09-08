import Foundation
import Testing
@testable import ScoreKeep

@Suite("Team creation cutover-gate review")
struct CanonicalTeamCreationCutoverGateReviewTests {
    @Test("every mandatory gate appears in the review")
    func everyMandatoryGateAppearsInReview() {
        let review = CanonicalTeamCreationCutoverReview.current

        #expect(review.missingMandatoryGateIDs.isEmpty)
        #expect(review.findings.filter(\.gateID.isMandatory).count == review.mandatoryGateIDs.count)
    }

    @Test("unresolved mandatory gates do not permit a ready verdict")
    func unresolvedMandatoryGatesDoNotPermitReadyVerdict() {
        let review = CanonicalTeamCreationCutoverReview.current

        #expect(review.verdict == .blockedPendingSpecificImplementationOrPolicyWork)
        #expect(review.orderedBlockers.isEmpty == false)
        #expect(review.orderedBlockers.contains(.durableIdempotency))
        #expect(review.orderedBlockers.contains(.disablePath))
        #expect(review.orderedBlockers.contains(.userReviewPolicy))
    }

    @Test("isolated testing only status blocks production readiness")
    func isolatedTestingOnlyStatusBlocksProductionReadiness() {
        let review = allSatisfiedReview().replacingStatus(for: .adapterCorrectness, with: .satisfiedForIsolatedTestingOnly)

        #expect(CanonicalTeamCreationCutoverGateStatus.satisfiedForIsolatedTestingOnly.blocksProductionReadiness)
        #expect(review.verdict == .blockedPendingSpecificImplementationOrPolicyWork)
    }

    @Test("unsafe status blocks readiness")
    func unsafeStatusBlocksReadiness() {
        let review = allSatisfiedReview().replacingStatus(for: .oneWriter, with: .unsafe)

        #expect(CanonicalTeamCreationCutoverGateStatus.unsafe.blocksProductionReadiness)
        #expect(review.verdict == .unsafeForRouting)
    }

    @Test("unknown status blocks readiness")
    func unknownStatusBlocksReadiness() {
        let review = allSatisfiedReview().replacingStatus(for: .sourceVersionAndMigrationStateReadiness, with: .unknown)

        #expect(CanonicalTeamCreationCutoverGateStatus.unknown.blocksProductionReadiness)
        #expect(review.verdict == .blockedPendingSpecificImplementationOrPolicyWork)
    }

    @Test("non mandatory gates are explicitly identified")
    func nonMandatoryGatesAreExplicitlyIdentified() throws {
        let review = CanonicalTeamCreationCutoverReview.current
        let outOfScope = try #require(review.findings.first { $0.gateID == .outOfScopeRoutes })

        #expect(outOfScope.gateID.isMandatory == false)
        #expect(outOfScope.status == .notApplicable)
        #expect(CanonicalTeamCreationCutoverGateID.allCases.filter { !$0.isMandatory } == [.outOfScopeRoutes])
    }

    @Test("scoring correction import media deletion migration and seed routes remain outside bounded review")
    func highRiskRoutesRemainOutsideBoundedReview() {
        let outOfScope = CanonicalTeamCreationCutoverReview.current.explicitlyOutOfScopeRoutes

        #expect(outOfScope.contains("scoring"))
        #expect(outOfScope.contains("correction"))
        #expect(outOfScope.contains("import"))
        #expect(outOfScope.contains("media"))
        #expect(outOfScope.contains("deletion"))
        #expect(outOfScope.contains("migration"))
        #expect(outOfScope.contains("seed"))
        #expect(CanonicalTeamCreationCutoverReview.current.boundedScope == ["simple reusable team creation from TeamView named-team form"])
    }

    @Test("team view creation uses standard draft route")
    func teamViewCreationUsesStandardDraftRoute() throws {
        let route = CanonicalPersistenceCutoverRouteManifest.route(for: .teamCreationAndEditing)
        let teamView = try source(named: "ScoreKeep/List Data/TeamView.swift")
        let teamContentView = try source(named: "ScoreKeep/Content Views/TeamContentView.swift")

        #expect(CanonicalTeamCreationCutoverReview.current.legacyWriterReference == "TeamView.teamInsertDelete")
        #expect(route.currentAuthority == .legacySwiftData)
        #expect(route.activeProductionWriterCount == 1)
        #expect(teamView.contains("modelContext.insert(theTeam)") == false)
        #expect(teamContentView.contains("AddTeamDraftView"))
    }

    @Test("converted production views route through add team draft")
    func convertedProductionViewsRouteThroughAddTeamDraft() throws {
        let review = CanonicalTeamCreationCutoverReview.current
        let teamView = try source(named: "ScoreKeep/List Data/TeamView.swift")
        let contentView = try source(named: "ScoreKeep/Content Views/ContentView.swift")
        let teamContentView = try source(named: "ScoreKeep/Content Views/TeamContentView.swift")
        let editGameView = try source(named: "ScoreKeep/Edit Data/EditGameView.swift")
        let pasteView = try source(named: "ScoreKeep/Player org/PasteView.swift")
        let draftView = try source(named: "ScoreKeep/Common/AddTeamDraftView.swift")
        let scoreContentView = try source(named: "ScoreKeep/Content Views/ScoreContentView.swift")
        let productionSources = [teamView, contentView, teamContentView, scoreContentView, editGameView, pasteView, draftView]

        #expect(review.adapterRouted == false)
        #expect([contentView, teamContentView, editGameView, pasteView].allSatisfy { $0.contains("AddTeamDraftView") })
        #expect(scoreContentView.contains("AddTeamDraftView") == false)
        #expect(productionSources.allSatisfy { !$0.contains("CanonicalTeamCreationTransactionAdapter") })
        #expect(productionSources.allSatisfy { !$0.contains("CanonicalTeamCreationRequest(") })
    }

    @Test("review evaluation is deterministic")
    func reviewEvaluationIsDeterministic() {
        let first = CanonicalTeamCreationCutoverReview.current
        let second = CanonicalTeamCreationCutoverReview.current

        #expect(first == second)
        #expect(first.verdict == second.verdict)
        #expect(first.orderedBlockers == second.orderedBlockers)
    }

    @Test("review inputs remain unchanged by evaluation")
    func reviewInputsRemainUnchangedByEvaluation() {
        let review = CanonicalTeamCreationCutoverReview.current
        let findings = review.findings
        let scope = review.boundedScope
        let outOfScope = review.explicitlyOutOfScopeRoutes
        _ = review.verdict
        _ = review.orderedBlockers

        #expect(review.findings == findings)
        #expect(review.boundedScope == scope)
        #expect(review.explicitlyOutOfScopeRoutes == outOfScope)
    }

    @Test("pure review logic has no persistence purchase or secure storage dependency")
    func pureReviewLogicHasNoForbiddenDependency() throws {
        let source = try source(named: "ScoreKeep/Common/CanonicalTeamCreationCutoverReview.swift")
        let forbiddenTokens = ["ModelContext", "ModelContainer", "SwiftData", "FetchDescriptor", ".save(", ".insert(", ".delete(", "@Model", "StoreKit", "Keychain"]

        #expect(source.contains("import Foundation"))
        #expect(forbiddenTokens.allSatisfy { !source.contains($0) })
    }

    @Test("final verdict matches documented gate statuses")
    func finalVerdictMatchesDocumentedGateStatuses() throws {
        let review = CanonicalTeamCreationCutoverReview.current
        let document = try source(named: "ScoreKeep/Docs/Verification/TeamCreationAdapterCutoverGateReview.md")

        #expect(review.verdict == .blockedPendingSpecificImplementationOrPolicyWork)
        #expect(document.contains("Overall verdict: Blocked pending specific implementation or policy work."))
        #expect(document.contains("Adapter correctness: Satisfied for isolated testing only."))
        #expect(document.contains("Durable or otherwise proven idempotency: Not satisfied."))
        #expect(document.contains("Purchase and allowance separation: Satisfied."))
        #expect(document.contains("Routing remains disabled."))
    }

    private func allSatisfiedReview() -> CanonicalTeamCreationCutoverReview {
        let base = CanonicalTeamCreationCutoverReview.current
        let findings = base.findings.map { finding in
            CanonicalTeamCreationCutoverGateFinding(
                gateID: finding.gateID,
                status: finding.gateID.isMandatory ? .satisfied : finding.status,
                summary: finding.summary,
                requiredNextAction: finding.requiredNextAction
            )
        }
        return CanonicalTeamCreationCutoverReview(
            findings: findings,
            boundedScope: base.boundedScope,
            explicitlyOutOfScopeRoutes: base.explicitlyOutOfScopeRoutes,
            legacyWriterReference: base.legacyWriterReference,
            adapterRouted: base.adapterRouted
        )
    }

    private func source(named relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }
}

enum TeamCreationCutoverGateReviewTestError: Error {
    case repositoryRootNotFound
}
