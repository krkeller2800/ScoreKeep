import XCTest
@testable import ScoreKeep

final class Task923RosterDownloadAllowanceTransactionSuite: XCTestCase {
    func testSuccessfulDownloadImportConsumesOneAllowance() {
        var transaction = RosterDownloadAllowanceTransaction()
        let rosterID = "Detroit Tigers.ScoreKeep_Players"
        let allowance = MLBDownloadAllowanceState(
            usedCount: 0,
            storageInterpretation: .validStored
        )

        let result = transaction.successfulDownloadImportBoundary(
            rosterID: rosterID,
            allowance: allowance
        )

        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: rosterID)
        )
        XCTAssertEqual(result, .consume(expectedIdentity))
    }

    func testDuplicateDownloadImportRecognitionConsumesOnlyOnce() {
        var transaction = RosterDownloadAllowanceTransaction()
        let rosterID = "Detroit Tigers.ScoreKeep_Players"
        let allowance = MLBDownloadAllowanceState(
            usedCount: 0,
            storageInterpretation: .validStored
        )
        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: rosterID)
        )

        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: rosterID, allowance: allowance),
            .consume(expectedIdentity)
        )
        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: rosterID, allowance: allowance),
            .duplicate(expectedIdentity)
        )
    }

    func testDistinctRosterDownloadsEachConsumeOnce() {
        var transaction = RosterDownloadAllowanceTransaction()
        let firstRosterID = "Detroit Tigers.ScoreKeep_Players"
        let secondRosterID = "Chicago Cubs.ScoreKeep_Players"
        let allowance = MLBDownloadAllowanceState(
            usedCount: 1,
            storageInterpretation: .validStored
        )

        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: firstRosterID, allowance: allowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulMLBRosterDownloadImport,
                    idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: firstRosterID)
                )
            )
        )
        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: secondRosterID, allowance: allowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulMLBRosterDownloadImport,
                    idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: secondRosterID)
                )
            )
        )
    }

    func testDownloadWithoutSuccessfulImportBoundaryConsumesNoAllowance() {
        let transaction = RosterDownloadAllowanceTransaction()

        XCTAssertEqual(
            transaction.nonQualifying(.downloadOnlyWithoutImportBoundary),
            .notQualifying(.downloadOnlyWithoutImportBoundary)
        )
    }

    func testPreviewCanceledFailedPendingOrBlockedActionsConsumeNoAllowance() {
        let transaction = RosterDownloadAllowanceTransaction()
        let actions: [NonQualifyingAllowanceAction] = [
            .importPreviewOnly,
            .canceled,
            .failed,
            .pending,
            .blockedByAllowance
        ]

        for action in actions {
            XCTAssertEqual(transaction.nonQualifying(action), .notQualifying(action))
        }
    }

    func testExhaustedAllowanceDoesNotConsumeIdentity() {
        var transaction = RosterDownloadAllowanceTransaction()
        let rosterID = "Detroit Tigers.ScoreKeep_Players"
        let exhaustedAllowance = MLBDownloadAllowanceState(
            usedCount: MLBDownloadAllowanceState.freeLimit,
            storageInterpretation: .validStored
        )
        let replenishedAllowance = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )
        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: RosterDownloadAllowanceTransaction.idempotencyKey(for: rosterID)
        )

        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: rosterID, allowance: exhaustedAllowance),
            .noAllowanceRemaining(expectedIdentity)
        )
        XCTAssertEqual(
            transaction.successfulDownloadImportBoundary(rosterID: rosterID, allowance: replenishedAllowance),
            .consume(expectedIdentity)
        )
    }

    func testTask919ThroughTask922RegressionsRemainUnchanged() {
        let mlbDownloadState = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )
        let freeGameState = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        var gameTransaction = GameCreationAllowanceTransaction()
        let gameID = UUID()
        let gameIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
        )

        XCTAssertTrue(mlbDownloadState.canDownloadWithAllowance)
        XCTAssertEqual(mlbDownloadState.displayText, "Downloads remaining: 1 of 4")
        XCTAssertTrue(freeGameState.canCreateWithAllowance)
        XCTAssertEqual(
            QualifyingAllowanceAction.successfulMLBRosterDownloadImport.counterKey,
            MLBDownloadAllowanceState.counterKey
        )
        XCTAssertEqual(
            gameTransaction.successfulPersistedCreation(gameID: gameID, allowance: freeGameState),
            .consume(gameIdentity)
        )
        XCTAssertEqual(
            gameTransaction.successfulPersistedCreation(gameID: gameID, allowance: freeGameState),
            .duplicate(gameIdentity)
        )
    }
}
