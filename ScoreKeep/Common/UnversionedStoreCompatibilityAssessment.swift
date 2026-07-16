import Foundation

struct UnversionedStoreCompatibilityAssessment: Hashable, Sendable {
    enum EvidenceLevel: String, Sendable {
        case provenCompatible = "Proven compatible"
        case compatibleThroughConversionStrategy = "Compatible only through a specific conversion strategy"
        case likelyCompatibleButNotProven = "Likely compatible but not proven"
        case requiresArchiveBuiltPriorAppOrDeviceCopyEvidence = "Requires archive-built prior-app or device-copy evidence"
        case unsupported = "Unsupported"
        case unsafe = "Unsafe"
        case blockedByFrameworkLimitation = "Blocked by a reproducible framework limitation"
    }

    enum RecommendedDirection: String, Sendable {
        case directV1ToV2TransitionProven = "Direction A - Direct V1-to-V2 Transition Proven"
        case automaticIndependentModelAdditionProvenExplicitVersioningUnresolved = "Direction B - Automatic Independent-Model Addition Proven but Explicit Versioning Still Unresolved"
        case storeCopyCompatibilityConversionRequired = "Direction C - Store-Copy Compatibility Conversion Required"
        case archiveOrDeviceEvidenceStillRequired = "Direction D - Archive/Device Evidence Still Required"
        case unsupportedOrUnsafe = "Direction E - Unsupported or Unsafe"
    }

    enum OpenClassification: String, Sendable {
        case openedAndPreservedEvidence
        case openedWithEmptyEvidenceStorage
        case refusedUnknownModelVersion
        case refusedChecksumMismatch
        case refusedSchemaMismatch
        case refusedMigrationStageFailure
        case refusedPersistentStoreFailure
        case openedButVerificationFailed
        case notAttempted
    }

    let evidenceLevel: EvidenceLevel
    let recommendedDirection: RecommendedDirection
    let proposedV1Recognition: OpenClassification
    let directProposedV2Migration: OpenClassification
    let automaticModelAddition: OpenClassification
    let conversionFallback: OpenClassification
    let productionRoutingChanged: Bool

    static let isolatedCurrentRun = UnversionedStoreCompatibilityAssessment(
        evidenceLevel: .provenCompatible,
        recommendedDirection: .directV1ToV2TransitionProven,
        proposedV1Recognition: .openedAndPreservedEvidence,
        directProposedV2Migration: .openedWithEmptyEvidenceStorage,
        automaticModelAddition: .openedWithEmptyEvidenceStorage,
        conversionFallback: .notAttempted,
        productionRoutingChanged: false
    )
}
