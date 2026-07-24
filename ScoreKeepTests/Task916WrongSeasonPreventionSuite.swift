import XCTest
@testable import ScoreKeep

@MainActor
final class Task916WrongSeasonPreventionSuite: XCTestCase {
    private let keychain = KeychainService()
    private let entitlementKey = "seasonPassMaxExpirationISO8601"

    override func setUp() {
        super.setUp()
        try? keychain.delete(entitlementKey)
    }

    override func tearDown() {
        try? keychain.delete(entitlementKey)
        super.tearDown()
    }

    func testCurrentSeasonRecoveryStillGrantsEntitlement() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2025",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.completeVerifiedRecovery(productID: "com.komakode.ScoreKeep.SeasonPass2025")

        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
        XCTAssertNil(manager.lastErrorMessage)
    }

    func testPriorSeasonRecoveryNeverGrantsCurrentEntitlement() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2025",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1780272000) } // Jun 1, 2026
        )

        await manager.completeVerifiedRecovery(productID: "com.komakode.ScoreKeep.SeasonPass2025")

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .priorSeason)
        XCTAssertNil(manager.lastErrorMessage)
    }

    func testFutureSeasonRecoveryNeverStoresCurrentEntitlement() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2026",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.completeVerifiedRecovery(productID: "com.komakode.ScoreKeep.SeasonPass2026")

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .futureSeason)
        XCTAssertEqual(manager.lastErrorMessage, "This purchase is not valid for the current ScoreKeep season.")
    }

    func testUnrelatedProductWithCurrentYearSuffixNeverGrantsEntitlement() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.example.OtherProduct2025",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        manager.isPurchasePending = true
        manager.isPurchaseFailed = true
        manager.isPurchaseCancelled = true

        await manager.completeVerifiedRecovery(productID: "com.example.OtherProduct2025")

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .notEntitled)
        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseFailed)
        XCTAssertFalse(manager.isPurchaseCancelled)
        XCTAssertEqual(manager.lastErrorMessage, "This purchase is not valid for the current ScoreKeep season.")
    }

    func testMalformedSeasonProductNeverGrantsEntitlement() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass20A5",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.completeVerifiedRecovery(productID: "com.komakode.ScoreKeep.SeasonPass20A5")

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .notEntitled)
        XCTAssertEqual(manager.lastErrorMessage, "This purchase is not valid for the current ScoreKeep season.")
    }

    func testRestoreBehaviorRemainsCorrectForCurrentSeason() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2025",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            restoreAction: { }
        )

        await manager.restore()

        XCTAssertTrue(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }

    func testPendingRecoveryBehaviorRemainsUnchangedForCurrentSeason() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2025",
                isVerified: true,
                isRevoked: false
            )
        ]

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        manager.isPurchasePending = true
        manager.isPurchaseFailed = true
        manager.isPurchaseCancelled = true

        await manager.completeVerifiedRecovery(productID: "com.komakode.ScoreKeep.SeasonPass2025")

        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseFailed)
        XCTAssertFalse(manager.isPurchaseCancelled)
        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }

    func testOfflineKnownBehaviorRemainsUnchanged() async {
        let formatter = ISO8601DateFormatter()
        let maxDate = Date(timeIntervalSince1970: 1767225599) // Dec 31, 2025
        if let data = formatter.string(from: maxDate).data(using: .utf8) {
            try? keychain.set(data, for: entitlementKey)
        }

        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = []

        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }
}
