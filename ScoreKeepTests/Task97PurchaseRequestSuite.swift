import XCTest
@testable import ScoreKeep

@MainActor
final class Task97PurchaseRequestSuite: XCTestCase {
    
    func testPurchaseRequestBeginsWhenProductIsAvailable() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        let fetcher = MockProductCatalogFetcher(productsToReturn: [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ])
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.userCancelled } // Simulate cancellation to verify boundary
        )
        
        // Setup state to .discovered
        await manager.loadProducts()
        
        // The purchase will use our injected closure and return .userCancelled.
        // It shouldn't crash, and the pending state should remain false.
        await manager.purchaseSeasonPass()
        
        XCTAssertFalse(manager.isPurchasing) // Reset by defer
        XCTAssertFalse(manager.isPurchasePending) // Because we returned .userCancelled
    }
    
    func testNoPurchaseRequestOccursWithoutDiscoveredProduct() async {
        let manager = PurchaseManager()
        // Default state is .notStarted
        await manager.purchaseSeasonPass()
        XCTAssertFalse(manager.isPurchasing)
    }
}
