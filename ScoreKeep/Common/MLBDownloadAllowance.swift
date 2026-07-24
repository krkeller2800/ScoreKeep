import Foundation

struct MLBDownloadAllowanceState: Equatable, Sendable {
    static let counterKey = "mlbDownloadCountKC"
    static let defaultUsedCount = 0
    static let freeLimit = 4
    static let invalidStoredUsedCount = freeLimit

    let usedCount: Int
    let storageInterpretation: KeychainBackedCounter.StorageInterpretation

    var remaining: Int {
        max(0, Self.freeLimit - usedCount)
    }

    var canDownloadWithAllowance: Bool {
        remaining > 0
    }

    var displayText: String {
        "Downloads remaining: \(remaining) of \(Self.freeLimit)"
    }

    var accessibilityLabel: String {
        "MLB downloads remaining \(remaining) of \(Self.freeLimit)"
    }
}
