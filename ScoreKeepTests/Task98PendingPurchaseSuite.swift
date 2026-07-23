import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task98PendingPurchaseSuite: XCTestCase {
    
    func testPendingPurchaseUpdatesState() async {
        let fetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        
        let mockProduct = MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        fetcher.productsToReturn = [mockProduct]
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return .pending }
        )
        
        await manager.loadProducts()
        
        // Assert initial state
        XCTAssertFalse(manager.isPurchasePending)
        
        // Trigger purchase
        await manager.purchaseSeasonPass()
        
        // Assert updated pending state
        XCTAssertTrue(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchasing) // Should be false after the call finishes
    }
}
