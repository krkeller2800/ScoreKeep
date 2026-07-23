public struct TransactionEvidenceInput: Equatable, Sendable {
    public let productID: String
    public let isVerified: Bool
    public let isRevoked: Bool
    
    public init(
        productID: String,
        isVerified: Bool,
        isRevoked: Bool
    ) {
        self.productID = productID
        self.isVerified = isVerified
        self.isRevoked = isRevoked
    }
}

public struct TransactionEvidenceNormalizer: Sendable {
    private let seasonClassifier: SeasonClassifier
    
    public init(
        seasonClassifier: SeasonClassifier = SeasonClassifier()
    ) {
        self.seasonClassifier = seasonClassifier
    }
    
    public func normalize(
        input: TransactionEvidenceInput,
        currentYear: Int
    ) -> EntitlementEvidence {
        let season = seasonClassifier.classify(
            identifier: input.productID,
            currentYear: currentYear
        )
        return EntitlementEvidence(
            season: season,
            isVerified: input.isVerified,
            isRevoked: input.isRevoked
        )
    }
}
