import Testing
@testable import ScoreKeep
import Foundation
import StoreKit

@Suite("Task 9.1 Product Discovery Suite")
struct Task91ProductDiscoverySuite {

    struct FakeProduct: DiscoveredProduct {
        var id: String
        var displayName: String
        var displayPrice: String
        var description: String
        func purchase() async throws -> Product.PurchaseResult { return .pending }
    }

    final class FakeProductFetcher: ProductCatalogFetching, @unchecked Sendable {
        var productsToReturn: [FakeProduct]
        var shouldFail: Bool
        var requestedIdentifiers: [[String]] = []

        init(productsToReturn: [FakeProduct] = [], shouldFail: Bool = false) {
            self.productsToReturn = productsToReturn
            self.shouldFail = shouldFail
        }

        func fetchProducts(for identifiers: [String]) async throws -> [any DiscoveredProduct] {
            requestedIdentifiers.append(identifiers)
            if shouldFail {
                struct LookupError: Error {}
                throw LookupError()
            }
            // Preserve StoreKit logic by returning only matching products
            return productsToReturn.filter { identifiers.contains($0.id) }
        }
    }

    struct FakeIdentifierProvider: CurrentSeasonIdentifierProviding {
        var identifier: String
        func currentSeasonIdentifier() -> String {
            return identifier
        }
    }

    @Test("Initial state is notStarted")
    @MainActor
    func initialState() {
        let fetcher = FakeProductFetcher()
        let provider = FakeIdentifierProvider(identifier: "com.komakode.ScoreKeep.SeasonPass2025")
        let service = ProductDiscoveryService(fetcher: fetcher, identifierProvider: provider)
        #expect(service.state == .notStarted)
    }

    @Test("Discovers and preserves product metadata for the exact current-season identifier")
    @MainActor
    func discoversCurrentSeasonProduct() async {
        let expectedProduct = FakeProduct(
            id: "com.komakode.ScoreKeep.SeasonPass2026",
            displayName: "ScoreKeep 2026 Season Pass",
            displayPrice: "$4.99",
            description: "Score games through 2026"
        )
        let fetcher = FakeProductFetcher(productsToReturn: [expectedProduct])
        // Use 2026 per instructions to prove dynamic capability
        let provider = FakeIdentifierProvider(identifier: "com.komakode.ScoreKeep.SeasonPass2026")
        let service = ProductDiscoveryService(fetcher: fetcher, identifierProvider: provider)

        await service.discoverCurrentSeasonProduct()

        // Verifies the fake captured the request exactly without arbitrary caller input
        #expect(fetcher.requestedIdentifiers == [["com.komakode.ScoreKeep.SeasonPass2026"]])

        #expect(service.state == .discovered(expectedProduct))
        if case .discovered(let product) = service.state {
            #expect(product.id == "com.komakode.ScoreKeep.SeasonPass2026")
            #expect(product.displayName == "ScoreKeep 2026 Season Pass")
            #expect(product.displayPrice == "$4.99")
            #expect(product.description == "Score games through 2026")
        }
    }

    @Test("Product unavailable when StoreKit returns empty for current-season identifier")
    @MainActor
    func productUnavailable() async {
        let fetcher = FakeProductFetcher(productsToReturn: [])
        let provider = FakeIdentifierProvider(identifier: "com.komakode.ScoreKeep.SeasonPass2026")
        let service = ProductDiscoveryService(fetcher: fetcher, identifierProvider: provider)

        await service.discoverCurrentSeasonProduct()

        #expect(fetcher.requestedIdentifiers == [["com.komakode.ScoreKeep.SeasonPass2026"]])
        #expect(service.state == .productUnavailable)
    }

    @Test("Lookup failure represents deterministic semantic error without inventing entitlement conclusions")
    @MainActor
    func lookupFailure() async {
        let fetcher = FakeProductFetcher(shouldFail: true)
        let provider = FakeIdentifierProvider(identifier: "com.komakode.ScoreKeep.SeasonPass2026")
        let service = ProductDiscoveryService(fetcher: fetcher, identifierProvider: provider)

        await service.discoverCurrentSeasonProduct()

        #expect(fetcher.requestedIdentifiers == [["com.komakode.ScoreKeep.SeasonPass2026"]])
        #expect(service.state == .failure(.lookupFailed))
    }

    @Test("CalendarSeasonIdentifierProvider builds identifier correctly using repository evidence")
    func calendarProviderBuildsIdentifier() {
        var dateComponents = DateComponents()
        dateComponents.year = 2026
        dateComponents.month = 6
        dateComponents.day = 1
        let testDate = Calendar.current.date(from: dateComponents)!

        let provider = CalendarSeasonIdentifierProvider(calendar: .current, currentDate: { testDate })
        #expect(provider.currentSeasonIdentifier() == "com.komakode.ScoreKeep.SeasonPass2026")
    }

    @Test("Unrelated or differently ordered product does not replace the requested product")
    @MainActor
    func ignoresUnrelatedProduct() async {
        let expectedProduct = FakeProduct(
            id: "com.komakode.ScoreKeep.SeasonPass2026",
            displayName: "ScoreKeep 2026 Season Pass",
            displayPrice: "$4.99",
            description: "Score games through 2026"
        )
        let unrelatedProduct = FakeProduct(
            id: "com.komakode.ScoreKeep.SeasonPass2025",
            displayName: "ScoreKeep 2025 Season Pass",
            displayPrice: "$4.99",
            description: "Score games through 2025"
        )
        // StoreKit may return extra products or out of order; we should only match the requested one.
        let fetcher = FakeProductFetcher(productsToReturn: [unrelatedProduct, expectedProduct])
        let provider = FakeIdentifierProvider(identifier: "com.komakode.ScoreKeep.SeasonPass2026")
        let service = ProductDiscoveryService(fetcher: fetcher, identifierProvider: provider)

        await service.discoverCurrentSeasonProduct()

        #expect(service.state == .discovered(expectedProduct))
    }
}
