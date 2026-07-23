//
//  PurchaseManager.swift
//  ScoreKeep
//
//  Created by Karl Keller on 11/24/25.
//

import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    // MARK: - Public published properties for UI
    @Published var isSeasonPassActive: Bool = false
    @Published var seasonPassProduct: Product?
    @Published var entitlementState: EntitlementState = .notEntitled
    @Published var priceState: ProductDiscoveryState = .notStarted

    // State for Paywall UI
    @Published var isPurchasing: Bool = false
    @Published var isPurchasePending: Bool = false
    @Published var lastErrorMessage: String?

    // MARK: - Configuration
    // Build the product ID by convention from the current calendar year.
    // Keep the prefix stable and ensure App Store Connect has the current-year product approved in advance.
    private let productIDPrefix = "com.komakode.ScoreKeep.SeasonPass"

    // Local entitlement storage (Keychain)
    private let keychain = KeychainService()
    // Store the single "max expiration" date across any purchases
    private let entitlementKey = "seasonPassMaxExpirationISO8601" // Data stored as ISO8601 string

    // Keep a reference to the updates listening task so it can live with the manager
    private var updatesTask: Task<Void, Never>?

    private let entitlementFetcher: any CurrentEntitlementFetching
    private let calendar: Calendar
    private let currentDate: @Sendable () -> Date
    private let discoveryService: ProductDiscoveryService

    init(
        entitlementFetcher: any CurrentEntitlementFetching = StoreKitCurrentEntitlementFetcher(),
        catalogFetcher: any ProductCatalogFetching = StoreKitProductCatalogFetcher(),
        calendar: Calendar = .current,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.entitlementFetcher = entitlementFetcher
        self.calendar = calendar
        self.currentDate = currentDate

        self.discoveryService = ProductDiscoveryService(
            fetcher: catalogFetcher,
            identifierProvider: CalendarSeasonIdentifierProvider(calendar: calendar, currentDate: currentDate)
        )

        // Begin listening to transaction updates immediately
        startListeningForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Public API

    func loadProducts() async {
        lastErrorMessage = nil
        priceState = .loading

        await discoveryService.discoverCurrentSeasonProduct()
        self.priceState = discoveryService.state

        // Update the legacy product field for compatibility with the purchase method
        switch discoveryService.state {
        case .discovered(let discoveredProduct):
            if let liveProduct = discoveredProduct as? Product {
                self.seasonPassProduct = liveProduct
                self.lastErrorMessage = nil
            } else {
                // If it's a mock product during testing, clear the live product
                self.seasonPassProduct = nil
                self.lastErrorMessage = nil
            }
        case .productUnavailable:
            self.seasonPassProduct = nil
            self.lastErrorMessage = "This year’s Season Pass is not currently available."
        case .failure:
            self.seasonPassProduct = nil
            self.lastErrorMessage = "We couldn’t load this year’s Season Pass. Please try again in a moment."
        case .loading, .notStarted:
            break
        }
    }

    /// Initiates a purchase request for the currently discovered Season Pass.
    func purchaseSeasonPass() async {
        guard case .discovered(let discoveredProduct) = priceState else { return }

        isPurchasing = true
        isPurchasePending = false
        defer { isPurchasing = false }

        // Only handle pending requests per Task 9.8.
        if let result = try? await discoveredProduct.purchase() {
            if case .pending = result {
                self.isPurchasePending = true
            }
        }
    }

    /// Checks current StoreKit purchase status for the non-renewing Season Pass.
    func restore() async {
        await restorePurchases()
    }

    /// Recalculate entitlement state from StoreKit and locally stored expiration.
    /// Call at app launch and when app returns to foreground.
    func refreshEntitlements() async {
        let currentYear = calendar.component(.year, from: currentDate())
        let normalizer = TransactionEvidenceNormalizer(seasonClassifier: SeasonClassifier())
        let classifier = EntitlementClassifier()

        var evidenceRecords: [EntitlementEvidence] = []

        // 1. Evaluate StoreKit transactions
        let inputs = await entitlementFetcher.currentEntitlements()
        for input in inputs {
            let evidence = normalizer.normalize(input: input, currentYear: currentYear)
            evidenceRecords.append(evidence)
        }

        // 2. Evaluate Keychain evidence
        if let maxExpiration = loadLocalMaxExpiration() {
            // "Preserve previously confirmed access offline."
            if maxExpiration > currentDate() {
                evidenceRecords.append(EntitlementEvidence(season: .current, isVerified: true, isRevoked: false))
            } else if maxExpiration != .distantPast {
                evidenceRecords.append(EntitlementEvidence(season: .prior, isVerified: true, isRevoked: false))
            }
        }

        // 3. Classify and update state
        let newState = classifier.classify(evidence: evidenceRecords)
        self.entitlementState = newState
        self.isSeasonPassActive = (newState == .entitled)
    }

    // MARK: - Purchase

    /// Purchases a specific StoreKit Product and updates entitlement state.
    // Legacy inline purchase(product:) method removed by Task 9.7.

    /// Checks purchase status and refreshes local entitlements.
    /// The Season Pass is non-renewing, so it does not appear as an auto-renewing subscription.
    func restorePurchases() async {
        lastErrorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            // AppStore.sync does not make non-renewing purchases active on a new device.
            await refreshEntitlements()
            if isSeasonPassActive {
                self.lastErrorMessage = "Your Season Pass is active on this device. It is non-renewing and does not renew automatically."
            } else {
                self.lastErrorMessage = "The Season Pass is a non-renewing purchase. It unlocks ScoreKeep through the season year and does not renew automatically. If you changed devices and need help restoring access, please contact support."
            }
        } catch {
            self.lastErrorMessage = "We couldn’t restore purchases. Please try again."
        }
    }

    /// Presents the system manage subscriptions UI.
    /// Not applicable for non‑renewing subscriptions; open the subscriptions URL as a fallback or show support.
    func manageSubscriptions() async {
        // For non‑renewing, system sheet won’t manage this purchase. Use fallback.
        openSubscriptionsURLFallback()
    }

    private func openSubscriptionsURLFallback() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        DispatchQueue.main.async {
            #if canImport(UIKit)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            #endif
        }
    }

    // MARK: - Private helpers

    private func startListeningForTransactions() {
        updatesTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                await self.handle(transactionUpdate: update)
            }
        }
    }

    @MainActor
    private func handle(transactionUpdate update: VerificationResult<Transaction>) async {
        if let transaction = try? checkVerified(update) {
            // Non‑renewing product: compute/store expiration when we see a verified transaction
            if let year = extractYear(fromProductID: transaction.productID) {
                let expiration = endOfYear(for: year)
                saveLocalMaxExpiration(expiration)

                await transaction.finish()
                await refreshEntitlements()
            } else {
                // Finish any other transactions too, just in case
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signedType):
            return signedType
        }
    }

    // MARK: - Product loading helpers

    private func loadCurrentYearProduct(productID: String) async throws -> Product? {
        let products = try await Product.products(for: [productID])
        return products.first { $0.id == productID }
    }

    private func currentSeasonPassProductID() -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        return "\(productIDPrefix)\(currentYear)"
    }

    // MARK: - Year handling

    private func extractYear(fromProductID productID: String) -> Int? {
        // Expect last 4 characters to be the year (e.g., ...SeasonPass2026)
        guard productID.count >= 4 else { return nil }
        let suffix = String(productID.suffix(4))
        return Int(suffix)
    }

    private func endOfYear(for year: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = 12
        comps.day = 31
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        // Use the current calendar/time zone (local end of year)
        return Calendar.current.date(from: comps) ?? Date.distantPast
    }

    // MARK: - Entitlement persistence (Keychain)

    private func saveLocalMaxExpiration(_ newDate: Date) {
        let existing = loadLocalMaxExpiration() ?? .distantPast
        let maxDate = max(existing, newDate)
        let formatter = ISO8601DateFormatter()
        let str = formatter.string(from: maxDate)
        if let data = str.data(using: .utf8) {
            try? keychain.set(data, for: entitlementKey)
        }
    }

    private func loadLocalMaxExpiration() -> Date? {
        do {
            if let data = try keychain.get(entitlementKey),
               let str = String(data: data, encoding: .utf8) {
                return ISO8601DateFormatter().date(from: str)
            }
        } catch {
            // ignore and treat as inactive
        }
        return nil
    }
}
