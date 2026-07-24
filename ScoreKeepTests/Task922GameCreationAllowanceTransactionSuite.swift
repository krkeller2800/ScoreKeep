import XCTest
@testable import ScoreKeep

final class Task922GameCreationAllowanceTransactionSuite: XCTestCase {
    func testSuccessfulGameCreationConsumesOneAllowance() {
        var transaction = GameCreationAllowanceTransaction()
        let gameID = UUID()
        let allowance = FreeGameAllowanceState(
            remaining: 2,
            storageInterpretation: .validStored
        )

        let result = transaction.successfulPersistedCreation(
            gameID: gameID,
            allowance: allowance
        )

        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
        )
        XCTAssertEqual(result, .consume(expectedIdentity))
    }

    func testDuplicateGameCreationRecognitionConsumesOnlyOnce() {
        var transaction = GameCreationAllowanceTransaction()
        let gameID = UUID()
        let allowance = FreeGameAllowanceState(
            remaining: 2,
            storageInterpretation: .validStored
        )
        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
        )

        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: gameID, allowance: allowance),
            .consume(expectedIdentity)
        )
        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: gameID, allowance: allowance),
            .duplicate(expectedIdentity)
        )
    }

    func testDistinctCreatedGamesEachConsumeOnce() {
        var transaction = GameCreationAllowanceTransaction()
        let firstGameID = UUID()
        let secondGameID = UUID()
        let allowance = FreeGameAllowanceState(
            remaining: 2,
            storageInterpretation: .validStored
        )

        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: firstGameID, allowance: allowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulGameCreation,
                    idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: firstGameID)
                )
            )
        )
        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: secondGameID, allowance: allowance),
            .consume(
                AllowanceConsumptionIdentity(
                    action: .successfulGameCreation,
                    idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: secondGameID)
                )
            )
        )
    }

    func testNoAllowanceRemainingDoesNotConsumeIdentity() {
        var transaction = GameCreationAllowanceTransaction()
        let gameID = UUID()
        let exhaustedAllowance = FreeGameAllowanceState(
            remaining: 0,
            storageInterpretation: .validStored
        )
        let replenishedAllowance = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let expectedIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: GameCreationAllowanceTransaction.idempotencyKey(for: gameID)
        )

        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: gameID, allowance: exhaustedAllowance),
            .noAllowanceRemaining(expectedIdentity)
        )
        XCTAssertEqual(
            transaction.successfulPersistedCreation(gameID: gameID, allowance: replenishedAllowance),
            .consume(expectedIdentity)
        )
    }

    func testFailedOrCanceledCreationConsumesNoAllowance() {
        let transaction = GameCreationAllowanceTransaction()

        XCTAssertEqual(transaction.nonQualifying(.failed), .notQualifying(.failed))
        XCTAssertEqual(transaction.nonQualifying(.canceled), .notQualifying(.canceled))
    }

    func testNonQualifyingActionsConsumeNoAllowance() {
        let transaction = GameCreationAllowanceTransaction()

        for action in NonQualifyingAllowanceAction.allCases {
            XCTAssertEqual(transaction.nonQualifying(action), .notQualifying(action))
        }
    }

    func testTask918ThroughTask921RegressionsRemainUnchanged() {
        let freeGameState = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let mlbDownloadState = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )
        var idempotencyRegister = AllowanceIdempotencyRegister()
        let identity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "game-create:regression"
        )

        XCTAssertTrue(freeGameState.canCreateWithAllowance)
        XCTAssertEqual(QualifyingAllowanceAction.successfulGameCreation.counterKey, FreeGameAllowanceState.counterKey)
        XCTAssertTrue(mlbDownloadState.canDownloadWithAllowance)
        XCTAssertEqual(
            QualifyingAllowanceAction.successfulMLBRosterDownloadImport.counterKey,
            MLBDownloadAllowanceState.counterKey
        )
        XCTAssertEqual(idempotencyRegister.recognize(identity), .consume(identity))
        XCTAssertEqual(idempotencyRegister.recognize(identity), .duplicate(identity))
    }
}
