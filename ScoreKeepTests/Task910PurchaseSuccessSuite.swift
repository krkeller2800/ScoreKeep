import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task910PurchaseSuccessSuite: XCTestCase {
    
    func testPurchaseSuccessVerifiedUpdatesState() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        
        let mockProduct = MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        let fetcher = MockProductCatalogFetcher(productsToReturn: [mockProduct])
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) } // Inject verified success
        )
        
        await manager.loadProducts()
        
        // Assert initial state
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertFalse(manager.isPurchaseUnverified)
        
        // Trigger purchase
        await manager.purchaseSeasonPass()
        
        // Assert updated state
        XCTAssertTrue(manager.isPurchaseSuccessful)
        XCTAssertFalse(manager.isPurchaseUnverified)
        XCTAssertFalse(manager.isPurchasing) // Should be false after the call finishes
        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseCancelled)
    }
    
    func testPurchaseSuccessUnverifiedUpdatesState() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        
        let mockProduct = MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        let fetcher = MockProductCatalogFetcher(productsToReturn: [mockProduct])
        
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: false) } // Inject unverified success
        )
        
        await manager.loadProducts()
        
        // Assert initial state
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertFalse(manager.isPurchaseUnverified)
        
        // Trigger purchase
        await manager.purchaseSeasonPass()
        
        // Assert updated state
        XCTAssertFalse(manager.isPurchaseSuccessful)
        XCTAssertTrue(manager.isPurchaseUnverified)
        XCTAssertFalse(manager.isPurchasing) // Should be false after the call finishes
        XCTAssertFalse(manager.isPurchasePending)
        XCTAssertFalse(manager.isPurchaseCancelled)
    }
}
