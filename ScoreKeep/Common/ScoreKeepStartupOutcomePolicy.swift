import Foundation

enum ScoreKeepStartupPresentationCode: String, CaseIterable, Hashable, Sendable {
    case legacyNormal
    case proposedPreparedDisabled
    case capacityInsufficient
    case capacityUnavailable
    case protectionUnavailable
    case sourceBackupRequired
    case backupVerificationFailed
    case migrationReady
    case migrationInProgress
    case migrationInterrupted
    case proposedContainerConstructed
    case verificationPending
    case migrationCompleted
    case completionUncertain
    case recoveryRequired
    case proposedTemporarilyDisabled
    case readOnlyRecordsAvailable
    case recordsUnavailable
    case retryPermitted
    case retryProhibited
    case applicationRestartRequired
    case supportManualReviewAppropriate
    case fatalConfigurationDefect
}

struct ScoreKeepStartupDiagnosticPresentation: Hashable, Sendable {
    let stableDiagnosticCode: String
    let disposition: ScoreKeepStartupPresentationCode
    let migrationPhase: ScoreKeepStartupMigrationPhase
    let recordsAvailable: Bool
    let writesDisabled: Bool
    let retrySafe: Bool
    let recoveryRequired: Bool
    let backupVerified: Bool
    let storageInsufficient: Bool
    let deviceUnlockOrFileAvailabilityRequired: Bool
    let applicationRestartAppropriate: Bool
    let supportInformationAppropriate: Bool
}

struct ScoreKeepStartupWorkflowPolicy: Hashable, Sendable {
    let mayShowApplicationContent: Bool
    let mayReadRecords: Bool
    let mayWriteRecords: Bool
    let mayBeginScoring: Bool
    let mayBeginImports: Bool
    let mayBeginTeamCreation: Bool
    let mustRemainOnStartupOrRecoverySurface: Bool
    let mustPreserveEnteredWorkflowState: Bool
    let mayOfferRetry: Bool
    let retryMustReuseSameMigrationIdentity: Bool
    let legacyFallbackProhibited: Bool
    let diagnosticsMustBeAvailable: Bool
    let backupMustBeRetained: Bool
}

enum ScoreKeepStartupOutcomePolicy {
    static func presentation(for code: ScoreKeepStartupPresentationCode) -> ScoreKeepStartupDiagnosticPresentation {
        let migrationPhase: ScoreKeepStartupMigrationPhase
        switch code {
        case .legacyNormal, .proposedPreparedDisabled: migrationPhase = .notAssessed
        case .migrationReady: migrationPhase = .migrationPermitted
        case .migrationInProgress: migrationPhase = .preflightInProgress
        case .migrationInterrupted: migrationPhase = .interrupted
        case .proposedContainerConstructed: migrationPhase = .containerConstructed
        case .verificationPending: migrationPhase = .postOpenVerificationRequired
        case .migrationCompleted: migrationPhase = .completed
        case .completionUncertain: migrationPhase = .completionUncertain
        case .recoveryRequired: migrationPhase = .recoveryRequired
        case .readOnlyRecordsAvailable: migrationPhase = .readOnly
        case .capacityInsufficient, .capacityUnavailable, .protectionUnavailable, .sourceBackupRequired, .backupVerificationFailed, .proposedTemporarilyDisabled, .recordsUnavailable, .retryPermitted, .retryProhibited, .applicationRestartRequired, .supportManualReviewAppropriate, .fatalConfigurationDefect:
            migrationPhase = .writesProhibited
        }
        return ScoreKeepStartupDiagnosticPresentation(
            stableDiagnosticCode: "startup.\(code.rawValue)",
            disposition: code,
            migrationPhase: migrationPhase,
            recordsAvailable: [.legacyNormal, .proposedPreparedDisabled, .migrationCompleted, .readOnlyRecordsAvailable].contains(code),
            writesDisabled: code != .legacyNormal && code != .migrationCompleted,
            retrySafe: code == .retryPermitted || code == .migrationInterrupted,
            recoveryRequired: code == .recoveryRequired || code == .completionUncertain || code == .supportManualReviewAppropriate,
            backupVerified: [.migrationReady, .migrationInProgress, .migrationInterrupted, .proposedContainerConstructed, .verificationPending, .migrationCompleted, .completionUncertain, .recoveryRequired, .readOnlyRecordsAvailable].contains(code),
            storageInsufficient: code == .capacityInsufficient,
            deviceUnlockOrFileAvailabilityRequired: code == .protectionUnavailable,
            applicationRestartAppropriate: code == .applicationRestartRequired,
            supportInformationAppropriate: [.supportManualReviewAppropriate, .recoveryRequired, .completionUncertain, .fatalConfigurationDefect].contains(code)
        )
    }

    static func workflow(for code: ScoreKeepStartupPresentationCode) -> ScoreKeepStartupWorkflowPolicy {
        switch code {
        case .legacyNormal:
            return policy(show: true, read: true, write: true, scoring: true, imports: true, team: true, surface: false, preserve: false, retry: false, sameID: false, noLegacy: false, diagnostics: false, backup: false)
        case .proposedPreparedDisabled:
            return policy(show: true, read: true, write: false, scoring: false, imports: false, team: false, surface: false, preserve: true, retry: false, sameID: false, noLegacy: false, diagnostics: true, backup: false)
        case .migrationCompleted:
            return policy(show: true, read: true, write: true, scoring: true, imports: true, team: true, surface: false, preserve: true, retry: false, sameID: false, noLegacy: true, diagnostics: true, backup: true)
        case .readOnlyRecordsAvailable:
            return policy(show: true, read: true, write: false, scoring: false, imports: false, team: false, surface: false, preserve: true, retry: false, sameID: false, noLegacy: true, diagnostics: true, backup: true)
        case .retryPermitted, .migrationInterrupted:
            return policy(show: false, read: false, write: false, scoring: false, imports: false, team: false, surface: true, preserve: true, retry: true, sameID: true, noLegacy: true, diagnostics: true, backup: true)
        default:
            return policy(show: false, read: false, write: false, scoring: false, imports: false, team: false, surface: true, preserve: true, retry: false, sameID: false, noLegacy: true, diagnostics: true, backup: true)
        }
    }

    static func map(orchestratorDisposition: ScoreKeepMigrationOrchestratorDisposition) -> ScoreKeepStartupPresentationCode {
        switch orchestratorDisposition {
        case .completed: return .migrationCompleted
        case .interrupted: return .migrationInterrupted
        case .disabled: return .proposedPreparedDisabled
        case .ownershipConflict: return .fatalConfigurationDefect
        case .sourcePreservationFailed: return .backupVerificationFailed
        case .constructionFailed: return .retryProhibited
        case .verificationFailed: return .recoveryRequired
        case .completionEvidenceFailed: return .completionUncertain
        case .recoveryRequired: return .recoveryRequired
        case .writesProhibited: return .proposedTemporarilyDisabled
        }
    }

    private static func policy(show: Bool, read: Bool, write: Bool, scoring: Bool, imports: Bool, team: Bool, surface: Bool, preserve: Bool, retry: Bool, sameID: Bool, noLegacy: Bool, diagnostics: Bool, backup: Bool) -> ScoreKeepStartupWorkflowPolicy {
        ScoreKeepStartupWorkflowPolicy(mayShowApplicationContent: show, mayReadRecords: read, mayWriteRecords: write, mayBeginScoring: scoring, mayBeginImports: imports, mayBeginTeamCreation: team, mustRemainOnStartupOrRecoverySurface: surface, mustPreserveEnteredWorkflowState: preserve, mayOfferRetry: retry, retryMustReuseSameMigrationIdentity: sameID, legacyFallbackProhibited: noLegacy, diagnosticsMustBeAvailable: diagnostics, backupMustBeRetained: backup)
    }
}
