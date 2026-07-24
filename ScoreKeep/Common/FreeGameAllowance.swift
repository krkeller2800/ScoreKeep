import Foundation

struct FreeGameAllowanceState: Equatable, Sendable {
    static let counterKey = "freeGameCreatesRemainingKC"
    static let defaultRemaining = 2
    static let invalidStoredRemaining = 0

    let remaining: Int
    let storageInterpretation: KeychainBackedCounter.StorageInterpretation

    var canCreateWithAllowance: Bool {
        remaining > 0
    }

    var displayText: String {
        "Free games: \(remaining)"
    }

    var accessibilityLabel: String {
        "Free games remaining \(remaining)"
    }
}

enum FreeGameAllowanceBuildConfiguration: Equatable, Sendable {
    case debug
    case release
}

enum FreeGameAllowanceDebugResetClassification: Equatable, Sendable {
    case debugOnlyResetToDefault
    case noProductionReset
}

struct FreeGameAllowanceDebugResetPolicy: Sendable {
    static func classify(
        buildConfiguration: FreeGameAllowanceBuildConfiguration
    ) -> FreeGameAllowanceDebugResetClassification {
        switch buildConfiguration {
        case .debug:
            return .debugOnlyResetToDefault
        case .release:
            return .noProductionReset
        }
    }
}
