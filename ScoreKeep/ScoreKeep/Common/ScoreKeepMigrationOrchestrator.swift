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
    case afterWorkspaceCreationStarted
    case afterWorkspaceVerification
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
    case workspaceCreationFailed
    case constructionFailed
    case destinationVerificationPending
    case destinationVerified
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
    let failureDiagnosticIdentity: String?
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
    let sourceLocation: ScoreKeepStartupStoreLocation.Kind
    let sourcePreservationAuthorizationScope: ScoreKeepSourcePreservationAuthorizationScope
    let allowIncompleteBackupRemoval: Bool
    let interruptionPoint: ScoreKeepMigrationInterruptionPoint?
    let factoryInjection: ScoreKeepProposedContainerFactoryInjection?
    let semanticRestoreVerifier: ((URL) throws -> Bool)?
    let postOpenVerifier: ((ModelContainer) throws -> Bool)?
    let expectedSourceBaseline: ScoreKeepMigrationBaselineRecord?
    let expectedSourceFamilyIdentity: String?
    let expectedBackupFamilyIdentity: String?

    init(
        operationIdentity: ScoreKeepMigrationOperationIdentity,
        sourceStoreURL: URL,
        backupStoreURL: URL,
        targetStoreURL: URL,
        sourceClassification: ScoreKeepSourceStoreClassification,
        disableState: ScoreKeepSchemaRouteDisableState,
        authorizationEvidence: String?,
        sourceClosureEvidence: ScoreKeepSourceClosureEvidence,
        sourceLocation: ScoreKeepStartupStoreLocation.Kind = .disposableTestStore,
        sourcePreservationAuthorizationScope: ScoreKeepSourcePreservationAuthorizationScope = .testOwnedDisposable,
        allowIncompleteBackupRemoval: Bool = true,
        interruptionPoint: ScoreKeepMigrationInterruptionPoint?,
        factoryInjection: ScoreKeepProposedContainerFactoryInjection?,
        semanticRestoreVerifier: ((URL) throws -> Bool)?,
        postOpenVerifier: ((ModelContainer) throws -> Bool)?,
        expectedSourceBaseline: ScoreKeepMigrationBaselineRecord? = nil,
        expectedSourceFamilyIdentity: String? = nil,
        expectedBackupFamilyIdentity: String? = nil
    ) {
        self.operationIdentity = operationIdentity
        self.sourceStoreURL = sourceStoreURL
        self.backupStoreURL = backupStoreURL
        self.targetStoreURL = targetStoreURL
        self.sourceClassification = sourceClassification
        self.disableState = disableState
        self.authorizationEvidence = authorizationEvidence
        self.sourceClosureEvidence = sourceClosureEvidence
        self.sourceLocation = sourceLocation
        self.sourcePreservationAuthorizationScope = sourcePreservationAuthorizationScope
        self.allowIncompleteBackupRemoval = allowIncompleteBackupRemoval
        self.interruptionPoint = interruptionPoint
        self.factoryInjection = factoryInjection
        self.semanticRestoreVerifier = semanticRestoreVerifier
        self.postOpenVerifier = postOpenVerifier
        self.expectedSourceBaseline = expectedSourceBaseline
        self.expectedSourceFamilyIdentity = expectedSourceFamilyIdentity
        self.expectedBackupFamilyIdentity = expectedBackupFamilyIdentity
    }
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
        if journal.phase < .preflightStarted || journal.disableState != resolvedDisable {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: max(journal.phase, .preflightStarted),
                disableState: resolvedDisable,
                diagnosticCodes: resolvedDisable.failsClosed ? [.disableStateActive] : []
            )
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterDisableStateResolution {
            return interrupted(journal)
        }
        guard resolvedDisable == .proposedTransitionExplicitlyAuthorized else {
            return classified(.disabled, journal: journal, container: nil, diagnostics: [.disableStateActive])
        }

        let ownership = ScoreKeepStartupOwnershipAuthority.claim(current: journal.startupOwnership, requested: .migrationInProgress)
        if journal.startupOwnership != ownership {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: max(journal.phase, .preflightStarted),
                startupOwnership: ownership,
                diagnosticCodes: ownership == .conflictingOwners ? [.ownershipConflict] : []
            )
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterOwnershipClaim {
            return interrupted(journal)
        }
        guard ownership != .conflictingOwners else {
            return classified(.ownershipConflict, journal: journal, container: nil, diagnostics: [.ownershipConflict])
        }

        if journal.phase < .sourceClassified {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .sourceClassified,
                sourceClassification: input.sourceClassification
            )
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterSourceClassification {
            return interrupted(journal)
        }

        let preservationRequired = input.sourceClassification.requiresMigration
        if preservationRequired && journal.phase < .backupVerified {
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
                        sourceLocation: input.sourceLocation,
                        sourceClosureEvidence: input.sourceClosureEvidence,
                        allowIncompleteTestOwnedBackupRemoval: input.allowIncompleteBackupRemoval,
                        semanticRestoreVerifier: input.semanticRestoreVerifier,
                        authorizationScope: input.sourcePreservationAuthorizationScope
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
                return classified(
                    .sourcePreservationFailed,
                    journal: journal,
                    container: nil,
                    diagnostics: [.recoveryRequired],
                    failureDiagnosticIdentity: ScoreKeepSourcePreservationErrorIdentity.make(error)
                )
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
        } else if journal.phase < .backupVerified {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .backupVerified,
                sourcePreservationDisposition: .notRequiredForNewEmptyStore,
                backupVerificationDisposition: .notRequiredForNewEmptyStore,
                retryClassification: .noRetryRequired
            )
            try journalStore.save(journal)
        }

        if preservationRequired && journal.phase < .workspaceVerified {
            if journal.phase < .workspaceCreationStarted {
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .workspaceCreationStarted,
                    retryClassification: .retryRequiresFreshTargetCopy
                )
                try journalStore.save(journal)
            }
            if input.interruptionPoint == .afterWorkspaceCreationStarted {
                return interrupted(journal)
            }

            do {
                let workspace = try copyStoreFamily(
                    from: input.backupStoreURL,
                    to: input.targetStoreURL,
                    replacingIncompleteDestination: true
                )
                guard workspace.isComplete else {
                    throw ScoreKeepStoreFamilyError.primaryStoreMissing
                }
            } catch {
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .failedSafely,
                    recoveryRequirement: .discardIncompleteDisposableTarget,
                    diagnosticCodes: [.workspaceCopyFailed]
                )
                try journalStore.save(journal)
                return classified(
                    .workspaceCreationFailed,
                    journal: journal,
                    container: nil,
                    diagnostics: [.workspaceCopyFailed]
                )
            }

            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .workspaceVerified,
                retryClassification: .retryRequiresFreshTargetCopy
            )
            try journalStore.save(journal)
            if input.interruptionPoint == .afterWorkspaceVerification {
                return interrupted(journal)
            }
        }

        if journal.phase < .migrationAttemptStarted {
            journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .migrationAttemptStarted)
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterMigrationAttemptRecording || input.interruptionPoint == .afterContainerConstructionBegins {
            return interrupted(journal)
        }

        let factoryResult = ScoreKeepProposedContainerFactory.construct(
            ScoreKeepProposedContainerFactoryInput(
                storeLocation: .disposableMigrationTarget(url: input.targetStoreURL, requiresFreshDestination: false),
                writabilityMode: .writable,
                startupIntent: .isolatedVerification,
                sourceClassification: input.sourceClassification,
                routeChoice: .proposedV3EligibleForIsolatedVerification,
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

        if journal.phase < .containerConstructed {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .containerConstructed,
                containerConstructionDisposition: factoryResult.disposition
            )
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterContainerConstructionReturns {
            return interrupted(journal, container: container)
        }

        if input.sourceClassification == .existingProposedV2Store || input.sourceClassification == .convertedProposedV2Store {
            if journal.phase < .destinationVerificationInProgress {
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .destinationVerificationInProgress,
                    postOpenVerificationDisposition: "startedTask3.22D",
                    recoveryRequirement: .verifyExistingTarget
                )
                try journalStore.save(journal)
            }
            if input.interruptionPoint == .afterPostOpenVerificationStarts {
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .destinationVerificationFailed,
                    postOpenVerificationDisposition: "interruptedTask3.22D",
                    recoveryRequirement: .verifyExistingTarget,
                    diagnosticCodes: [.destinationVerificationInterrupted]
                )
                try journalStore.save(journal)
                return classified(.verificationFailed, journal: journal, container: nil, diagnostics: [.destinationVerificationInterrupted])
            }

            let verification = ScoreKeepDestinationVerifier.verify(
                container: container,
                input: ScoreKeepDestinationVerificationInput(
                    operationIdentity: input.operationIdentity,
                    candidateStoreURL: input.targetStoreURL,
                    sourceStoreURL: input.sourceStoreURL,
                    backupStoreURL: input.backupStoreURL,
                    expectedSourceBaseline: input.expectedSourceBaseline,
                    expectedSourceFamilyIdentity: input.expectedSourceFamilyIdentity,
                    expectedBackupFamilyIdentity: input.expectedBackupFamilyIdentity,
                    candidateAssessmentOverride: nil
                )
            )
            guard verification.passed else {
                let diagnostic = verification.diagnosticCode ?? .postOpenVerificationFailed
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .destinationVerificationFailed,
                    postOpenVerificationDisposition: verification.evidence.journalSummary,
                    recoveryRequirement: .verifyExistingTarget,
                    diagnosticCodes: [diagnostic]
                )
                try journalStore.save(journal)
                return classified(.verificationFailed, journal: journal, container: nil, diagnostics: [diagnostic])
            }
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .destinationMetadataVerified,
                postOpenVerificationDisposition: "metadataVerifiedTask3.22D"
            )
            try journalStore.save(journal)
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .legacyReconciliationVerified,
                postOpenVerificationDisposition: "legacyReconciliationVerifiedTask3.22D"
            )
            try journalStore.save(journal)
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .canonicalZeroVerified,
                postOpenVerificationDisposition: "canonicalZeroVerifiedTask3.22D"
            )
            try journalStore.save(journal)
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .destinationVerificationSucceeded,
                postOpenVerificationDisposition: verification.evidence.journalSummary,
                completionDisposition: "candidateEligibleForLaterAcceptance",
                retryClassification: .noRetryRequired,
                recoveryRequirement: .restoreFromVerifiedBackup,
                startupOwnership: .released
            )
            try journalStore.save(journal)
            return classified(.destinationVerified, journal: journal, container: nil, diagnostics: [])
        }

        if journal.phase < .postOpenVerificationStarted {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .postOpenVerificationStarted,
                postOpenVerificationDisposition: "started"
            )
            try journalStore.save(journal)
        }
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

        if journal.phase < .postOpenVerificationPassed {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .postOpenVerificationPassed,
                postOpenVerificationDisposition: "passed"
            )
            try journalStore.save(journal)
        }
        if input.interruptionPoint == .afterPostOpenVerificationPasses || input.interruptionPoint == .afterCompletionRecordingStarts {
            return interrupted(journal, container: container)
        }

        if journal.phase < .completionRecorded {
            journal = try ScoreKeepMigrationJournalTransition.advance(
                journal,
                to: .completionRecorded,
                completionDisposition: "sidecarCompletionRecorded",
                retryClassification: .noRetryRequired,
                recoveryRequirement: .noRecoveryRequired
            )
            try journalStore.save(journal)
        }
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
        case .workspaceCreationStarted, .workspaceVerified:
            return .discardIncompleteDisposableTarget
        case .migrationAttemptStarted:
            return .discardIncompleteDisposableTarget
        case .containerConstructed, .destinationVerificationPending,
             .destinationVerificationInProgress, .destinationMetadataVerified,
             .legacyReconciliationVerified, .canonicalZeroVerified,
             .postOpenVerificationStarted, .postOpenVerificationPassed:
            return .verifyExistingTarget
        case .destinationVerificationSucceeded:
            return .restoreFromVerifiedBackup
        case .destinationVerificationFailed:
            return record.recoveryRequirement
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
        diagnostics: [ScoreKeepMigrationJournalDiagnosticCode],
        failureDiagnosticIdentity: String? = nil
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
                routeChoice: .proposedV3PreparedButDisabled,
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
            diagnostics: diagnostics,
            failureDiagnosticIdentity: failureDiagnosticIdentity
        )
    }

    @discardableResult
    private static func copyStoreFamily(
        from sourceURL: URL,
        to destinationURL: URL,
        replacingIncompleteDestination: Bool = false,
        fileManager: FileManager = .default
    ) throws -> ScoreKeepStoreFamilyDescriptor {
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        guard sourceURL.deletingLastPathComponent().standardizedFileURL != destinationDirectory.standardizedFileURL else {
            throw ScoreKeepStoreFamilyError.backupDirectoryMatchesSource
        }
        if fileManager.fileExists(atPath: destinationDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(atPath: destinationDirectory.path)
            if contents.isEmpty == false {
                guard replacingIncompleteDestination else {
                    throw ScoreKeepStoreFamilyError.backupDirectoryNotFresh
                }
                try fileManager.removeItem(at: destinationDirectory)
                try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
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
        let copied = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: destinationURL, fileManager: fileManager)
        guard try ScoreKeepStoreFamilyDiscovery.validateBackup(
            source: family,
            backup: copied,
            sourceURL: sourceURL,
            backupURL: destinationURL
        ) else {
            throw ScoreKeepStoreFamilyError.backupDirectoryNotFresh
        }
        return copied
    }
}

private func max(_ lhs: ScoreKeepMigrationJournalPhase, _ rhs: ScoreKeepMigrationJournalPhase) -> ScoreKeepMigrationJournalPhase {
    lhs < rhs ? rhs : lhs
}
