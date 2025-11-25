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

    // State for Paywall UI
    @Published var isPurchasing: Bool = false
    @Published var lastErrorMessage: String?

    // MARK: - Configuration
    private let seasonPassProductID = "com.komakode.ScoreKeep.seasonpass.annual"

    // Keep a reference to the updates listening task so it can live with the manager
    private var updatesTask: Task<Void, Never>?

    init() {
        // Begin listening to transaction updates immediately
        startListeningForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Public API

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [seasonPassProductID])
            // If StoreKit returns empty (can happen transiently), retry once shortly after
            if let first = products.first {
                self.seasonPassProduct = first
                self.lastErrorMessage = nil
            } else {
                // Retry once after a short delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                let retry = try await Product.products(for: [seasonPassProductID])
                if let firstRetry = retry.first {
                    self.seasonPassProduct = firstRetry
                    self.lastErrorMessage = nil
                } else {
                    self.seasonPassProduct = nil
                    self.lastErrorMessage = "We couldn’t load purchase options. Please try again in a moment."
                }
            }
        } catch {
            // Retry once on transient errors
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                let retry = try await Product.products(for: [seasonPassProductID])
                if let firstRetry = retry.first {
                    self.seasonPassProduct = firstRetry
                    self.lastErrorMessage = nil
                } else {
                    self.seasonPassProduct = nil
                    self.lastErrorMessage = "We couldn’t load purchase options. Please try again in a moment."
                }
            } catch {
                self.seasonPassProduct = nil
                self.lastErrorMessage = "We couldn’t load purchase options. Please try again in a moment."
            }
        }
    }

    /// Existing convenience purchase for the single season pass product.
    func purchaseSeasonPass() async {
        guard let product = seasonPassProduct else { return }
        await purchase(product: product)
    }

    /// Existing restore convenience.
    func restore() async {
        await restorePurchases()
    }

    /// Recalculate entitlement state from current entitlements.
    /// Call at app launch and when app returns to foreground.
    func refreshEntitlements() async {
        var active = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                // Only consider our product ID
                if transaction.productID == seasonPassProductID {
                    // Auto-renewable subscription: confirm not expired as of now
                    if let expiration = transaction.expirationDate {
                        active = expiration > Date()
                    } else {
                        // If StoreKit doesn’t provide an expiration for some reason, be conservative
                        active = true
                    }
                }
            }
        }

        self.isSeasonPassActive = active
    }

    // MARK: - New wrappers for PaywallView

    /// Purchases a specific StoreKit Product and updates entitlement state.
    func purchase(product: Product) async {
        lastErrorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                // Verify the transaction
                if let transaction = try? checkVerified(verificationResult) {
                    // Finish the transaction and refresh entitlements
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    self.lastErrorMessage = "We couldn’t verify the purchase with the App Store."
                }
            case .userCancelled:
                // Friendly, non-error state
                self.lastErrorMessage = "Purchase was cancelled."
            case .pending:
                // The purchase is pending (e.g., Ask to Buy). Entitlement will update later.
                self.lastErrorMessage = "Your purchase is pending approval. You’ll get access automatically once it’s approved."
            @unknown default:
                self.lastErrorMessage = "An unknown purchase result occurred."
            }
        } catch {
            // Provide a friendly message
            self.lastErrorMessage = "We couldn’t complete the purchase. Please try again."
        }
    }

    /// Restores purchases and refreshes entitlements.
    func restorePurchases() async {
        lastErrorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            // After sync, entitlements may change; refresh them
            await refreshEntitlements()
            // If still not active, let user know
            if !isSeasonPassActive {
                self.lastErrorMessage = "No previous purchases were found for this Apple ID."
            }
        } catch {
            self.lastErrorMessage = "We couldn’t restore purchases. Please try again."
        }
    }

    // MARK: - Private helpers

    private func startListeningForTransactions() {
        updatesTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                // Hop back to main actor to verify and process
                await self.handle(transactionUpdate: update)
            }
        }
    }

    @MainActor
    private func handle(transactionUpdate update: VerificationResult<Transaction>) async {
        if let transaction = try? checkVerified(update) {
            // Only react to our product
            if transaction.productID == seasonPassProductID {
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
            // Throwing here stops processing unverified transactions
            throw error
        case .verified(let signedType):
            return signedType
        }
    }
}
