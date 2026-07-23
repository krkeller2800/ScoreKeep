import XCTest
import StoreKit
@testable import ScoreKeep

struct MockProduct: DiscoveredProduct {
    var id: String
    var displayName: String
    var displayPrice: String
    var description: String

    var purchaseResultToReturn: Product.PurchaseResult = .pending

    func purchase() async throws -> Product.PurchaseResult {
        return purchaseResultToReturn
    }
}

final class MockProductCatalogFetcher: ProductCatalogFetching {
    var productsToReturn: [DiscoveredProduct] = []
    var errorToThrow: Error?

    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct] {
        if let error = errorToThrow {
            throw error
        }
        return productsToReturn.filter { identifiers.contains($0.id) }
    }
}

@MainActor
final class Task96LocalizedPriceStateSuite: XCTestCase {

    func testNotStartedState() {
        let manager = PurchaseManager()
        XCTAssertEqual(manager.priceState, .notStarted)
    }

    func testSuccessfulLocalizedProductDiscovery() async {
        let fetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        fetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]

        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.loadProducts()

        if case .discovered(let product) = manager.priceState {
            XCTAssertEqual(product.id, productID)
            XCTAssertEqual(product.displayPrice, "$19.99")
        } else {
            XCTFail("Expected .discovered state, got \(manager.priceState)")
        }
        XCTAssertNil(manager.lastErrorMessage)
    }

    func testUnavailableProductState() async {
        let fetcher = MockProductCatalogFetcher()
        fetcher.productsToReturn = [] // Product is unavailable

        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.loadProducts()

        XCTAssertEqual(manager.priceState, .productUnavailable)
        XCTAssertEqual(manager.lastErrorMessage, "This year’s Season Pass is not currently available.")
        XCTAssertNil(manager.seasonPassProduct)
    }

    func testDiscoveryFailureState() async {
        let fetcher = MockProductCatalogFetcher()
        fetcher.errorToThrow = NSError(domain: "Test", code: 1, userInfo: nil)

        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.loadProducts()

        XCTAssertEqual(manager.priceState, .failure(.lookupFailed))
        XCTAssertEqual(manager.lastErrorMessage, "We couldn’t load this year’s Season Pass. Please try again in a moment.")
        XCTAssertNil(manager.seasonPassProduct)
    }

    func testNoStalePricePresentationAfterFailure() async {
        let fetcher = MockProductCatalogFetcher()
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"

        // 1. Success first
        fetcher.productsToReturn = [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ]

        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.loadProducts()

        if case .discovered(let product) = manager.priceState {
            XCTAssertEqual(product.displayPrice, "$19.99")
        } else {
            XCTFail("Expected .discovered state")
        }

        // 2. Now fail
        fetcher.errorToThrow = NSError(domain: "Test", code: 1, userInfo: nil)
        await manager.loadProducts()

        XCTAssertEqual(manager.priceState, .failure(.lookupFailed))
        XCTAssertNil(manager.seasonPassProduct, "Live product should be cleared")
        XCTAssertEqual(manager.lastErrorMessage, "We couldn’t load this year’s Season Pass. Please try again in a moment.")
    }
}
