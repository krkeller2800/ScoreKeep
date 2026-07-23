import Foundation
import Testing
@testable import ScoreKeep

@Suite("Task 8.14 Generated-Output and Source-Export Routing Suite")
struct Task814GeneratedOutputSourceExportRoutingSuite {
    @Test("Compatible source-data export request resolves to source-export route")
    func compatibleSourceDataExportRequestResolvesToSourceExportRoute() {
        let route = CompatibleSourceDataExportRoute(kind: .players, fileBaseName: "Roster")

        #expect(route.authority == .compatibleSourceDataExport)
        #expect(route.purchaseGatedAction == .compatibleSourceDataExport)
    }

    @Test("Generated scorecard PDF request resolves to generated-output route")
    func generatedScorecardPDFRequestResolvesToGeneratedOutputRoute() throws {
        let route = try generatedRoute(for: .singleGameScorecard)

        #expect(route.authority == .generatedOutput)
        #expect(route.kind == .scorecardPDF)
        #expect(route.purchaseGatedAction == .scorecardPDF)
    }

    @Test("Hitting-statistics output resolves to generated-output route")
    func hittingStatisticsOutputResolvesToGeneratedOutputRoute() throws {
        let route = try generatedRoute(for: .hittingStatistics)

        #expect(route.authority == .generatedOutput)
        #expect(route.kind == .hittingStatistics)
        #expect(route.purchaseGatedAction == .hittingStatistics)
    }

    @Test("Pitching-statistics output resolves to generated-output route")
    func pitchingStatisticsOutputResolvesToGeneratedOutputRoute() throws {
        let route = try generatedRoute(for: .pitchingStatistics)

        #expect(route.authority == .generatedOutput)
        #expect(route.kind == .pitchingStatistics)
        #expect(route.purchaseGatedAction == .pitchingStatistics)
    }

    @Test("Source-data export is never classified as generated output")
    func sourceDataExportIsNeverClassifiedAsGeneratedOutput() {
        let routes = [
            CompatibleSourceDataExportRoute(kind: .players, fileBaseName: "Roster"),
            CompatibleSourceDataExportRoute(kind: .game, fileBaseName: "Game")
        ]

        for route in routes {
            #expect(route.authority != .generatedOutput)
            #expect(!route.requiresGeneratedOutputPurchaseGate)
        }
    }

    @Test("Generated output is never classified as compatible source data")
    func generatedOutputIsNeverClassifiedAsCompatibleSourceData() throws {
        for family in generatedFamilies {
            let route = try generatedRoute(for: family)

            #expect(route.authority != .compatibleSourceDataExport)
            #expect(route.purchaseGatedAction != .compatibleSourceDataExport)
        }
    }

    @Test("Source-data export does not require generated-output purchase gate")
    func sourceDataExportDoesNotRequireGeneratedOutputPurchaseGate() {
        let route = CompatibleSourceDataExportRoute(kind: .game, fileBaseName: "Visitors at Home")
        let decision = PurchaseGatingPolicy.decide(
            action: route.purchaseGatedAction,
            entitlement: .inactive,
            workflow: workflowState(for: route.purchaseGatedAction)
        )

        #expect(!route.requiresGeneratedOutputPurchaseGate)
        #expect(decision.disposition == .proceed(.sourceDataOwnership))
        #expect(decision.pendingWorkflow == nil)
    }

    @Test("Generated output retains existing purchase-gating classification")
    func generatedOutputRetainsExistingPurchaseGatingClassification() throws {
        for family in generatedFamilies {
            let route = try generatedRoute(for: family)
            let workflow = workflowState(for: route.purchaseGatedAction)
            let decision = PurchaseGatingPolicy.decide(
                action: route.purchaseGatedAction,
                entitlement: .inactive,
                workflow: workflow
            )

            #expect(route.requiresGeneratedOutputPurchaseGate)
            #expect(decision.disposition == .requiresPaywall)
            #expect(decision.pendingWorkflow == workflow)
        }
    }

    @Test("Route selection is deterministic when repeated")
    func routeSelectionIsDeterministicWhenRepeated() throws {
        let sourceRoute = CompatibleSourceDataExportRoute(kind: .players, fileBaseName: "Roster")
        let repeatedSourceRoute = CompatibleSourceDataExportRoute(kind: .players, fileBaseName: "Roster")
        let generatedRoute = try generatedRoute(for: .hittingStatistics)
        let repeatedGeneratedRoute = try self.generatedRoute(for: .hittingStatistics)

        #expect(sourceRoute == repeatedSourceRoute)
        #expect(generatedRoute == repeatedGeneratedRoute)
    }

    @Test("Each route preserves payload or destination identity")
    func eachRoutePreservesPayloadOrDestinationIdentity() throws {
        let teamID = UUID(uuidString: "81400000-0000-0000-0000-000000000001")!
        let gameID = UUID(uuidString: "81400000-0000-0000-0000-000000000002")!
        let sourceRoute = CompatibleSourceDataExportRoute(kind: .game, fileBaseName: "Visitors at Home on Jul 23, 2026")
        let generatedRoute = try generatedRoute(
            for: .singleGameScorecard,
            scope: .singleGame(teamID: teamID, gameID: gameID)
        )

        #expect(sourceRoute.fileName == "Visitors at Home on Jul 23, 2026.ScoreKeep_Games")
        #expect(generatedRoute.scope == .singleGame(teamID: teamID, gameID: gameID))
    }

    @Test("Existing export file naming and type identity remain unchanged")
    func existingExportFileNamingAndTypeIdentityRemainUnchanged() {
        let playersRoute = CompatibleSourceDataExportRoute(kind: .players, fileBaseName: "Team Name")
        let gameRoute = CompatibleSourceDataExportRoute(kind: .game, fileBaseName: "Visitors at Home")

        #expect(CompatibleSourceDataExportKind.players.fileExtension == "ScoreKeep_Players")
        #expect(CompatibleSourceDataExportKind.game.fileExtension == "ScoreKeep_Games")
        #expect(playersRoute.fileName == "Team Name.ScoreKeep_Players")
        #expect(gameRoute.fileName == "Visitors at Home.ScoreKeep_Games")
    }

    @Test("Existing report routing remains unchanged")
    func existingReportRoutingRemainsUnchanged() throws {
        let hitting = try generatedRoute(for: .hittingStatistics)
        let pitching = try generatedRoute(for: .pitchingStatistics)
        let scorecard = try generatedRoute(for: .singleGameScorecard)

        #expect(hitting.kind == .hittingStatistics)
        #expect(pitching.kind == .pitchingStatistics)
        #expect(scorecard.kind == .scorecardPDF)
        #expect(hitting.scope == .teamAggregate(teamID: teamID))
        #expect(pitching.scope == .teamAggregate(teamID: teamID))
        #expect(scorecard.scope == .singleGame(teamID: teamID, gameID: gameID))
    }

    private var generatedFamilies: [ReportFamily] {
        [.singleGameScorecard, .hittingStatistics, .pitchingStatistics]
    }

    private var teamID: UUID {
        UUID(uuidString: "81400000-0000-0000-0000-0000000000AA")!
    }

    private var gameID: UUID {
        UUID(uuidString: "81400000-0000-0000-0000-0000000000BB")!
    }

    private func generatedRoute(
        for family: ReportFamily,
        scope suppliedScope: PreparedReportScope? = nil
    ) throws -> GeneratedOutputRoute {
        let scope = suppliedScope ?? defaultScope(for: family)
        let document = try preparedDocument(family: family, scope: scope)
        return try #require(GeneratedOutputRoute(document: document))
    }

    private func preparedDocument(family: ReportFamily, scope: PreparedReportScope) throws -> CanonicalPDFDocument {
        let result: Result<CanonicalPDFDocument, CanonicalPDFDocumentError>

        switch family {
        case .hittingStatistics:
            result = CanonicalPDFDocumentPreparer.prepare(
                family: family,
                scope: scope,
                source: .hitting(CanonicalHittingProjectionResult(disposition: .resolved, playerStatistics: [:], diagnostics: [], validationFindings: []))
            )
        case .pitchingStatistics:
            result = CanonicalPDFDocumentPreparer.prepare(
                family: family,
                scope: scope,
                source: .pitching(CanonicalPitchingStatisticsProjectionResult(disposition: .resolved, pitcherStatistics: [:], diagnostics: [], validationFindings: []))
            )
        case .singleGameScorecard:
            result = CanonicalPDFDocumentPreparer.prepare(
                family: family,
                scope: scope,
                source: .scorecard(CanonicalScorecardProjectionResult(disposition: .resolved, events: [], diagnostics: [], replayMayContinue: true))
            )
        }

        return try #require(try? result.get())
    }

    private func defaultScope(for family: ReportFamily) -> PreparedReportScope {
        switch family {
        case .hittingStatistics, .pitchingStatistics:
            .teamAggregate(teamID: teamID)
        case .singleGameScorecard:
            .singleGame(teamID: teamID, gameID: gameID)
        }
    }

    private func workflowState(for action: PurchaseGatedAction) -> PurchaseGatedWorkflowState {
        PurchaseGatedWorkflowState(
            action: action,
            gameIdentity: gameID,
            teamIdentity: teamID,
            scopeDescription: "Task 8.14 route separation scope",
            idempotencyKey: "task-814-\(action.rawValue)"
        )
    }
}
