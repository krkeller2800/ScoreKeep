import Foundation
import SwiftData

struct ScoreKeepStartupStoreLocation: Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable, Sendable {
        case productionIntendedApplicationStore
        case disposableTestStore
        case disposableSourceCopy
        case disposableMigrationTarget
        case readOnlyDiagnosticCopy
        case unsupportedOrUnknown
    }

    let kind: Kind
    let url: URL?
    let requiresFreshDestination: Bool

    static func disposableTestStore(url: URL, requiresFreshDestination: Bool = false) -> ScoreKeepStartupStoreLocation {
        ScoreKeepStartupStoreLocation(kind: .disposableTestStore, url: url, requiresFreshDestination: requiresFreshDestination)
    }

    static func disposableSourceCopy(url: URL) -> ScoreKeepStartupStoreLocation {
        ScoreKeepStartupStoreLocation(kind: .disposableSourceCopy, url: url, requiresFreshDestination: false)
    }

    static func disposableMigrationTarget(url: URL, requiresFreshDestination: Bool = true) -> ScoreKeepStartupStoreLocation {
        ScoreKeepStartupStoreLocation(kind: .disposableMigrationTarget, url: url, requiresFreshDestination: requiresFreshDestination)
    }

    static func readOnlyDiagnosticCopy(url: URL) -> ScoreKeepStartupStoreLocation {
        ScoreKeepStartupStoreLocation(kind: .readOnlyDiagnosticCopy, url: url, requiresFreshDestination: false)
    }

    static let productionIntendedApplicationStore = ScoreKeepStartupStoreLocation(kind: .productionIntendedApplicationStore, url: nil, requiresFreshDestination: false)
    static let unsupportedOrUnknown = ScoreKeepStartupStoreLocation(kind: .unsupportedOrUnknown, url: nil, requiresFreshDestination: false)
}

enum ScoreKeepStartupWritabilityMode: String, CaseIterable, Hashable, Sendable {
    case writable
    case readOnlyDiagnosis
}

enum ScoreKeepProposedSchemaSelection: String, CaseIterable, Hashable, Sendable, Codable {
    case proposedV2
    case proposedV3
}

enum ScoreKeepProposedMigrationPlanSelection: String, CaseIterable, Hashable, Sendable {
    case provenV1ToV2TeamCreationEvidencePlan
    case provenV1ToV3CanonicalScoringStoragePlan
}

enum ScoreKeepStartupIntent: String, CaseIterable, Hashable, Sendable {
    case isolatedVerification
    case productionTransitionPreparation
    case readOnlyDiagnosis
}

enum ScoreKeepSchemaRouteChoice: String, CaseIterable, Hashable, Sendable {
    case legacyUnversionedProductionStartup
    case proposedV2PreparedButDisabled
    case proposedV2EligibleForIsolatedVerification
    case proposedV2EligibleForBoundedProductionTransition
    case proposedV2Active
    case proposedV2DisabledAfterActivation
    case proposedV3PreparedButDisabled
    case proposedV3EligibleForIsolatedVerification
    case proposedV3EligibleForBoundedProductionTransition
    case proposedV3Active
    case proposedV3DisabledAfterActivation
    case recoveryOnly
    case unsafe

    static let currentDefault: ScoreKeepSchemaRouteChoice = .legacyUnversionedProductionStartup
}

enum ScoreKeepSourceStoreClassification: String, CaseIterable, Hashable, Sendable, Codable {
    case noStoreExists
    case emptyCurrentUnversionedStore
    case populatedCurrentUnversionedStore
    case proposedV1RecognizableStore
    case existingProposedV2Store
    case existingProposedV3Store
    case automaticallyEvolvedComparisonStore
    case convertedProposedV2Store
    case convertedProposedV3Store
    case unknownVersion
    case unsupportedFutureVersion
    case unreadableStore
    case contradictoryMetadata
    case migrationEvidenceExists
    case migrationEvidenceMissing
    case migrationEvidenceUncertain
    case readOnlyDiagnosisRequired

    var isSupportedForProposedV2Startup: Bool {
        switch self {
        case .noStoreExists, .emptyCurrentUnversionedStore, .populatedCurrentUnversionedStore,
             .proposedV1RecognizableStore, .existingProposedV2Store, .existingProposedV3Store,
             .convertedProposedV2Store, .convertedProposedV3Store:
            return true
        case .automaticallyEvolvedComparisonStore, .unknownVersion, .unsupportedFutureVersion,
             .unreadableStore, .contradictoryMetadata, .migrationEvidenceExists,
             .migrationEvidenceMissing, .migrationEvidenceUncertain, .readOnlyDiagnosisRequired:
            return false
        }
    }

    var requiresMigration: Bool {
        switch self {
        case .emptyCurrentUnversionedStore, .populatedCurrentUnversionedStore, .proposedV1RecognizableStore,
             .existingProposedV2Store, .convertedProposedV2Store:
            return true
        case .noStoreExists, .existingProposedV3Store, .convertedProposedV3Store,
             .automaticallyEvolvedComparisonStore, .unknownVersion, .unsupportedFutureVersion,
             .unreadableStore, .contradictoryMetadata, .migrationEvidenceExists,
             .migrationEvidenceMissing, .migrationEvidenceUncertain, .readOnlyDiagnosisRequired:
            return false
        }
    }
}

enum ScoreKeepStartupMigrationPhase: String, CaseIterable, Hashable, Sendable, Comparable {
    case notAssessed
    case noMigrationRequired
    case migrationRequired
    case preflightInProgress
    case sourceSnapshotVerified
    case sourcePreservationRequired
    case migrationPermitted
    case containerConstructionInProgress
    case containerConstructed
    case postOpenVerificationRequired
    case postOpenVerificationPassed
    case completionRecordingRequired
    case completed
    case interrupted
    case failedSafely
    case completionUncertain
    case recoveryRequired
    case disabled
    case unsupported
    case readOnly
    case writesProhibited

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: ScoreKeepStartupMigrationPhase, rhs: ScoreKeepStartupMigrationPhase) -> Bool {
        lhs.order < rhs.order
    }
}

struct ScoreKeepStartupMigrationSnapshot: Hashable, Sendable {
    let phase: ScoreKeepStartupMigrationPhase
    let sourceClassification: ScoreKeepSourceStoreClassification
    let routeChoice: ScoreKeepSchemaRouteChoice
    let operationIdentity: ScoreKeepMigrationOperationIdentity?
    let diagnosticsRequired: Bool

    static let notAssessed = ScoreKeepStartupMigrationSnapshot(
        phase: .notAssessed,
        sourceClassification: .unknownVersion,
        routeChoice: .legacyUnversionedProductionStartup,
        operationIdentity: nil,
        diagnosticsRequired: false
    )
}

struct ScoreKeepMigrationOperationIdentity: Hashable, Sendable, Codable {
    let sourceStoreIdentity: String
    let sourceSchema: ScoreKeepSourceStoreClassification
    let targetSchema: ScoreKeepProposedSchemaSelection
    let applicationMigrationGeneration: Int
    let operationUUID: UUID

    var diagnosticToken: String {
        "migration-\(applicationMigrationGeneration)-\(operationUUID.uuidString.prefix(8))"
    }
}

enum ScoreKeepStartupOutcomeKind: String, CaseIterable, Hashable, Sendable {
    case legacyStartupActive
    case proposedStartupPreparedButDisabled
    case newEmptyProposedV2StoreReady
    case existingStoreMigratedAndVerified
    case existingProposedV2StoreVerified
    case readOnlyRecoveryMode
    case sourceUnsupported
    case migrationBlocked
    case migrationFailedSafely
    case migrationCompletionUncertain
    case verificationFailed
    case recoveryRequired
    case retryPermittedWithSameMigrationIdentity
    case retryProhibited
    case userReviewRequired
    case applicationStartupMustStopBeforeWrites
    case fatalConfigurationDefect
}

struct ScoreKeepStartupOutcome: Hashable, Sendable {
    let kind: ScoreKeepStartupOutcomeKind
    let mayShowAppContent: Bool
    let mayReadBaseballRecords: Bool
    let mayWriteBaseballRecords: Bool
    let mayUseLegacyStartup: Bool
    let automaticFallbackProhibited: Bool
    let retryIsSafe: Bool
    let sourcePreservationMustRemain: Bool
    let diagnosticsRequired: Bool

    static func outcome(for kind: ScoreKeepStartupOutcomeKind) -> ScoreKeepStartupOutcome {
        switch kind {
        case .legacyStartupActive:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: true, mayReadBaseballRecords: true, mayWriteBaseballRecords: true, mayUseLegacyStartup: true, automaticFallbackProhibited: false, retryIsSafe: false, sourcePreservationMustRemain: false, diagnosticsRequired: false)
        case .newEmptyProposedV2StoreReady, .existingStoreMigratedAndVerified, .existingProposedV2StoreVerified:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: true, mayReadBaseballRecords: true, mayWriteBaseballRecords: true, mayUseLegacyStartup: false, automaticFallbackProhibited: true, retryIsSafe: false, sourcePreservationMustRemain: false, diagnosticsRequired: true)
        case .proposedStartupPreparedButDisabled:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: true, mayReadBaseballRecords: true, mayWriteBaseballRecords: false, mayUseLegacyStartup: true, automaticFallbackProhibited: false, retryIsSafe: false, sourcePreservationMustRemain: false, diagnosticsRequired: true)
        case .retryPermittedWithSameMigrationIdentity:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: false, mayReadBaseballRecords: false, mayWriteBaseballRecords: false, mayUseLegacyStartup: false, automaticFallbackProhibited: true, retryIsSafe: true, sourcePreservationMustRemain: true, diagnosticsRequired: true)
        case .readOnlyRecoveryMode:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: true, mayReadBaseballRecords: true, mayWriteBaseballRecords: false, mayUseLegacyStartup: false, automaticFallbackProhibited: true, retryIsSafe: false, sourcePreservationMustRemain: true, diagnosticsRequired: true)
        case .sourceUnsupported, .migrationBlocked, .migrationFailedSafely, .migrationCompletionUncertain,
             .verificationFailed, .recoveryRequired, .retryProhibited, .userReviewRequired,
             .applicationStartupMustStopBeforeWrites, .fatalConfigurationDefect:
            return ScoreKeepStartupOutcome(kind: kind, mayShowAppContent: false, mayReadBaseballRecords: false, mayWriteBaseballRecords: false, mayUseLegacyStartup: false, automaticFallbackProhibited: true, retryIsSafe: false, sourcePreservationMustRemain: true, diagnosticsRequired: true)
        }
    }
}

struct ScoreKeepWriteReadinessInput: Hashable, Sendable {
    var sourceClassification: ScoreKeepSourceStoreClassification
    var constructionSucceeded: Bool
    var requiredMigrationCompleted: Bool
    var postOpenVerificationPassed: Bool
    var completionEvidenceReconciled: Bool
    var hasUncertainty: Bool
    var recoveryRequired: Bool
    var routeChoice: ScoreKeepSchemaRouteChoice
    var proposedSchemaActive: Bool
    var storeIsWritable: Bool
    var oneWriterPolicyAvailable: Bool
    var diagnosticsIdentifyAuthority: Bool
    var productionCutoverApprovalSupplied: Bool
}

struct ScoreKeepWriteReadinessResult: Hashable, Sendable {
    let permitsBaseballWrites: Bool
    let blockingReasons: Set<String>
}

enum ScoreKeepWriteReadinessEvaluator {
    static func evaluate(_ input: ScoreKeepWriteReadinessInput) -> ScoreKeepWriteReadinessResult {
        var reasons = Set<String>()
        if !input.sourceClassification.isSupportedForProposedV2Startup { reasons.insert("sourceClassificationUnsupported") }
        if !input.constructionSucceeded { reasons.insert("containerConstructionNotSucceeded") }
        if !input.requiredMigrationCompleted { reasons.insert("requiredMigrationNotCompleted") }
        if !input.postOpenVerificationPassed { reasons.insert("postOpenVerificationMissing") }
        if !input.completionEvidenceReconciled { reasons.insert("completionEvidenceNotReconciled") }
        if input.hasUncertainty { reasons.insert("uncertaintyPresent") }
        if input.recoveryRequired { reasons.insert("recoveryRequired") }
        if input.routeChoice != .proposedV2Active && input.routeChoice != .proposedV3Active { reasons.insert("routeNotActive") }
        if !input.proposedSchemaActive { reasons.insert("proposedSchemaNotActive") }
        if !input.storeIsWritable { reasons.insert("storeReadOnly") }
        if !input.oneWriterPolicyAvailable { reasons.insert("oneWriterPolicyMissing") }
        if !input.diagnosticsIdentifyAuthority { reasons.insert("diagnosticsAuthorityMissing") }
        if !input.productionCutoverApprovalSupplied { reasons.insert("productionCutoverApprovalMissing") }
        return ScoreKeepWriteReadinessResult(permitsBaseballWrites: reasons.isEmpty, blockingReasons: reasons)
    }
}

struct ScoreKeepStartupDiagnosticSummary: Hashable, Sendable {
    let factoryPath: String
    let routeChoice: ScoreKeepSchemaRouteChoice
    let storeLocationKind: ScoreKeepStartupStoreLocation.Kind
    let sourceClassification: ScoreKeepSourceStoreClassification
    let migrationDiagnosticToken: String?
    let targetSchema: ScoreKeepProposedSchemaSelection
    let constructionDisposition: ScoreKeepProposedContainerConstructionDisposition
    let verificationDisposition: String
    let writeReadinessDisposition: String
    let disableState: ScoreKeepSchemaRouteChoice
    let recoveryRequired: Bool
    let stableDiagnosticCodes: [String]
}
