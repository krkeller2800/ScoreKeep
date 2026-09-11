import XCTest
import StoreKit
@testable import ScoreKeep

struct MockProduct: DiscoveredProduct {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}

enum MockProductCatalogFetcherError: Error, Sendable {
    case requestedFailure
}

final class MockProductCatalogFetcher: ProductCatalogFetching {
    let productsToReturn: [any DiscoveredProduct]
    let errorToThrow: MockProductCatalogFetcherError?

    init(
        productsToReturn: [any DiscoveredProduct] = [],
        errorToThrow: MockProductCatalogFetcherError? = nil
    ) {
        self.productsToReturn = productsToReturn
        self.errorToThrow = errorToThrow
    }

    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct] {
        if let error = errorToThrow {
            throw error
        }
        return productsToReturn.filter { identifiers.contains($0.id) }
    }
}

private actor MockProductCatalogFetchCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

final class SequencedMockProductCatalogFetcher: ProductCatalogFetching {
    private let firstProducts: [any DiscoveredProduct]
    private let counter = MockProductCatalogFetchCounter()

    init(firstProducts: [any DiscoveredProduct]) {
        self.firstProducts = firstProducts
    }

    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct] {
        if await counter.next() == 1 {
            return firstProducts.filter { identifiers.contains($0.id) }
        }
        throw MockProductCatalogFetcherError.requestedFailure
    }
}

@MainActor
final class Task96LocalizedPriceStateSuite: XCTestCase {

    func testNotStartedState() {
        let manager = PurchaseManager()
        XCTAssertEqual(manager.priceState, .notStarted)
    }

    func testSuccessfulLocalizedProductDiscovery() async {
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"
        let fetcher = MockProductCatalogFetcher(productsToReturn: [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ])

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
        let fetcher = MockProductCatalogFetcher(errorToThrow: .requestedFailure)

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
        let productID = "com.komakode.ScoreKeep.SeasonPass2025"

        // 1. Success first
        let fetcher = SequencedMockProductCatalogFetcher(firstProducts: [
            MockProduct(id: productID, displayName: "Season Pass", displayPrice: "$19.99", description: "ScoreKeep Season Pass")
        ])

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
        await manager.loadProducts()

        XCTAssertEqual(manager.priceState, .failure(.lookupFailed))
        XCTAssertNil(manager.seasonPassProduct, "Live product should be cleared")
        XCTAssertEqual(manager.lastErrorMessage, "We couldn’t load this year’s Season Pass. Please try again in a moment.")
    }
}
