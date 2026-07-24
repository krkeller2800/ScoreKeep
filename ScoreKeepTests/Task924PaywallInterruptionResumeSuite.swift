import XCTest
@testable import ScoreKeep

final class Task924PaywallInterruptionResumeSuite: XCTestCase {
    func testInterruptedWorkflowResumesAfterEntitlementPurchase() {
        let policy = PaywallResumePolicy()

        XCTAssertEqual(
            policy.decision(
                for: .gameCreation,
                isEntitled: true,
                hasAllowance: false
            ),
            .resume(.gameCreation, .entitlement)
        )
    }

    func testInterruptedWorkflowResumesAfterAllowancePath() {
        let policy = PaywallResumePolicy()
        let workflow = PaywallInterruptedWorkflow.rosterDownloadImport(rosterID: "Detroit Tigers.ScoreKeep_Players")

        XCTAssertEqual(
            policy.decision(
                for: workflow,
                isEntitled: false,
                hasAllowance: true
            ),
            .resume(workflow, .allowance)
        )
    }

    func testEntitlementAndAllowanceAreRevalidatedBeforeCompletion() {
        let policy = PaywallResumePolicy()
        let workflow = PaywallInterruptedWorkflow.gameCreation

        XCTAssertEqual(
            policy.decision(for: workflow, isEntitled: false, hasAllowance: false),
            .blocked(workflow)
        )
        XCTAssertEqual(
            policy.decision(for: workflow, isEntitled: true, hasAllowance: false),
            .resume(workflow, .entitlement)
        )
        XCTAssertEqual(
            policy.decision(for: workflow, isEntitled: false, hasAllowance: true),
            .resume(workflow, .allowance)
        )
    }

    func testInterruptionCancellationLeavesNoSideEffects() {
        let policy = PaywallResumePolicy()
        let workflow = PaywallInterruptedWorkflow.gameCreation
        let gameTransaction = GameCreationAllowanceTransaction()
        let rosterTransaction = RosterDownloadAllowanceTransaction()

        XCTAssertEqual(policy.cancellation(for: workflow), .canceled(workflow))
        XCTAssertEqual(gameTransaction.nonQualifying(.canceled), .notQualifying(.canceled))
        XCTAssertEqual(rosterTransaction.nonQualifying(.canceled), .notQualifying(.canceled))
    }

    func testTask922AndTask923AllowanceTransactionsRemainAuthoritative() {
        var gameTransaction = GameCreationAllowanceTransaction()
        var rosterTransaction = RosterDownloadAllowanceTransaction()
        let gameID = UUID()
        let rosterID = "Detroit Tigers.ScoreKeep_Players"
        let freeGameAllowance = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let rosterAllowance = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )

        XCTAssertEqual(
            gameTransaction.successfulPersistedCreation(
                gameID: gameID,
                allowance: freeGameAllowance
            ),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulGameCreation,
                    idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
                )
            )
        )
        XCTAssertEqual(
            rosterTransaction.successfulDownloadImportBoundary(
                rosterID: rosterID,
                allowance: rosterAllowance
            ),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulMLBRosterDownloadImport,
                    idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: rosterID)
                )
            )
        )
    }
}
