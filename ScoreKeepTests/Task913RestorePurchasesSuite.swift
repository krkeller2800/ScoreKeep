import XCTest
@testable import ScoreKeep
import StoreKit

@MainActor
final class Task913RestorePurchasesSuite: XCTestCase {
    
    func testSuccessfulRestoreUpdatesStateAndEntitlement() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let entitlementFetcher = SpyEntitlementFetcher()
        // Provide the evidence that refreshEntitlements will find during restore
        entitlementFetcher.inputs = [
            TransactionEvidenceInput(productID: productID, isVerified: true, isRevoked: false)
        ]
        
        var restoreActionCalled = false
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) },
            restoreAction: { restoreActionCalled = true }
        )
        
        await manager.loadProducts()
        
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertFalse(manager.isSeasonPassActive)
        
        // Trigger restore
        await manager.restore()
        
        XCTAssertTrue(restoreActionCalled, "Restore action should be called")
        XCTAssertTrue(manager.isRestoreSuccessful, "Restore successful state should be published")
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertTrue(manager.isSeasonPassActive, "Entitlement should be refreshed and active")
        XCTAssertEqual(manager.entitlementState, .entitled)
    }
    
    func testNoPurchasesToRestoreUpdatesState() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let entitlementFetcher = SpyEntitlementFetcher()
        // Empty inputs simulating no prior purchases
        entitlementFetcher.inputs = []
        
        var restoreActionCalled = false
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) },
            restoreAction: { restoreActionCalled = true }
        )
        
        await manager.loadProducts()
        
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertFalse(manager.isSeasonPassActive)
        
        // Trigger restore
        await manager.restore()
        
        XCTAssertTrue(restoreActionCalled, "Restore action should be called")
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertTrue(manager.isNothingToRestore, "Nothing to restore state should be published")
        XCTAssertFalse(manager.isSeasonPassActive, "Entitlement should remain inactive")
        XCTAssertEqual(manager.entitlementState, .notEntitled)
    }
}
