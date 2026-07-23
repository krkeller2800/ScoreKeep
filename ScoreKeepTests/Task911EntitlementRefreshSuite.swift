import XCTest
@testable import ScoreKeep
import StoreKit

final class SpyEntitlementFetcher: CurrentEntitlementFetching, @unchecked Sendable {
    var inputs: [TransactionEvidenceInput] = []
    private(set) var callCount = 0
    
    func currentEntitlements() async -> [TransactionEvidenceInput] {
        callCount += 1
        return inputs
    }
}

@MainActor
final class Task911EntitlementRefreshSuite: XCTestCase {
    
    func testVerifiedPurchaseRefreshesEntitlementAndUnlocksAccess() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let entitlementFetcher = SpyEntitlementFetcher()
        // Provide the evidence that refreshEntitlements will find
        entitlementFetcher.inputs = [
            TransactionEvidenceInput(productID: productID, isVerified: true, isRevoked: false)
        ]
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) }
        )
        
        await manager.loadProducts()
        
        XCTAssertEqual(entitlementFetcher.callCount, 0)
        XCTAssertFalse(manager.isSeasonPassActive)
        
        await manager.purchaseSeasonPass()
        
        XCTAssertTrue(manager.isPurchaseSuccessful)
        XCTAssertEqual(entitlementFetcher.callCount, 1, "Refresh should be called exactly once")
        XCTAssertTrue(manager.isSeasonPassActive, "Premium access should be unlocked")
        XCTAssertEqual(manager.entitlementState, .entitled)
    }
    
    func testUnverifiedPurchaseDoesNotRefreshEntitlement() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let entitlementFetcher = SpyEntitlementFetcher()
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: false) }
        )
        
        await manager.loadProducts()
        await manager.purchaseSeasonPass()
        
        XCTAssertTrue(manager.isPurchaseUnverified)
        XCTAssertEqual(entitlementFetcher.callCount, 0, "Unverified purchase should not trigger refresh")
        XCTAssertFalse(manager.isSeasonPassActive)
    }
    
    func testDuplicateRefreshIsAvoidedWhenAlreadyActive() async {
        let catalogFetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        catalogFetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]
        
        let entitlementFetcher = SpyEntitlementFetcher()
        entitlementFetcher.inputs = [
            TransactionEvidenceInput(productID: productID, isVerified: true, isRevoked: false)
        ]
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) }
        )
        
        await manager.loadProducts()
        
        // Simulate app launch refresh
        await manager.refreshEntitlements()
        XCTAssertEqual(entitlementFetcher.callCount, 1)
        XCTAssertTrue(manager.isSeasonPassActive)
        
        // Trigger purchase again (e.g. user tapped buy but StoreKit returned success because already owned)
        await manager.purchaseSeasonPass()
        
        XCTAssertTrue(manager.isPurchaseSuccessful)
        // Count should STILL be 1! Duplicate avoided.
        XCTAssertEqual(entitlementFetcher.callCount, 1, "Duplicate refresh should be avoided if already active")
    }
}
