import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task912PurchaseFailureSuite: XCTestCase {
    
    struct DummyError: Error {}
    
    func testPurchaseFailureUpdatesStateAndLeavesEntitlementUnchanged() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let manager = PurchaseManager(
            entitlementFetcher: StoreKitCurrentEntitlementFetcher(), // Default, shouldn't be called
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in throw DummyError() } // Simulate a thrown error
        )
        
        await manager.loadProducts()
        
        // Setup initial entitlement state artificially to ensure it doesn't change
        manager.entitlementState = .notEntitled
        manager.isSeasonPassActive = false
        
        // Assert initial failure state
        XCTAssertFalse(manager.isPurchaseFailed)
        
        // Trigger purchase
        await manager.purchaseSeasonPass()
        
        // Assert updated failure state
        XCTAssertTrue(manager.isPurchaseFailed)
        
        // Assert transient purchase state is reset
        XCTAssertFalse(manager.isPurchasing)
        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertFalse(manager.isPurchaseUnverified)
        XCTAssertFalse(manager.isPurchaseCancelled)
        
        // Assert entitlement is unchanged
        XCTAssertEqual(manager.entitlementState, .notEntitled)
        XCTAssertFalse(manager.isSeasonPassActive)
    }
}
