import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task99PurchaseCancellationSuite: XCTestCase {
    
    func testPurchaseCancellationUpdatesState() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        
        let mockProduct = MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        let fetcher = MockProductCatalogFetcher(productsToReturn: [mockProduct])
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.userCancelled } // Inject user cancellation
        )
        
        await manager.loadProducts()
        
        // Assert initial state
        XCTAssertFalse(manager.isPurchaseCancelled)
        
        // Trigger purchase
        await manager.purchaseSeasonPass()
        
        // Assert updated cancelled state
        XCTAssertTrue(manager.isPurchaseCancelled)
        XCTAssertFalse(manager.isPurchasing) // Should be false after the call finishes
        XCTAssertFalse(manager.isPurchasePending) // Should not be pending
    }
}
