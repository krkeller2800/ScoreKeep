import XCTest
@testable import ScoreKeep
import StoreKit

private actor RestoreActionSpy {
    private var called = false

    func markCalled() {
        called = true
    }

    func wasCalled() -> Bool {
        called
    }
}

@MainActor
final class Task913RestorePurchasesSuite: XCTestCase {
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

    
    func testSuccessfulRestoreUpdatesStateAndEntitlement() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        let catalogFetcher = MockProductCatalogFetcher(productsToReturn: [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ])
        
        let entitlementFetcher = SpyEntitlementFetcher()
        // Provide the evidence that refreshEntitlements will find during restore
        entitlementFetcher.inputs = [
            TransactionEvidenceInput(productID: productID, isVerified: true, isRevoked: false)
        ]
        
        let restoreAction = RestoreActionSpy()
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) },
            restoreAction: { await restoreAction.markCalled() }
        )
        
        await manager.loadProducts()
        
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertFalse(manager.isSeasonPassActive)
        
        // Trigger restore
        await manager.restore()
        
        let restoreWasCalled = await restoreAction.wasCalled()
        XCTAssertTrue(restoreWasCalled, "Restore action should be called")
        XCTAssertTrue(manager.isRestoreSuccessful, "Restore successful state should be published")
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertTrue(manager.isSeasonPassActive, "Entitlement should be refreshed and active")
        XCTAssertEqual(manager.entitlementState, .entitled)
    }
    
    func testNoPurchasesToRestoreUpdatesState() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        let catalogFetcher = MockProductCatalogFetcher(productsToReturn: [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ])
        
        let entitlementFetcher = SpyEntitlementFetcher()
        // Empty inputs simulating no prior purchases
        entitlementFetcher.inputs = []
        
        let restoreAction = RestoreActionSpy()
        
        let manager = PurchaseManager(
            entitlementFetcher: entitlementFetcher,
            catalogFetcher: catalogFetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) }, // Jun 1, 2025
            purchaseAction: { _ in return PurchaseManager.PurchaseOutcome.success(verified: true) },
            restoreAction: { await restoreAction.markCalled() }
        )
        
        await manager.loadProducts()
        
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertFalse(manager.isNothingToRestore)
        XCTAssertFalse(manager.isSeasonPassActive)
        
        // Trigger restore
        await manager.restore()
        
        let restoreWasCalled = await restoreAction.wasCalled()
        XCTAssertTrue(restoreWasCalled, "Restore action should be called")
        XCTAssertFalse(manager.isRestoreSuccessful)
        XCTAssertTrue(manager.isNothingToRestore, "Nothing to restore state should be published")
        XCTAssertFalse(manager.isSeasonPassActive, "Entitlement should remain inactive")
        XCTAssertEqual(manager.entitlementState, .statusUnavailable)
    }
}
