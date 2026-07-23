import Foundation
import StoreKit

/// Represents a product discovered from StoreKit, abstracting the live `Product` type.
protocol DiscoveredProduct: Sendable {
    var id: String { get }
    var displayName: String { get }
    var displayPrice: String { get }
    var description: String { get }

    @MainActor
    func purchase() async throws -> Product.PurchaseResult
}

extension Product: DiscoveredProduct {
    func purchase() async throws -> Product.PurchaseResult {
        return try await self.purchase(options: [])
    }
}

/// Abstracts the fetching of products to allow deterministic testing.
protocol ProductCatalogFetching: Sendable {
    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct]
}

/// Live implementation that calls StoreKit directly.
struct StoreKitProductCatalogFetcher: ProductCatalogFetching {
    func fetchProducts(for identifiers: [String]) async throws -> [DiscoveredProduct] {
        return try await Product.products(for: identifiers)
    }
}

enum ProductDiscoveryError: Error, Equatable, Sendable {
    case lookupFailed
}

/// The possible states of product discovery.
enum ProductDiscoveryState: Equatable, Sendable {
    case notStarted
    case loading
    case discovered(any DiscoveredProduct)
    case productUnavailable
    case failure(ProductDiscoveryError)

    static func == (lhs: ProductDiscoveryState, rhs: ProductDiscoveryState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.loading, .loading),
             (.productUnavailable, .productUnavailable):
            return true
        case (.discovered(let lhsProduct), .discovered(let rhsProduct)):
            return lhsProduct.id == rhsProduct.id &&
                   lhsProduct.displayName == rhsProduct.displayName &&
                   lhsProduct.displayPrice == rhsProduct.displayPrice &&
                   lhsProduct.description == rhsProduct.description
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Abstracts retrieving the current-season product identifier.
protocol CurrentSeasonIdentifierProviding: Sendable {
    func currentSeasonIdentifier() -> String
}

/// Uses the calendar year to build the season pass identifier, mirroring the repository's convention.
struct CalendarSeasonIdentifierProvider: CurrentSeasonIdentifierProviding {
    private let prefix = "com.komakode.ScoreKeep.SeasonPass"
    private let calendar: Calendar
    private let currentDate: @Sendable () -> Date

    init(calendar: Calendar = .current, currentDate: @escaping @Sendable () -> Date = { Date() }) {
        self.calendar = calendar
        self.currentDate = currentDate
    }

    func currentSeasonIdentifier() -> String {
        let year = calendar.component(.year, from: currentDate())
        return "\(prefix)\(year)"
    }
}

/// Prepares product authority by looking up the current-season product identifier
/// without inventing future prices or making entitlement decisions.
@MainActor
final class ProductDiscoveryService: ObservableObject {
    @Published private(set) var state: ProductDiscoveryState = .notStarted

    private let fetcher: any ProductCatalogFetching
    private let identifierProvider: any CurrentSeasonIdentifierProviding

    init(fetcher: any ProductCatalogFetching = StoreKitProductCatalogFetcher(),
         identifierProvider: any CurrentSeasonIdentifierProviding = CalendarSeasonIdentifierProvider()) {
        self.fetcher = fetcher
        self.identifierProvider = identifierProvider
    }

    /// Discovers the current-season product intrinsically without accepting an arbitrary identifier.
    func discoverCurrentSeasonProduct() async {
        state = .loading
        let identifier = identifierProvider.currentSeasonIdentifier()
        do {
            let products = try await fetcher.fetchProducts(for: [identifier])
            if let product = products.first(where: { $0.id == identifier }) {
                state = .discovered(product)
            } else {
                state = .productUnavailable
            }
        } catch {
            state = .failure(.lookupFailed)
        }
    }
}
