import Foundation
import XCTest
@testable import ScoreKeep

private final class RolloverDateSource: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDate: Date

    init(_ date: Date) {
        storedDate = date
    }

    func callAsFunction() -> Date {
        lock.withLock { storedDate }
    }

    func set(_ date: Date) {
        lock.withLock { storedDate = date }
    }
}

private actor RolloverCatalogFetcher: ProductCatalogFetching {
    private let products: [MockProduct]
    private(set) var requestedIdentifiers: [[String]] = []

    init(products: [MockProduct]) {
        self.products = products
    }

    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct] {
        requestedIdentifiers.append(identifiers)
        return products.filter { identifiers.contains($0.id) }
    }

    func requests() -> [[String]] {
        requestedIdentifiers
    }
}

private actor RolloverPurchaseRecorder {
    private(set) var purchasedProductIDs: [String] = []

    func record(_ productID: String) {
        purchasedProductIDs.append(productID)
    }

    func productIDs() -> [String] {
        purchasedProductIDs
    }
}

@MainActor
final class Task915SeasonRolloverSafetySuite: XCTestCase {
    private let product2026 = MockProduct(
        id: "com.komakode.ScoreKeep.SeasonPass2026",
        displayName: "ScoreKeep 2026 Season Pass",
        displayPrice: "$4.99",
        description: "Score games through 2026"
    )
    private let product2027 = MockProduct(
        id: "com.komakode.ScoreKeep.SeasonPass2027",
        displayName: "ScoreKeep 2027 Season Pass",
        displayPrice: "$4.99",
        description: "Score games through 2027"
    )

    func testActivationOrPaywallRediscoveryTracksNewSeasonWithoutRecreatingManager() async {
        let dateSource = RolloverDateSource(date(year: 2026))
        let fetcher = RolloverCatalogFetcher(products: [product2026, product2027])
        let manager = PurchaseManager(catalogFetcher: fetcher, calendar: utcCalendar, currentDate: { dateSource() })

        await manager.loadProducts()
        XCTAssertEqual(manager.discoveredSeasonProductID, product2026.id)

        dateSource.set(date(year: 2027))
        await manager.ensureCurrentSeasonProduct()

        XCTAssertEqual(manager.discoveredSeasonProductID, product2027.id)
        let requests = await fetcher.requests()
        XCTAssertEqual(requests, [[product2026.id], [product2027.id]])
    }

    func testPurchaseNeverUsesCachedPriorSeasonProductAfterRollover() async {
        let dateSource = RolloverDateSource(date(year: 2026))
        let fetcher = RolloverCatalogFetcher(products: [product2026])
        let purchaseRecorder = RolloverPurchaseRecorder()
        let manager = PurchaseManager(
            catalogFetcher: fetcher,
            calendar: utcCalendar,
            currentDate: { dateSource() },
            purchaseAction: { product in
                await purchaseRecorder.record(product.id)
                return .userCancelled
            }
        )

        await manager.loadProducts()
        dateSource.set(date(year: 2027))
        await manager.purchaseSeasonPass()

        let purchasedProductIDs = await purchaseRecorder.productIDs()
        let requests = await fetcher.requests()
        XCTAssertEqual(purchasedProductIDs, [])
        XCTAssertEqual(requests, [[product2026.id], [product2027.id]])
        XCTAssertEqual(manager.priceState, .productUnavailable)
        XCTAssertNil(manager.discoveredSeasonProductID)
    }

    func testSameSeasonActivationDoesNotRediscoverProduct() async {
        let dateSource = RolloverDateSource(date(year: 2026))
        let fetcher = RolloverCatalogFetcher(products: [product2026, product2027])
        let manager = PurchaseManager(catalogFetcher: fetcher, calendar: utcCalendar, currentDate: { dateSource() })

        await manager.loadProducts()
        await manager.ensureCurrentSeasonProduct()
        await manager.ensureCurrentSeasonProduct()

        let requests = await fetcher.requests()
        XCTAssertEqual(requests, [[product2026.id]])
        XCTAssertEqual(manager.discoveredSeasonProductID, product2026.id)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: 6, day: 1))!
    }
}
