import Foundation
import SwiftData

enum ScoreKeepMigrationInterruptionPoint: String, CaseIterable, Hashable, Sendable {
    case afterJournalCreation
    case afterDisableStateResolution
    case afterOwnershipClaim
    case afterSourceClassification
    case afterBackupCopyStart
    case afterBackupCopyCompletion
    case afterBackupVerification
    case afterMigrationAttemptRecording
    case afterContainerConstructionBegins
    case afterContainerConstructionReturns
    case afterPostOpenVerificationStarts
    case afterPostOpenVerificationPasses
    case afterCompletionRecordingStarts
    case afterCompletionRecordingSucceeds
    case afterOwnershipFinalization
}

enum ScoreKeepMigrationOrchestratorDisposition: String, CaseIterable, Hashable, Sendable {
    case completed
    case interrupted
    case disabled
    case ownershipConflict
    case sourcePreservationFailed
    case constructionFailed
    case verificationFailed
    case completionEvidenceFailed
    case recoveryRequired
    case writesProhibited
}

struct ScoreKeepMigrationOrchestratorResult {
    let disposition: ScoreKeepMigrationOrchestratorDisposition
    let journal: ScoreKeepMigrationJournalRecord
    let container: ModelContainer?
    let writeReadiness: ScoreKeepWriteReadinessResult
    let recoveryRequirement: ScoreKeepMigrationRecoveryRequirement
    let diagnostics: [ScoreKeepMigrationJournalDiagnosticCode]
}

struct ScoreKeepMigrationOrchestratorInput {
    let operationIdentity: ScoreKeepMigrationOperationIdentity
    let sourceStoreURL: URL
    let backupStoreURL: URL
    let targetStoreURL: URL
    let sourceClassification: ScoreKeepSourceStoreClassification
    let disableState: ScoreKeepSchemaRouteDisableState
    let authorizationEvidence: String?
    let sourceClosureEvidence: ScoreKeepSourceClosureEvidence
    let interruptionPoint: ScoreKeepMigrationInterruptionPoint?
    let factoryInjection: ScoreKeepProposedContainerFactoryInjection?
    let semanticRestoreVerifier: ((URL) throws -> Bool)?
    let postOpenVerifier: ((ModelContainer) throws -> Bool)?
}

@MainActor
enum ScoreKeepMigrationOrchestrator {
    static func run(
        input: ScoreKeepMigrationOrchestratorInput,
        journalStore: ScoreKeepMigrationJournalStore
    ) throws -> ScoreKeepMigrationOrchestratorResult {
        let loaded = journalStore.load()
        var journal = loaded.record ?? ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: input.operationIdentity,
            sourceStoreDiagnosticIdentity: input.operationIdentity.sourceStoreIdentity,
            sourceClassification: input.sourceClassification,
            disableState: input.disableState
        )

        if loaded.record == nil {
            journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .preflightStarted)
            try journalStore.save(journal)
            if input.interruptionPoint == .afterJournalCreation {
                return interrupted(journal)
            }
        }

        let resolvedDisable = try ScoreKeepSchemaRouteDisableAuthority.resolve(
            state: input.disableState,
            authorizationEvidence: input.authorizationEvidence
        )
        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: max(journal.phase, .preflightStarted),
            disableState: resolvedDisable,
            diagnosticCodes: resolvedDisable.failsClosed ? [.disableStateActive] : []
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterDisableStateResolution {
            return interrupted(journal)
        }
        guard resolvedDisable == .proposedTransitionExplicitlyAuthorized else {
            return classified(.disabled, journal: journal, container: nil, diagnostics: [.disableStateActive])
        }

        let ownership = ScoreKeepStartupOwnershipAuthority.claim(current: journal.startupOwnership, requested: .migrationInProgress)
        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: max(journal.phase, .preflightStarted),
            startupOwnership: ownership,
            diagnosticCodes: ownership == .conflictingOwners ? [.ownershipConflict] : []
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterOwnershipClaim {
            return interrupted(journal)
        }
        guard ownership != .conflictingOwners else {
            return classified(.ownershipConflict, journal: journal, container: nil, diagnostics: [.ownershipConflict])
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .sourceClassified,
            sourceClassification: input.sourceClassification
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterSourceClassification {
            return interrupted(journal)
        }

        let preservationRequired = input.sourceClassification.requiresMigration
        if preservationRequired {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .sourcePreservationStarted,
                sourcePreservationDisposition: .started
            )
            try journalStore.save(journal)
            if input.interruptionPoint == .afterBackupCopyStart {
                return interrupted(journal)
            }

            let preservation: ScoreKeepSourcePreservationEvidence
            do {
                preservation = try ScoreKeepSourcePreservationExecutor.preserve(
                    ScoreKeepSourcePreservationRequest(
                        sourceStoreURL: input.sourceStoreURL,
                        backupStoreURL: input.backupStoreURL,
                        sourceLocation: .disposableTestStore,
                        sourceClosureEvidence: input.sourceClosureEvidence,
                        allowIncompleteTestOwnedBackupRemoval: true,
                        semanticRestoreVerifier: input.semanticRestoreVerifier
                    )
                )
            } catch {
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .recoveryRequired,
                    recoveryRequirement: .writesRemainProhibited,
                    diagnosticCodes: [.recoveryRequired]
                )
                try journalStore.save(journal)
                return classified(.sourcePreservationFailed, journal: journal, container: nil, diagnostics: [.recoveryRequired])
            }

            if input.interruptionPoint == .afterBackupCopyCompletion {
                return interrupted(journal)
            }
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .backupVerified,
                sourcePreservationDisposition: preservation.disposition,
                backupIdentity: preservation.backupIdentity,
                backupVerificationDisposition: .backupVerified,
                retryClassification: .reuseVerifiedBackup
            )
            try journalStore.save(journal)
            if input.interruptionPoint == .afterBackupVerification {
                return interrupted(journal)
            }
        } else {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .backupVerified,
                sourcePreservationDisposition: .notRequiredForNewEmptyStore,
                backupVerificationDisposition: .notRequiredForNewEmptyStore,
                retryClassification: .noRetryRequired
            )
            try journalStore.save(journal)
        }

        if preservationRequired {
            try copyStoreFamily(from: input.backupStoreURL, to: input.targetStoreURL)
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .migrationAttemptStarted)
        try journalStore.save(journal)
        if input.interruptionPoint == .afterMigrationAttemptRecording || input.interruptionPoint == .afterContainerConstructionBegins {
            return interrupted(journal)
        }

        let factoryResult = ScoreKeepProposedContainerFactory.construct(
            ScoreKeepProposedContainerFactoryInput(
                storeLocation: .disposableMigrationTarget(url: input.targetStoreURL, requiresFreshDestination: false),
                writabilityMode: .writable,
                startupIntent: .isolatedVerification,
                sourceClassification: input.sourceClassification,
                routeChoice: .proposedV2EligibleForIsolatedVerification,
                failureInjection: input.factoryInjection
            )
        )
        guard let container = factoryResult.container else {
            let diagnostic: ScoreKeepMigrationJournalDiagnosticCode = factoryResult.disposition == .migrationCompletionUncertain ? .constructionCompletionUncertain : .proposedContainerConstructionFailed
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: factoryResult.disposition == .migrationCompletionUncertain ? .completionUncertain : .failedSafely,
                containerConstructionDisposition: factoryResult.disposition,
                recoveryRequirement: .writesRemainProhibited,
                diagnosticCodes: [diagnostic]
            )
            try journalStore.save(journal)
            return classified(.constructionFailed, journal: journal, container: nil, diagnostics: [diagnostic])
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .containerConstructed,
            containerConstructionDisposition: factoryResult.disposition
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterContainerConstructionReturns {
            return interrupted(journal, container: container)
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .postOpenVerificationStarted,
            postOpenVerificationDisposition: "started"
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterPostOpenVerificationStarts {
            return interrupted(journal, container: container)
        }

        let postOpenPassed = try input.postOpenVerifier?(container) ?? true
        guard postOpenPassed else {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .recoveryRequired,
                postOpenVerificationDisposition: "failed",
                recoveryRequirement: .verifyExistingTarget,
                diagnosticCodes: [.postOpenVerificationFailed]
            )
            try journalStore.save(journal)
            return classified(.verificationFailed, journal: journal, container: container, diagnostics: [.postOpenVerificationFailed])
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .postOpenVerificationPassed,
            postOpenVerificationDisposition: "passed"
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterPostOpenVerificationPasses || input.interruptionPoint == .afterCompletionRecordingStarts {
            return interrupted(journal, container: container)
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .completionRecorded,
            completionDisposition: "sidecarCompletionRecorded",
            retryClassification: .noRetryRequired,
            recoveryRequirement: .noRecoveryRequired
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterCompletionRecordingSucceeds {
            return interrupted(journal, container: container)
        }

        journal = try ScoreKeepMigrationJournalTransition.advance(
            journal,
            to: .completionRecorded,
            startupOwnership: .released
        )
        try journalStore.save(journal)
        if input.interruptionPoint == .afterOwnershipFinalization {
            return interrupted(journal, container: container)
        }

        return classified(.completed, journal: journal, container: container, diagnostics: [])
    }

    static func reconcile(_ record: ScoreKeepMigrationJournalRecord?) -> ScoreKeepMigrationRecoveryRequirement {
        guard let record else { return .retryPreflightWithSameOperationIdentity }
        switch record.phase {
        case .noEvidence, .preflightStarted, .sourceClassified, .sourcePreservationStarted:
            return .retryPreflightWithSameOperationIdentity
        case .backupVerified:
            return .reuseVerifiedBackup
        case .migrationAttemptStarted:
            return .discardIncompleteDisposableTarget
        case .containerConstructed, .postOpenVerificationStarted, .postOpenVerificationPassed:
            return .verifyExistingTarget
        case .completionRecorded:
            return .noRecoveryRequired
        case .failedSafely:
            return .discardIncompleteDisposableTarget
        case .completionUncertain:
            return .requireManualReview
        case .recoveryRequired:
            return record.recoveryRequirement
        case .disabled:
            return .writesRemainProhibited
        }
    }

    private static func interrupted(
        _ journal: ScoreKeepMigrationJournalRecord,
        container: ModelContainer? = nil
    ) -> ScoreKeepMigrationOrchestratorResult {
        classified(.interrupted, journal: journal, container: container, diagnostics: [])
    }

    private static func classified(
        _ disposition: ScoreKeepMigrationOrchestratorDisposition,
        journal: ScoreKeepMigrationJournalRecord,
        container: ModelContainer?,
        diagnostics: [ScoreKeepMigrationJournalDiagnosticCode]
    ) -> ScoreKeepMigrationOrchestratorResult {
        let readiness = ScoreKeepWriteReadinessEvaluator.evaluate(
            ScoreKeepWriteReadinessInput(
                sourceClassification: journal.sourceClassification,
                constructionSucceeded: journal.containerConstructionDisposition != nil,
                requiredMigrationCompleted: journal.phase == .completionRecorded,
                postOpenVerificationPassed: journal.postOpenVerificationDisposition == "passed",
                completionEvidenceReconciled: journal.completionDisposition == "sidecarCompletionRecorded",
                hasUncertainty: journal.phase == .completionUncertain,
                recoveryRequired: journal.recoveryRequirement != .noRecoveryRequired,
                routeChoice: .proposedV2PreparedButDisabled,
                proposedSchemaActive: false,
                storeIsWritable: false,
                oneWriterPolicyAvailable: journal.startupOwnership != .conflictingOwners,
                diagnosticsIdentifyAuthority: true,
                productionCutoverApprovalSupplied: false
            )
        )
        return ScoreKeepMigrationOrchestratorResult(
            disposition: disposition,
            journal: journal,
            container: container,
            writeReadiness: readiness,
            recoveryRequirement: reconcile(journal),
            diagnostics: diagnostics
        )
    }

    private static func copyStoreFamily(from sourceURL: URL, to destinationURL: URL, fileManager: FileManager = .default) throws {
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: destinationDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(atPath: destinationDirectory.path)
            guard contents.isEmpty else {
                throw ScoreKeepStoreFamilyError.backupDirectoryNotFresh
            }
        } else {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }
        let family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL, fileManager: fileManager)
        for member in family.members {
            let sourceMemberURL = sourceURL.deletingLastPathComponent().appendingPathComponent(member.fileName)
            let destinationMemberURL = destinationDirectory.appendingPathComponent(member.fileName)
            try fileManager.copyItem(at: sourceMemberURL, to: destinationMemberURL)
        }
    }
}

private func max(_ lhs: ScoreKeepMigrationJournalPhase, _ rhs: ScoreKeepMigrationJournalPhase) -> ScoreKeepMigrationJournalPhase {
    lhs < rhs ? rhs : lhs
}
