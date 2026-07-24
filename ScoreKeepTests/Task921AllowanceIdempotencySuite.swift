import XCTest
@testable import ScoreKeep

final class Task921AllowanceIdempotencySuite: XCTestCase {
    func testRepeatedQualifyingGameCreateConsumesAtMostOnce() {
        var register = AllowanceIdempotencyRegister()
        let identity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "game-create:game-1"
        )

        XCTAssertEqual(register.recognize(identity), .consume(identity))
        XCTAssertEqual(register.recognize(identity), .duplicate(identity))
        XCTAssertEqual(register.recognize(identity), .duplicate(identity))
    }

    func testRepeatedQualifyingMLBDownloadImportConsumesAtMostOnce() {
        var register = AllowanceIdempotencyRegister()
        let identity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: "mlb-download-import:tigers"
        )

        XCTAssertEqual(register.recognize(identity), .consume(identity))
        XCTAssertEqual(register.recognize(identity), .duplicate(identity))
    }

    func testDistinctQualifyingActionsCanEachConsumeOnce() {
        var register = AllowanceIdempotencyRegister()
        let gameIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "shared-operation"
        )
        let downloadIdentity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: "shared-operation"
        )

        XCTAssertEqual(register.recognize(gameIdentity), .consume(gameIdentity))
        XCTAssertEqual(register.recognize(downloadIdentity), .consume(downloadIdentity))
        XCTAssertEqual(register.recognize(gameIdentity), .duplicate(gameIdentity))
        XCTAssertEqual(register.recognize(downloadIdentity), .duplicate(downloadIdentity))
    }

    func testDistinctKeysForSameQualifyingActionCanEachConsumeOnce() {
        var register = AllowanceIdempotencyRegister()
        let first = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "game-create:game-1"
        )
        let second = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "game-create:game-2"
        )

        XCTAssertEqual(register.recognize(first), .consume(first))
        XCTAssertEqual(register.recognize(second), .consume(second))
        XCTAssertEqual(register.recognize(first), .duplicate(first))
        XCTAssertEqual(register.recognize(second), .duplicate(second))
    }

    func testNonQualifyingActionsDoNotCreateConsumptionIdentity() {
        let register = AllowanceIdempotencyRegister()

        for action in NonQualifyingAllowanceAction.allCases {
            XCTAssertEqual(register.recognize(action), .notQualifying(action))
        }
    }

    func testConsumptionIdentityCarriesTask920AllowanceMetadata() {
        let gameIdentity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: "game-create:game-1"
        )
        let downloadIdentity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: "mlb-download-import:tigers"
        )

        XCTAssertEqual(gameIdentity.allowanceKind, .freeGameCreation)
        XCTAssertEqual(gameIdentity.counterKey, FreeGameAllowanceState.counterKey)
        XCTAssertEqual(downloadIdentity.allowanceKind, .mlbRosterDownload)
        XCTAssertEqual(downloadIdentity.counterKey, MLBDownloadAllowanceState.counterKey)
    }

    func testTask918AndTask919AllowanceStateRegressionsRemainUnchanged() {
        let freeGameState = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )
        let mlbDownloadState = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )

        XCTAssertTrue(freeGameState.canCreateWithAllowance)
        XCTAssertEqual(freeGameState.displayText, "Free games: 1")
        XCTAssertTrue(mlbDownloadState.canDownloadWithAllowance)
        XCTAssertEqual(mlbDownloadState.displayText, "Downloads remaining: 1 of 4")
    }
}
