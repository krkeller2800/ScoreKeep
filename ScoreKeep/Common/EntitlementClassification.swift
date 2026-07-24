import Foundation

public enum EntitlementState: Hashable, Sendable {
    case entitled
    case notEntitled
    case priorSeason
    case futureSeason
    case statusUnavailable
}

public struct EntitlementEvidence: Equatable, Sendable {
    public let season: SeasonClassification
    public let isVerified: Bool
    public let isRevoked: Bool

    public init(
        season: SeasonClassification,
        isVerified: Bool,
        isRevoked: Bool
    ) {
        self.season = season
        self.isVerified = isVerified
        self.isRevoked = isRevoked
    }
}

public struct EntitlementClassifier: Sendable {
    public init() {}

    public func classify(
        evidence: [EntitlementEvidence]
    ) -> EntitlementState {
        var hasPrior = false
        var hasFuture = false

        for record in evidence {
            if record.isVerified && !record.isRevoked {
                switch record.season {
                case .current:
                    return .entitled // Highest access, early exit
                case .prior:
                    hasPrior = true
                case .future:
                    hasFuture = true
                case .wrong, .missingSeason:
                    break
                }
            }
        }

        if evidence.isEmpty {
            return .statusUnavailable
        }

        if hasPrior {
            return .priorSeason
        } else if hasFuture {
            return .futureSeason
        } else {
            return .notEntitled
        }
    }
}
