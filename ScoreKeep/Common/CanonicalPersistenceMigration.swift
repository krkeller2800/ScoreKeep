import Foundation

/// Non-routed Phase 3 migration vocabulary for classifying migration inputs and results.
///
/// These values are shallow by design. They do not store SwiftData containers, contexts,
/// model objects, closures, purchase receipts, Keychain values, or production routing state.
enum CanonicalMigrationSourceClassification: String, CaseIterable, Hashable, Sendable {
    case trulyEmptyNewStore
    case emptyExistingStore
    case metadataOnlyNoBaseballRecords
    case preferencesOnlyNoBaseballRecords
    case purchaseOrAllowanceOnlyNoBaseballRecords
    case previouslyInitializedEmptyStore
    case populatedExistingStore
    case unknownSourceVersion
    case unsupportedSource
    case unableToOpenSource
}

enum CanonicalMigrationTargetClassification: String, CaseIterable, Hashable, Sendable {
    case currentSwiftDataEmptyBaseballState
    case currentSwiftDataPopulatedState
    case targetUnavailable
    case notEstablished
}

enum CanonicalMigrationMode: String, CaseIterable, Hashable, Sendable {
    case classifyOnly
    case initializeEmptyStore
    case verifyEmptyStoreIdempotency
    case rejectPopulatedStore
}

enum CanonicalMigrationDisposition: String, CaseIterable, Hashable, Sendable {
    case notRequired
    case emptySourceInitialized
    case success
    case successWithWarnings
    case noChange
    case alreadyMigrated
    case partialOrUncertain
    case interrupted
    case retrySafe
    case retryUnsafe
    case recoveryAvailable
    case validationRejected
    case unsupportedSource
    case unknownSourceVersion
    case relationshipFailure
    case orderingFailure
    case mediaFailure
    case purchaseSeparationFailure
    case contradictory
    case unresolved
    case requiresReview
    case requiresRollback
    case priorStorePreserved
}

struct CanonicalMigrationRecordCounts: Hashable, Sendable {
    let games: Int
    let teams: Int
    let players: Int
    let atbats: Int
    let lineups: Int
    let pitchers: Int

    static let empty = CanonicalMigrationRecordCounts(
        games: 0,
        teams: 0,
        players: 0,
        atbats: 0,
        lineups: 0,
        pitchers: 0
    )

    var baseballRecordCount: Int {
        games + teams + players + atbats + lineups + pitchers
    }

    var containsBaseballRecords: Bool {
        baseballRecordCount > 0
    }
}

struct CanonicalMigrationPurchaseAllowanceProbe: Hashable, Sendable {
    let freeGameCreatesRemaining: Int
    let mlbDownloadUseCount: Int
    let entitlementMarker: String
    let purchaseMarker: String

    init(
        freeGameCreatesRemaining: Int,
        mlbDownloadUseCount: Int,
        entitlementMarker: String,
        purchaseMarker: String
    ) {
        self.freeGameCreatesRemaining = freeGameCreatesRemaining
        self.mlbDownloadUseCount = mlbDownloadUseCount
        self.entitlementMarker = entitlementMarker
        self.purchaseMarker = purchaseMarker
    }
}

struct CanonicalMigrationInput: Hashable, Sendable {
    let fixtureIdentity: String
    let operationIdentity: String
    let sourceVersion: String?
    let targetVersion: String
    let sourceClassification: CanonicalMigrationSourceClassification
    let targetClassification: CanonicalMigrationTargetClassification
    let mode: CanonicalMigrationMode
    let sourceRecordCounts: CanonicalMigrationRecordCounts
    let purchaseAllowanceProbe: CanonicalMigrationPurchaseAllowanceProbe

    init(
        fixtureIdentity: String,
        operationIdentity: String,
        sourceVersion: String?,
        targetVersion: String,
        sourceClassification: CanonicalMigrationSourceClassification,
        targetClassification: CanonicalMigrationTargetClassification,
        mode: CanonicalMigrationMode,
        sourceRecordCounts: CanonicalMigrationRecordCounts = .empty,
        purchaseAllowanceProbe: CanonicalMigrationPurchaseAllowanceProbe
    ) {
        self.fixtureIdentity = fixtureIdentity
        self.operationIdentity = operationIdentity
        self.sourceVersion = sourceVersion
        self.targetVersion = targetVersion
        self.sourceClassification = sourceClassification
        self.targetClassification = targetClassification
        self.mode = mode
        self.sourceRecordCounts = sourceRecordCounts
        self.purchaseAllowanceProbe = purchaseAllowanceProbe
    }
}

struct CanonicalMigrationFinding: Hashable, Sendable {
    let code: String
    let summary: String
    let requiresReview: Bool

    init(code: String, summary: String, requiresReview: Bool = false) {
        self.code = code
        self.summary = summary
        self.requiresReview = requiresReview
    }
}

struct CanonicalMigrationResult: Hashable, Sendable {
    let disposition: CanonicalMigrationDisposition
    let sourceClassification: CanonicalMigrationSourceClassification
    let targetClassification: CanonicalMigrationTargetClassification
    let sourceRecordCounts: CanonicalMigrationRecordCounts
    let targetRecordCounts: CanonicalMigrationRecordCounts
    let findings: [CanonicalMigrationFinding]
    let transactionResult: CanonicalPersistenceTransactionResult
    let purchaseAllowanceProbeBefore: CanonicalMigrationPurchaseAllowanceProbe
    let purchaseAllowanceProbeAfter: CanonicalMigrationPurchaseAllowanceProbe
    let sourceRemainsUsable: Bool
    let targetIsUsable: Bool
    let retryIsSafe: Bool
    let reloadRequired: Bool
    let reviewOrRepairRequired: Bool
    let producedRecords: Bool
    let noOp: Bool
    let completionProven: Bool

    var purchaseAndAllowanceUnchanged: Bool {
        purchaseAllowanceProbeBefore == purchaseAllowanceProbeAfter
    }
}

enum CanonicalMigrationClassifier {
    static func classifyEmptySource(
        recordCounts: CanonicalMigrationRecordCounts,
        hasMetadata: Bool,
        hasPreferences: Bool,
        hasPurchaseOrAllowanceEvidence: Bool,
        wasPreviouslyInitialized: Bool,
        sourceVersionKnown: Bool
    ) -> CanonicalMigrationSourceClassification {
        guard sourceVersionKnown else { return .unknownSourceVersion }
        guard recordCounts.containsBaseballRecords == false else { return .populatedExistingStore }
        if wasPreviouslyInitialized { return .previouslyInitializedEmptyStore }
        if hasPurchaseOrAllowanceEvidence { return .purchaseOrAllowanceOnlyNoBaseballRecords }
        if hasPreferences { return .preferencesOnlyNoBaseballRecords }
        if hasMetadata { return .metadataOnlyNoBaseballRecords }
        return .trulyEmptyNewStore
    }

    static func migrationDisposition(
        for sourceClassification: CanonicalMigrationSourceClassification,
        mode: CanonicalMigrationMode,
        targetRecordCounts: CanonicalMigrationRecordCounts,
        purchaseAllowanceUnchanged: Bool,
        initializationFailed: Bool = false,
        interrupted: Bool = false
    ) -> CanonicalMigrationDisposition {
        if purchaseAllowanceUnchanged == false { return .purchaseSeparationFailure }
        if initializationFailed { return .recoveryAvailable }
        if interrupted { return .interrupted }
        if targetRecordCounts.containsBaseballRecords { return .requiresReview }

        switch sourceClassification {
        case .trulyEmptyNewStore, .emptyExistingStore, .metadataOnlyNoBaseballRecords,
             .preferencesOnlyNoBaseballRecords, .purchaseOrAllowanceOnlyNoBaseballRecords:
            return mode == .classifyOnly ? .notRequired : .emptySourceInitialized
        case .previouslyInitializedEmptyStore:
            return .noChange
        case .populatedExistingStore:
            return .requiresReview
        case .unknownSourceVersion:
            return .unknownSourceVersion
        case .unsupportedSource, .unableToOpenSource:
            return .unsupportedSource
        }
    }
}
