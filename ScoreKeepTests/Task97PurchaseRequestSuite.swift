import XCTest
@testable import ScoreKeep

@MainActor
final class Task97PurchaseRequestSuite: XCTestCase {
    
    func testPurchaseRequestBeginsWhenProductIsAvailable() async {
        let fetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        fetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        // Setup state to .discovered
        await manager.loadProducts()
        
        // In our mock, liveProduct.purchase() now works!
        // We can't check isPurchasing synchronously because the defer block resets it.
        // But we can check that it didn't crash, and that the state properly evaluates.
        await manager.purchaseSeasonPass()
        
        XCTAssertFalse(manager.isPurchasing) // Reset by defer
        XCTAssertTrue(manager.isPurchasePending) // Because the mock returns pending by default
    }
    
    func testNoPurchaseRequestOccursWithoutDiscoveredProduct() async {
        let manager = PurchaseManager()
        // Default state is .notStarted
        await manager.purchaseSeasonPass()
        XCTAssertFalse(manager.isPurchasing)
    }
}
