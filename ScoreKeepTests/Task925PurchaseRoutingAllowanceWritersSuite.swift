import XCTest
@testable import ScoreKeep

final class Task925PurchaseRoutingAllowanceWritersSuite: XCTestCase {
    func testOneAuthoritativePurchaseDecisionPathUsesEntitlementState() {
        let authority = PurchaseDecisionAuthority()

        XCTAssertTrue(authority.decision(for: .entitled).permitsCurrentSeasonAccess)
        XCTAssertFalse(authority.decision(for: .notEntitled).permitsCurrentSeasonAccess)
        XCTAssertFalse(authority.decision(for: .priorSeason).permitsCurrentSeasonAccess)
        XCTAssertFalse(authority.decision(for: .futureSeason).permitsCurrentSeasonAccess)
        XCTAssertFalse(authority.decision(for: .statusUnavailable).permitsCurrentSeasonAccess)
    }

    func testPurchaseGatingPolicyRoutesThroughPhase9EntitlementAuthority() {
        let action = PurchaseGatedAction.scorecardPDF
        let workflow = PurchaseGatedWorkflowState(
            action: action,
            gameIdentity: UUID(),
            teamIdentity: UUID(),
            scopeDescription: "Task 9.25",
            idempotencyKey: "task-925-purchase"
        )

        let entitledDecision = PurchaseGatingPolicy.decide(
            action: action,
            entitlement: EntitlementState.entitled,
            workflow: workflow
        )
        let unavailableDecision = PurchaseGatingPolicy.decide(
            action: action,
            entitlement: EntitlementState.statusUnavailable,
            workflow: workflow
        )

        XCTAssertTrue(entitledDecision.permitsAction)
        XCTAssertFalse(unavailableDecision.permitsAction)
        XCTAssertTrue(unavailableDecision.requiresPaywall)
        XCTAssertEqual(unavailableDecision.pendingWorkflow, workflow)
    }

    func testOneWriterRouteForFreeGameAllowance() {
        let authority = AllowanceWriterRoutingAuthority()

        XCTAssertEqual(
            authority.writerRoute(for: .successfulGameCreation),
            .task922GameCreationTransaction
        )
        XCTAssertNotEqual(
            authority.writerRoute(for: .successfulGameCreation),
            .task923RosterDownloadTransaction
        )
    }

    func testOneWriterRouteForMLBRosterAllowance() {
        let authority = AllowanceWriterRoutingAuthority()

        XCTAssertEqual(
            authority.writerRoute(for: .successfulMLBRosterDownloadImport),
            .task923RosterDownloadTransaction
        )
        XCTAssertNotEqual(
            authority.writerRoute(for: .successfulMLBRosterDownloadImport),
            .task922GameCreationTransaction
        )
    }

    func testRetiredLegacyPathsCannotMutateAllowanceState() {
        let authority = AllowanceWriterRoutingAuthority()

        for action in NonQualifyingAllowanceAction.allCases {
            XCTAssertEqual(authority.legacyMutationDecision(for: action), .retired(action))
        }
    }

    func testExistingValuesArePreservedAndNoProductionResetOccurs() {
        let authority = AllowanceWriterRoutingAuthority()
        let freeGameAllowance = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let mlbAllowance = MLBDownloadAllowanceState(
            usedCount: 2,
            storageInterpretation: .validStored
        )

        XCTAssertEqual(freeGameAllowance.remaining, 1)
        XCTAssertTrue(freeGameAllowance.canCreateWithAllowance)
        XCTAssertEqual(mlbAllowance.usedCount, 2)
        XCTAssertEqual(mlbAllowance.remaining, 2)
        XCTAssertTrue(mlbAllowance.canDownloadWithAllowance)
        XCTAssertEqual(
            authority.resetDecision(buildConfiguration: .release),
            .notPermittedInProduction
        )
    }

    func testTasks922Through924ContinueToWork() {
        var gameTransaction = GameCreationAllowanceTransaction()
        var rosterTransaction = RosterDownloadAllowanceTransaction()
        let gameID = UUID()
        let rosterID = "Detroit Tigers.ScoreKeep_Players"
        let freeGameAllowance = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let mlbAllowance = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )
        let resumePolicy = PaywallResumePolicy()

        XCTAssertEqual(
            gameTransaction.successfulPersistedCreation(gameID: gameID, allowance: freeGameAllowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulGameCreation,
                    idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
                )
            )
        )
        XCTAssertEqual(
            rosterTransaction.successfulDownloadImportBoundary(rosterID: rosterID, allowance: mlbAllowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulMLBRosterDownloadImport,
                    idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: rosterID)
                )
            )
        )
        XCTAssertEqual(
            resumePolicy.decision(for: .gameCreation, isEntitled: true, hasAllowance: false),
            .resume(.gameCreation, .entitlement)
        )
    }
}
