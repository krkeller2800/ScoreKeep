import Foundation
import StoreKit

/// Abstracts the fetching of current entitlements to allow deterministic testing.
public protocol CurrentEntitlementFetching: Sendable {
    func currentEntitlements() async -> [TransactionEvidenceInput]
}

/// Live implementation that calls StoreKit directly.
public struct StoreKitCurrentEntitlementFetcher: CurrentEntitlementFetching {
    public init() {}
    
    public func currentEntitlements() async -> [TransactionEvidenceInput] {
        var inputs: [TransactionEvidenceInput] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                inputs.append(TransactionEvidenceInput(
                    productID: transaction.productID,
                    isVerified: true,
                    isRevoked: transaction.revocationDate != nil
                ))
            case .unverified(let transaction, _):
                inputs.append(TransactionEvidenceInput(
                    productID: transaction.productID,
                    isVerified: false,
                    isRevoked: transaction.revocationDate != nil
                ))
            }
        }
        return inputs
    }
}
