import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task914PurchaseLifecycleRecoverySuite: XCTestCase {
    
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
    
    func testTransientStateCleanupOnNewPurchaseWorkflow() async {
        let catalogFetcher = MockProductCatalogFetcher()
        catalogFetcher.productsToReturn = [
            MockProduct(id: "com.komakode.ScoreKeep.SeasonPass2025", displayName: "Pass", displayPrice: "$1", description: "Pass")
        ]
        
        let manager = PurchaseManager(
            entitlementFetcher: SpyEntitlementFetcher(),
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return .pending }
        )
        
        await manager.loadProducts()
        
        // Artificially dirty the transient states
        manager.isRestoreSuccessful = true
        manager.isPurchaseFailed = true
        manager.isPurchaseSuccessful = true
        manager.lastErrorMessage = "Old error"
        
        await manager.purchaseSeasonPass()
        
        // Assert old states are cleared and only the new pending state is set
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isPurchaseFailed)
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertNil(manager.lastErrorMessage)
        XCTAssertTrue(manager.isPurchasePending)
    }
    
    func testTransientStateCleanupOnNewRestoreWorkflow() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let manager = PurchaseManager(
            entitlementFetcher: SpyEntitlementFetcher(),
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            restoreAction: { throw CancellationError() } // Fail the restore
        )
        
        // Artificially dirty the transient states
        manager.isPurchasePending = true
        manager.isPurchaseCancelled = true
        manager.isPurchaseSuccessful = true
        manager.isPurchaseFailed = true
        manager.isRestoreSuccessful = true
        manager.isNothingToRestore = true
        
        await manager.restore()
        
        // Assert old states are cleared
        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseCancelled)
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertFalse(manager.isPurchaseFailed)
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        
        // Assert only the restore error message is set
        XCTAssertEqual(manager.lastErrorMessage, "We couldn’t restore purchases. Please try again.")
    }
    
    func testOfflineRecoveryUsesKeychainWhenStoreKitIsEmpty() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [] // StoreKit returns empty (e.g. offline with empty cache)
        
        // Seed keychain with a future expiration
        let formatter = ISO8601DateFormatter()
        let maxDate = Date(timeIntervalSince1970: 1767225599) // Dec 31, 2025
        if let data = formatter.string(from: maxDate).data(using: .utf8) {
            try? keychain.set(data, for: entitlementKey)
        }
        
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        // Startup behavior
        await manager.refreshEntitlements()
        
        // Assert entitlement is recovered from offline known state
        XCTAssertEqual(manager.entitlementState, .entitled)
        XCTAssertTrue(manager.isSeasonPassActive)
    }
    
    func testRecoveryFromInterruptedPurchase() async {
        // Interrupted purchases yield verified inputs in currentEntitlements
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(productID: "com.komakode.ScoreKeep.SeasonPass2025", isVerified: true, isRevoked: false)
        ]
        
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        XCTAssertFalse(manager.isSeasonPassActive)
        
        // Startup behavior
        await manager.refreshEntitlements()
        
        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }
}
