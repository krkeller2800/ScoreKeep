import Foundation

enum ScoreKeepMigrationJournalDiagnosticCode: String, CaseIterable, Codable, Hashable, Sendable {
    case journalUnreadable
    case journalVersionUnsupported
    case sourceUnavailable
    case sourceActive
    case backupDestinationNotFresh
    case storeFamilyIncomplete
    case backupCopyFailed
    case backupFingerprintMismatch
    case backupSemanticMismatch
    case workspaceCopyFailed
    case workspaceFingerprintMismatch
    case proposedContainerConstructionFailed
    case constructionCompletionUncertain
    case postOpenVerificationFailed
    case completionEvidenceFailed
    case disableStateActive
    case ownershipConflict
    case recoveryRequired
}

enum ScoreKeepSchemaRouteDisableState: String, CaseIterable, Codable, Hashable, Sendable {
    case legacyRouteRequired
    case proposedTransitionPreparedButDisabled
    case proposedTransitionExplicitlyAuthorized
    case proposedTransitionTemporarilyDisabled
    case recoveryOnly
    case proposedSchemaActiveButNewWritersDisabled
    case unsafe
    case unknownFutureValue

    static let currentDefault: ScoreKeepSchemaRouteDisableState = .legacyRouteRequired

    var failsClosed: Bool {
        switch self {
        case .proposedTransitionExplicitlyAuthorized:
            return false
        case .legacyRouteRequired, .proposedTransitionPreparedButDisabled,
             .proposedTransitionTemporarilyDisabled, .recoveryOnly,
             .proposedSchemaActiveButNewWritersDisabled, .unsafe, .unknownFutureValue:
            return true
        }
    }
}

enum ScoreKeepStartupOwnershipState: String, CaseIterable, Codable, Hashable, Sendable {
    case noOwner
    case legacyContainerSelected
    case proposedContainerSelected
    case migrationInProgress
    case recoveryOwner
    case ownershipUncertain
    case conflictingOwners
    case released

    var blocksWrites: Bool {
        switch self {
        case .legacyContainerSelected, .proposedContainerSelected:
            return false
        case .noOwner, .migrationInProgress, .recoveryOwner, .ownershipUncertain, .conflictingOwners, .released:
            return true
        }
    }
}

enum ScoreKeepMigrationJournalPhase: String, CaseIterable, Codable, Comparable, Hashable, Sendable {
    case noEvidence
    case preflightStarted
    case sourceClassified
    case sourcePreservationStarted
    case backupVerified
    case workspaceCreationStarted
    case workspaceVerified
    case migrationAttemptStarted
    case containerConstructed
    case destinationVerificationPending
    case postOpenVerificationStarted
    case postOpenVerificationPassed
    case completionRecorded
    case failedSafely
    case completionUncertain
    case recoveryRequired
    case disabled

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: ScoreKeepMigrationJournalPhase, rhs: ScoreKeepMigrationJournalPhase) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum ScoreKeepSourcePreservationDisposition: String, CaseIterable, Codable, Hashable, Sendable {
    case notRequiredForNewEmptyStore
    case required
    case started
    case sourceNotClosed
    case sourceUnavailable
    case destinationNotFresh
    case storeFamilyIncomplete
    case copyStarted
    case copyFailedBeforeCompletion
    case copyCompletionUncertain
    case backupFileVerificationPassed
    case backupSemanticVerificationPassed
    case backupVerified
    case backupContradictory
    case recoveryCopyUsable
    case recoveryCopyUnusable
    case manualReviewRequired
}

enum ScoreKeepMigrationRetryClassification: String, CaseIterable, Codable, Hashable, Sendable {
    case noRetryRequired
    case retryPreflightWithSameOperationIdentity
    case reuseVerifiedBackup
    case retryRequiresFreshTargetCopy
    case retryProhibited
    case doNotRetryMigration
}

enum ScoreKeepMigrationRecoveryRequirement: String, CaseIterable, Codable, Hashable, Sendable {
    case noRecoveryRequired
    case retryPreflightWithSameOperationIdentity
    case reuseVerifiedBackup
    case discardIncompleteTestOwnedBackup
    case discardIncompleteDisposableTarget
    case verifyExistingTarget
    case restoreFromVerifiedBackup
    case requireManualReview
    case unsupportedAutomaticRecovery
    case doNotReopenThroughLegacy
    case doNotRetryMigration
    case writesRemainProhibited
}

enum ScoreKeepMigrationJournalError: Error, Equatable {
    case missingJournal
    case decodingFailed
    case unsupportedJournalVersion(Int)
    case phaseRegression(from: ScoreKeepMigrationJournalPhase, to: ScoreKeepMigrationJournalPhase)
    case conflictingOperationIdentity
    case conflictingSourceIdentity
    case completionRequiresVerifiedBackup
    case completionRequiresPostOpenVerification
    case uncertaintyCannotBeErased
    case completedJournalConflictsWithTarget
    case atomicReplacementFailed
    case authorizationRequired
}

struct ScoreKeepMigrationJournalRecord: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var journalSchemaVersion: Int
    var operationIdentity: ScoreKeepMigrationOperationIdentity
    var sourceStoreDiagnosticIdentity: String
    var sourceClassification: ScoreKeepSourceStoreClassification
    var targetSchema: ScoreKeepProposedSchemaSelection
    var phase: ScoreKeepMigrationJournalPhase
    var sourcePreservationDisposition: ScoreKeepSourcePreservationDisposition
    var backupIdentity: String?
    var backupVerificationDisposition: ScoreKeepSourcePreservationDisposition
    var containerConstructionDisposition: ScoreKeepProposedContainerConstructionDisposition?
    var postOpenVerificationDisposition: String
    var completionDisposition: String
    var retryClassification: ScoreKeepMigrationRetryClassification
    var recoveryRequirement: ScoreKeepMigrationRecoveryRequirement
    var disableState: ScoreKeepSchemaRouteDisableState
    var startupOwnership: ScoreKeepStartupOwnershipState
    var diagnosticCodes: [ScoreKeepMigrationJournalDiagnosticCode]
    var transitionGeneration: Int

    static func initial(
        operationIdentity: ScoreKeepMigrationOperationIdentity,
        sourceStoreDiagnosticIdentity: String,
        sourceClassification: ScoreKeepSourceStoreClassification,
        disableState: ScoreKeepSchemaRouteDisableState = .legacyRouteRequired
    ) -> ScoreKeepMigrationJournalRecord {
        ScoreKeepMigrationJournalRecord(
            journalSchemaVersion: currentSchemaVersion,
            operationIdentity: operationIdentity,
            sourceStoreDiagnosticIdentity: sourceStoreDiagnosticIdentity,
            sourceClassification: sourceClassification,
            targetSchema: operationIdentity.targetSchema,
            phase: .noEvidence,
            sourcePreservationDisposition: .required,
            backupIdentity: nil,
            backupVerificationDisposition: .required,
            containerConstructionDisposition: nil,
            postOpenVerificationDisposition: "notStarted",
            completionDisposition: "notStarted",
            retryClassification: .retryPreflightWithSameOperationIdentity,
            recoveryRequirement: .noRecoveryRequired,
            disableState: disableState,
            startupOwnership: .noOwner,
            diagnosticCodes: [],
            transitionGeneration: 0
        )
    }
}

struct ScoreKeepMigrationJournalLoadResult: Sendable {
    let record: ScoreKeepMigrationJournalRecord?
    let error: ScoreKeepMigrationJournalError?
    let diagnosticCodes: [ScoreKeepMigrationJournalDiagnosticCode]
}

struct ScoreKeepMigrationJournalStore {
    let directory: URL
    let fileName: String
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL, fileName: String = "ScoreKeepMigrationJournal.json", fileManager: FileManager = .default) {
        self.directory = directory
        self.fileName = fileName
        self.fileManager = fileManager
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    }

    var journalURL: URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    func load() -> ScoreKeepMigrationJournalLoadResult {
        guard fileManager.fileExists(atPath: journalURL.path) else {
            return ScoreKeepMigrationJournalLoadResult(record: nil, error: nil, diagnosticCodes: [])
        }

        do {
            let data = try Data(contentsOf: journalURL)
            let record = try decoder.decode(ScoreKeepMigrationJournalRecord.self, from: data)
            guard record.journalSchemaVersion == ScoreKeepMigrationJournalRecord.currentSchemaVersion else {
                return ScoreKeepMigrationJournalLoadResult(
                    record: nil,
                    error: .unsupportedJournalVersion(record.journalSchemaVersion),
                    diagnosticCodes: [.journalVersionUnsupported]
                )
            }
            return ScoreKeepMigrationJournalLoadResult(record: record, error: nil, diagnosticCodes: [])
        } catch let error as ScoreKeepMigrationJournalError {
            return ScoreKeepMigrationJournalLoadResult(record: nil, error: error, diagnosticCodes: [.journalUnreadable])
        } catch {
            return ScoreKeepMigrationJournalLoadResult(record: nil, error: .decodingFailed, diagnosticCodes: [.journalUnreadable])
        }
    }

    func save(_ record: ScoreKeepMigrationJournalRecord) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(record)
        let temporaryURL = directory.appendingPathComponent(".\(fileName).\(UUID().uuidString).tmp", isDirectory: false)
        guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw ScoreKeepMigrationJournalError.atomicReplacementFailed
        }
        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            if fileManager.fileExists(atPath: journalURL.path) {
                _ = try fileManager.replaceItemAt(journalURL, withItemAt: temporaryURL, backupItemName: nil, options: [])
            } else {
                try fileManager.moveItem(at: temporaryURL, to: journalURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw ScoreKeepMigrationJournalError.atomicReplacementFailed
        }
    }
}

enum ScoreKeepMigrationJournalTransition {
    static func advance(
        _ record: ScoreKeepMigrationJournalRecord,
        to phase: ScoreKeepMigrationJournalPhase,
        operationIdentity: ScoreKeepMigrationOperationIdentity? = nil,
        sourceStoreDiagnosticIdentity: String? = nil,
        sourceClassification: ScoreKeepSourceStoreClassification? = nil,
        sourcePreservationDisposition: ScoreKeepSourcePreservationDisposition? = nil,
        backupIdentity: String? = nil,
        backupVerificationDisposition: ScoreKeepSourcePreservationDisposition? = nil,
        containerConstructionDisposition: ScoreKeepProposedContainerConstructionDisposition? = nil,
        postOpenVerificationDisposition: String? = nil,
        completionDisposition: String? = nil,
        retryClassification: ScoreKeepMigrationRetryClassification? = nil,
        recoveryRequirement: ScoreKeepMigrationRecoveryRequirement? = nil,
        disableState: ScoreKeepSchemaRouteDisableState? = nil,
        startupOwnership: ScoreKeepStartupOwnershipState? = nil,
        diagnosticCodes: [ScoreKeepMigrationJournalDiagnosticCode] = []
    ) throws -> ScoreKeepMigrationJournalRecord {
        let candidateOperation = operationIdentity ?? record.operationIdentity
        guard candidateOperation == record.operationIdentity else {
            throw ScoreKeepMigrationJournalError.conflictingOperationIdentity
        }
        let candidateSourceIdentity = sourceStoreDiagnosticIdentity ?? record.sourceStoreDiagnosticIdentity
        guard candidateSourceIdentity == record.sourceStoreDiagnosticIdentity else {
            throw ScoreKeepMigrationJournalError.conflictingSourceIdentity
        }
        guard phase >= record.phase || isTerminalOverride(from: record.phase, to: phase) else {
            throw ScoreKeepMigrationJournalError.phaseRegression(from: record.phase, to: phase)
        }
        guard record.phase != .completionUncertain || phase == .completionUncertain || phase == .recoveryRequired || phase == .disabled else {
            throw ScoreKeepMigrationJournalError.uncertaintyCannotBeErased
        }
        if phase == .completionRecorded {
            let backupDisposition = backupVerificationDisposition ?? record.backupVerificationDisposition
            guard backupDisposition == .backupVerified || sourcePreservationDisposition == .notRequiredForNewEmptyStore else {
                throw ScoreKeepMigrationJournalError.completionRequiresVerifiedBackup
            }
            guard (postOpenVerificationDisposition ?? record.postOpenVerificationDisposition) == "passed" else {
                throw ScoreKeepMigrationJournalError.completionRequiresPostOpenVerification
            }
        }

        var next = record
        next.phase = phase
        next.sourceClassification = sourceClassification ?? record.sourceClassification
        next.sourcePreservationDisposition = sourcePreservationDisposition ?? record.sourcePreservationDisposition
        next.backupIdentity = backupIdentity ?? record.backupIdentity
        next.backupVerificationDisposition = backupVerificationDisposition ?? record.backupVerificationDisposition
        next.containerConstructionDisposition = containerConstructionDisposition ?? record.containerConstructionDisposition
        next.postOpenVerificationDisposition = postOpenVerificationDisposition ?? record.postOpenVerificationDisposition
        next.completionDisposition = completionDisposition ?? record.completionDisposition
        next.retryClassification = retryClassification ?? record.retryClassification
        next.recoveryRequirement = recoveryRequirement ?? record.recoveryRequirement
        next.disableState = disableState ?? record.disableState
        next.startupOwnership = startupOwnership ?? record.startupOwnership
        next.diagnosticCodes.append(contentsOf: diagnosticCodes)
        next.transitionGeneration += 1
        return next
    }

    private static func isTerminalOverride(from: ScoreKeepMigrationJournalPhase, to: ScoreKeepMigrationJournalPhase) -> Bool {
        switch to {
        case .failedSafely, .completionUncertain, .recoveryRequired, .disabled:
            return from != .completionRecorded
        case .noEvidence, .preflightStarted, .sourceClassified, .sourcePreservationStarted,
             .backupVerified, .workspaceCreationStarted, .workspaceVerified,
             .migrationAttemptStarted, .containerConstructed, .destinationVerificationPending,
             .postOpenVerificationStarted, .postOpenVerificationPassed, .completionRecorded:
            return false
        }
    }
}

enum ScoreKeepSchemaRouteDisableAuthority {
    static func resolve(
        state: ScoreKeepSchemaRouteDisableState?,
        authorizationEvidence: String?
    ) throws -> ScoreKeepSchemaRouteDisableState {
        guard let state else { return .unsafe }
        if state == .proposedTransitionExplicitlyAuthorized, authorizationEvidence?.isEmpty != false {
            throw ScoreKeepMigrationJournalError.authorizationRequired
        }
        return state
    }
}

enum ScoreKeepStartupOwnershipAuthority {
    static func claim(
        current: ScoreKeepStartupOwnershipState,
        requested: ScoreKeepStartupOwnershipState
    ) -> ScoreKeepStartupOwnershipState {
        switch (current, requested) {
        case (.noOwner, .legacyContainerSelected),
             (.noOwner, .proposedContainerSelected),
             (.noOwner, .migrationInProgress),
             (.noOwner, .recoveryOwner):
            return requested
        case (.released, .legacyContainerSelected),
             (.released, .proposedContainerSelected),
             (.released, .migrationInProgress),
             (.released, .recoveryOwner):
            return requested
        case (let existing, let next) where existing == next:
            return existing
        default:
            return .conflictingOwners
        }
    }
}
