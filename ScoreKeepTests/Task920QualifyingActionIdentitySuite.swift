import XCTest
@testable import ScoreKeep

final class Task920QualifyingActionIdentitySuite: XCTestCase {
    func testQualifyingGameCreationIdentityUsesFreeGameAllowance() {
        let action = QualifyingAllowanceAction.successfulGameCreation

        XCTAssertEqual(action.allowanceKind, .freeGameCreation)
        XCTAssertEqual(action.counterKey, FreeGameAllowanceState.counterKey)
        XCTAssertNotEqual(action.counterKey, MLBDownloadAllowanceState.counterKey)
    }

    func testQualifyingMLBDownloadImportIdentityUsesMLBDownloadAllowance() {
        let action = QualifyingAllowanceAction.successfulMLBRosterDownloadImport

        XCTAssertEqual(action.allowanceKind, .mlbRosterDownload)
        XCTAssertEqual(action.counterKey, MLBDownloadAllowanceState.counterKey)
        XCTAssertNotEqual(action.counterKey, FreeGameAllowanceState.counterKey)
    }

    func testQualifyingAllowanceTypesRemainSeparated() {
        XCTAssertEqual(
            QualifyingAllowanceAction.allCases,
            [.successfulGameCreation, .successfulMLBRosterDownloadImport]
        )
        XCTAssertNotEqual(
            QualifyingAllowanceAction.successfulGameCreation.allowanceKind,
            QualifyingAllowanceAction.successfulMLBRosterDownloadImport.allowanceKind
        )
        XCTAssertNotEqual(
            QualifyingAllowanceAction.successfulGameCreation.counterKey,
            QualifyingAllowanceAction.successfulMLBRosterDownloadImport.counterKey
        )
    }

    func testNonQualifyingActionsDoNotDeclareAllowanceConsumptionIdentity() {
        XCTAssertEqual(NonQualifyingAllowanceAction.allCases, [
            .premiumAccess,
            .seededGameCreation,
            .blockedByAllowance,
            .canceled,
            .failed,
            .pending,
            .downloadOnlyWithoutImportBoundary,
            .importPreviewOnly
        ])
        XCTAssertEqual(NonQualifyingAllowanceAction.allCases.count, 8)
    }

    func testTask918FreeGameAllowanceStateRemainsAuthoritativeForGameCreation() {
        let state = FreeGameAllowanceState(
            remaining: 1,
            storageInterpretation: .validStored
        )

        XCTAssertTrue(state.canCreateWithAllowance)
        XCTAssertEqual(state.displayText, "Free games: 1")
        XCTAssertEqual(
            QualifyingAllowanceAction.successfulGameCreation.counterKey,
            FreeGameAllowanceState.counterKey
        )
    }

    func testTask919MLBDownloadAllowanceStateRemainsAuthoritativeForRosterDownloads() {
        let state = MLBDownloadAllowanceState(
            usedCount: 3,
            storageInterpretation: .validStored
        )

        XCTAssertEqual(state.remaining, 1)
        XCTAssertTrue(state.canDownloadWithAllowance)
        XCTAssertEqual(state.displayText, "Downloads remaining: 1 of 4")
        XCTAssertEqual(
            QualifyingAllowanceAction.successfulMLBRosterDownloadImport.counterKey,
            MLBDownloadAllowanceState.counterKey
        )
    }

    func testInvalidMLBDownloadStateRemainsBlockingRegression() {
        let state = MLBDownloadAllowanceState(
            usedCount: MLBDownloadAllowanceState.invalidStoredUsedCount,
            storageInterpretation: .invalidStored
        )

        XCTAssertEqual(state.remaining, 0)
        XCTAssertFalse(state.canDownloadWithAllowance)
    }
}
