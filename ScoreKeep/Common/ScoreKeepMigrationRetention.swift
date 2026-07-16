import Foundation

enum ScoreKeepMigrationRetentionCategory: String, CaseIterable, Hashable, Sendable {
    case activeMigrationJournal
    case completedMigrationJournal
    case uncertainMigrationJournal
    case recoveryRequiredJournal
    case verifiedSourceBackup
    case backupPendingVerification
    case failedIncompleteBackup
    case temporaryTarget
    case incompleteTarget
    case verifiedProposedV2ActiveStore
    case recoveryCopy
    case diagnosticState
    case manualReviewEvidence
    case cleanupEligible
    case cleanupProhibited
    case unknownArtifact
}

enum ScoreKeepMigrationArtifactRole: String, CaseIterable, Hashable, Sendable {
    case activeSource
    case activeTarget
    case journal
    case verifiedBackup
    case pendingBackup
    case temporaryTarget
    case incompleteTarget
    case recoveryCopy
    case diagnosticState
    case manualReviewEvidence
    case unknown
}

enum ScoreKeepMigrationVerificationStatus: String, CaseIterable, Hashable, Sendable {
    case notApplicable
    case pending
    case verified
    case failed
    case uncertain
}

enum ScoreKeepMigrationCleanupAuthorization: String, CaseIterable, Hashable, Sendable {
    case absent
    case testOwnedExplicit
    case productionProhibited
}

enum ScoreKeepMigrationCleanupAssessmentDisposition: String, CaseIterable, Hashable, Sendable {
    case retain
    case eligibleForCleanup
    case cleanupProhibited
    case manualReviewRequired
    case activeSource
    case activeTarget
    case verifiedBackupStillRequired
    case incompleteTestOwnedArtifactRemovable
    case unknownArtifactProhibited
    case pathOutsideAuthorizedRootProhibited
    case wrongOperationIdentityProhibited
}

struct ScoreKeepMigrationCleanupAssessmentInput: Hashable, Sendable {
    let artifactURL: URL
    let artifactRole: ScoreKeepMigrationArtifactRole
    let retentionCategory: ScoreKeepMigrationRetentionCategory
    let journalPhase: ScoreKeepMigrationJournalPhase
    let disableState: ScoreKeepSchemaRouteDisableState
    let startupOwnership: ScoreKeepStartupOwnershipState
    let verificationStatus: ScoreKeepMigrationVerificationStatus
    let retentionGeneration: Int
    let authorization: ScoreKeepMigrationCleanupAuthorization
    let activeOperationIdentity: ScoreKeepMigrationOperationIdentity?
    let artifactOperationIdentity: ScoreKeepMigrationOperationIdentity?
    let authorizedMigrationRoot: URL
    let testOwnedRoot: URL?
}

struct ScoreKeepMigrationCleanupAssessment: Hashable, Sendable {
    let disposition: ScoreKeepMigrationCleanupAssessmentDisposition
    let diagnosticCode: String

    var mayDelete: Bool {
        disposition == .eligibleForCleanup || disposition == .incompleteTestOwnedArtifactRemovable
    }
}

enum ScoreKeepMigrationRetentionPolicy {
    static func category(for role: ScoreKeepMigrationArtifactRole, journalPhase: ScoreKeepMigrationJournalPhase, verificationStatus: ScoreKeepMigrationVerificationStatus) -> ScoreKeepMigrationRetentionCategory {
        switch (role, journalPhase, verificationStatus) {
        case (.journal, .completionRecorded, _): return .completedMigrationJournal
        case (.journal, .completionUncertain, _): return .uncertainMigrationJournal
        case (.journal, .recoveryRequired, _): return .recoveryRequiredJournal
        case (.journal, _, _): return .activeMigrationJournal
        case (.verifiedBackup, _, .verified): return .verifiedSourceBackup
        case (.pendingBackup, _, .pending): return .backupPendingVerification
        case (.pendingBackup, _, .failed): return .failedIncompleteBackup
        case (.temporaryTarget, _, _): return .temporaryTarget
        case (.incompleteTarget, _, _): return .incompleteTarget
        case (.activeTarget, .completionRecorded, .verified): return .verifiedProposedV2ActiveStore
        case (.recoveryCopy, _, _): return .recoveryCopy
        case (.diagnosticState, _, _): return .diagnosticState
        case (.manualReviewEvidence, _, _): return .manualReviewEvidence
        case (.unknown, _, _): return .unknownArtifact
        case (.activeSource, _, _): return .cleanupProhibited
        case (.activeTarget, _, _): return .cleanupProhibited
        case (.verifiedBackup, _, _): return .verifiedSourceBackup
        case (.pendingBackup, _, _): return .backupPendingVerification
        }
    }
}

enum ScoreKeepMigrationCleanupAssessor {
    static func assess(_ input: ScoreKeepMigrationCleanupAssessmentInput, fileManager: FileManager = .default) -> ScoreKeepMigrationCleanupAssessment {
        let pathValidation = ScoreKeepProductionPathValidator.validateCleanupCandidate(
            input.artifactURL,
            layout: ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: input.authorizedMigrationRoot.deletingLastPathComponent()),
            testOwnedRoot: input.testOwnedRoot,
            fileManager: fileManager
        )
        if pathValidation.disposition == .cleanupCandidateOutsideMigrationRoot {
            return result(.pathOutsideAuthorizedRootProhibited)
        }
        if pathValidation.disposition == .productionPathRejectedForTestCleanup {
            return result(.pathOutsideAuthorizedRootProhibited)
        }
        if let active = input.activeOperationIdentity, let artifact = input.artifactOperationIdentity, active != artifact {
            return result(.wrongOperationIdentityProhibited)
        }
        switch input.artifactRole {
        case .activeSource:
            return result(.activeSource)
        case .activeTarget:
            return result(.activeTarget)
        case .unknown:
            return result(.unknownArtifactProhibited)
        case .verifiedBackup:
            return result(.verifiedBackupStillRequired)
        case .journal:
            return input.journalPhase == .completionRecorded && input.retentionGeneration > 0 ? result(.retain) : result(.retain)
        case .recoveryCopy, .manualReviewEvidence:
            return result(.manualReviewRequired)
        case .pendingBackup:
            if input.verificationStatus == .failed && input.authorization == .testOwnedExplicit {
                return result(.incompleteTestOwnedArtifactRemovable)
            }
            return result(.retain)
        case .temporaryTarget, .incompleteTarget:
            guard input.authorization == .testOwnedExplicit else { return result(.cleanupProhibited) }
            guard input.journalPhase != .completionUncertain && input.journalPhase != .recoveryRequired else { return result(.manualReviewRequired) }
            return result(.incompleteTestOwnedArtifactRemovable)
        case .diagnosticState:
            return result(.retain)
        }
    }

    private static func result(_ disposition: ScoreKeepMigrationCleanupAssessmentDisposition) -> ScoreKeepMigrationCleanupAssessment {
        ScoreKeepMigrationCleanupAssessment(disposition: disposition, diagnosticCode: "cleanup.\(disposition.rawValue)")
    }
}

enum ScoreKeepMigrationCleanupExecutionDisposition: String, CaseIterable, Hashable, Sendable {
    case removed
    case retained
    case prohibited
    case failed
    case partialFailure
}

struct ScoreKeepMigrationCleanupExecutionResult: Hashable, Sendable {
    let disposition: ScoreKeepMigrationCleanupExecutionDisposition
    let assessment: ScoreKeepMigrationCleanupAssessment
    let diagnosticCode: String
}

enum ScoreKeepMigrationCleanupExecutor {
    static func removeAssessedArtifact(url: URL, assessment: ScoreKeepMigrationCleanupAssessment, fileManager: FileManager = .default) -> ScoreKeepMigrationCleanupExecutionResult {
        guard assessment.mayDelete else {
            return ScoreKeepMigrationCleanupExecutionResult(disposition: .prohibited, assessment: assessment, diagnosticCode: "cleanup.prohibited")
        }
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return ScoreKeepMigrationCleanupExecutionResult(disposition: .removed, assessment: assessment, diagnosticCode: "cleanup.removed")
        } catch {
            return ScoreKeepMigrationCleanupExecutionResult(disposition: .failed, assessment: assessment, diagnosticCode: "cleanup.failed")
        }
    }
}
