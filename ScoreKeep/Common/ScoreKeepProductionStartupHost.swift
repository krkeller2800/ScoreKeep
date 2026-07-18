import CryptoKit
import CoreData
import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ScoreKeepProductionStartupRouteApproval {
    static let simpleTeamCreationProductionEnabled = true
    static let disposableProposedNormalUIRehearsalEnabled = true
}

private enum ScoreKeepStagedV1RecoveryError: Error {
    case v2VerificationFailed
    case v3VerificationFailed
    case backupSourceVersionMismatch(ScoreKeepProductionStoreMetadataAssessment)
    case backupSourceIdentityMismatch
    case v2IntermediateNotMigratable(ScoreKeepProductionStoreMetadataAssessment)
    case v1ToV2ContainerOpenFailed(ScoreKeepSanitizedPersistentStoreErrorReport)
}

struct ScoreKeepSanitizedPersistentStoreErrorReport: Hashable, Sendable {
    let identity: String
    let diagnostic: String
}

enum ScoreKeepSanitizedPersistentStoreErrorIdentity {
    static func make(for error: Error) -> String {
        makeReport(for: error).identity
    }

    static func makeReport(for error: Error) -> ScoreKeepSanitizedPersistentStoreErrorReport {
        let chain = errorTree(from: error as NSError)
        let text = chain
            .flatMap { error in
                [
                    error.domain,
                    error.localizedFailureReason,
                    error.localizedRecoverySuggestion
                ].compactMap { $0 }
            }
            .joined(separator: " ")
            .lowercased()

        let identity: String
        if text.contains("duplicate") && (text.contains("checksum") || text.contains("version")) {
            identity = "duplicateChecksum"
        } else if text.contains("locked") || text.contains("busy") || chain.contains(where: { $0.domain == "NSSQLiteErrorDomain" && ($0.code == 5 || $0.code == 6) }) {
            identity = "storeLocked"
        } else if text.contains("corrupt") || text.contains("malformed") || text.contains("not a database") || chain.contains(where: { $0.domain == "NSSQLiteErrorDomain" && ($0.code == 11 || $0.code == 26) }) {
            identity = "storeCorrupt"
        } else if text.contains("wal") || text.contains("shm") || text.contains("checkpoint") || text.contains("journal") || text.contains("disk i/o") {
            identity = "storeFamilyInconsistent"
        } else if text.contains("mapping model") || text.contains("missing mapping") || text.contains("migration mapping") {
            identity = "migrationMappingUnavailable"
        } else if text.contains("incompatible") || text.contains("version hash") || text.contains("source model") || text.contains("model used to open") {
            identity = "incompatibleModel"
        } else {
            let representative = chain.first { error in
                error.domain.contains("CoreData")
                    || error.domain.contains("Cocoa")
                    || error.domain.contains("SQLite")
                    || error.domain.contains("SwiftData")
            } ?? chain[0]
            identity = "unknownCoreData.\(sanitizedDomain(representative.domain)).\(representative.code)"
        }

        return ScoreKeepSanitizedPersistentStoreErrorReport(
            identity: identity,
            diagnostic: diagnostic(identity: identity, chain: chain)
        )
    }

    private static func errorTree(from error: NSError) -> [NSError] {
        var chain = [error]
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            chain.append(contentsOf: errorTree(from: underlying))
        }
        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for detail in detailed {
                chain.append(contentsOf: errorTree(from: detail))
            }
        }
        return chain
    }

    private static func diagnostic(identity: String, chain: [NSError]) -> String {
        var parts = [identity]
        parts.append(contentsOf: chain.enumerated().map { index, error in
            let prefix = index == 0 ? "top" : "nested\(index)"
            return "\(prefix).\(sanitizedDomain(error.domain)).\(error.code)"
        })
        if chain.count == 1, chain[0].domain == "SwiftData.SwiftDataError", chain[0].code == 1 {
            parts.append("swiftDataWrapperNoUnderlyingError")
        }
        let keyNames = Set(chain.flatMap { error in
            error.userInfo.keys.map { sanitizedUserInfoKey(String(describing: $0)) }
        })
        if keyNames.isEmpty == false {
            parts.append("keys.\(keyNames.sorted().joined(separator: "+"))")
        }
        if chain.contains(where: { $0.userInfo[NSUnderlyingErrorKey] is NSError }) {
            parts.append("hasUnderlyingError")
        }
        if chain.contains(where: { $0.userInfo[NSDetailedErrorsKey] is [NSError] }) {
            parts.append("hasDetailedErrors")
        }
        if chain.contains(where: { $0.localizedFailureReason != nil }) {
            parts.append("hasFailureReason")
        }
        if chain.contains(where: { $0.localizedRecoverySuggestion != nil }) {
            parts.append("hasRecoverySuggestion")
        }
        return parts.joined(separator: ".")
    }

    private static func sanitizedUserInfoKey(_ key: String) -> String {
        switch key {
        case NSUnderlyingErrorKey:
            return "NSUnderlyingErrorKey"
        case NSDetailedErrorsKey:
            return "NSDetailedErrorsKey"
        case NSLocalizedFailureReasonErrorKey:
            return "NSLocalizedFailureReasonErrorKey"
        case NSLocalizedRecoverySuggestionErrorKey:
            return "NSLocalizedRecoverySuggestionErrorKey"
        default:
            return "OtherUserInfoKey"
        }
    }

    private static func sanitizedDomain(_ domain: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return String(domain.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}

private enum ScoreKeepStagedV1RecoveryBoundary: String {
    case journalPreflight
    case v2IntermediateResumeOpen
    case sourcePreservationStarted
    case sourceBackupCopy
    case sourceBackupJournalRecord
    case v1ToV2MigrationAttemptRecord
    case v2IntermediateCopyFromBackup
    case v1ToV2MigrationContainerOpen
    case v2IntermediateBaselineCapture
    case v2IntermediateJournalRecord
    case v2IntermediateVerification
    case fallbackCopyVerified
    case fallbackMaterializationStarted
    case fallbackMaterializationOpened
    case fallbackMaterializationSaved
    case fallbackMaterializationCompleted
    case fallbackV2VerificationStarted
    case v3DestinationCopyFromV2
    case v2ToV3MigrationContainerOpen
    case v3DestinationBaselineCapture
    case v3Verification
    case postOpenVerificationJournalRecord
    case completionJournalRecord
    case openVerifiedV3Destination
}

enum ScoreKeepProductionStartupDiagnosticCode: String, CaseIterable, Hashable, Sendable {
    case protectedDataUnavailable
    case capacityInsufficient
    case capacityUnavailable
    case migrationInterruptedRetryable
    case migrationRecoveryRequired
    case journalCorrupt
    case journalUnsupported
    case sourceMissing
    case sourceIncomplete
    case backupVerificationFailed
    case proposedOpenFailed
    case postMigrationVerificationFailed
    case completionRecordFailed
    case retryInProgress
    case retryBlocked
    case startupCompleted
}

enum ScoreKeepProductionStartupRecoveryAction: String, CaseIterable, Hashable, Sendable {
    case unlockDevice
    case retry
    case freeUpStorage
    case copySupportSummary
}

struct ScoreKeepProductionStartupRecoveryPresentation: Hashable, Sendable {
    let diagnosticCode: ScoreKeepProductionStartupDiagnosticCode
    let title: String
    let explanation: String
    let actions: Set<ScoreKeepProductionStartupRecoveryAction>
    let retryAllowed: Bool
    let supportSummary: String

    static func make(
        diagnosticCode: ScoreKeepProductionStartupDiagnosticCode,
        protectedDataState: ScoreKeepProtectedDataObservationState,
        capacityStatus: String,
        sourceStatus: String,
        backupStatus: String,
        migrationPhase: String,
        targetVerification: String,
        retryAllowed: Bool,
        retryInProgress: Bool = false
    ) -> ScoreKeepProductionStartupRecoveryPresentation {
        let content = userContent(for: diagnosticCode, retryAllowed: retryAllowed, retryInProgress: retryInProgress)
        var actions = content.actions
        actions.insert(.copySupportSummary)
        let finalCode: ScoreKeepProductionStartupDiagnosticCode = retryInProgress ? .retryInProgress : diagnosticCode
        return ScoreKeepProductionStartupRecoveryPresentation(
            diagnosticCode: finalCode,
            title: content.title,
            explanation: content.explanation,
            actions: actions,
            retryAllowed: retryAllowed && retryInProgress == false,
            supportSummary: [
                "ScoreKeep Startup Support Summary",
                "App Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")",
                "Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")",
                "Startup Outcome: \(finalCode.rawValue)",
                "Protected Data: \(protectedDataState.rawValue)",
                "Capacity: \(capacityStatus)",
                "Source: \(sourceStatus)",
                "Backup: \(backupStatus)",
                "Migration Phase: \(migrationPhase)",
                "Target Verification: \(targetVerification)",
                "Retry: \((retryAllowed && retryInProgress == false) ? "allowed" : "prohibited")",
                "Codes: startup.\(finalCode.rawValue)"
            ].joined(separator: "\n")
        )
    }

    private static func userContent(
        for code: ScoreKeepProductionStartupDiagnosticCode,
        retryAllowed: Bool,
        retryInProgress: Bool
    ) -> (title: String, explanation: String, actions: Set<ScoreKeepProductionStartupRecoveryAction>) {
        if retryInProgress {
            return ("Preparing Your Data", "ScoreKeep is checking the saved data again. No changes can be made until this finishes.", [])
        }
        switch code {
        case .protectedDataUnavailable:
            return ("Unlock Device", "ScoreKeep needs the device to be unlocked before it can safely open saved data.", [.unlockDevice])
        case .capacityInsufficient, .capacityUnavailable:
            return ("More Storage Needed", "ScoreKeep needs more available device storage before it can safely prepare saved data.", retryAllowed ? [.freeUpStorage, .retry] : [.freeUpStorage])
        case .migrationInterruptedRetryable:
            return ("Finish Preparing Data", "ScoreKeep needs to finish preparing saved data before changes can be made.", [.retry])
        case .migrationRecoveryRequired, .journalCorrupt, .journalUnsupported, .sourceMissing, .sourceIncomplete, .backupVerificationFailed, .postMigrationVerificationFailed:
            return ("Recovery Needed", "ScoreKeep cannot safely finish preparing saved data on this device without review. No changes will be saved.", [])
        case .proposedOpenFailed:
            return ("Cannot Open Saved Data", "ScoreKeep could not safely open the prepared data. No changes will be saved.", retryAllowed ? [.retry] : [])
        case .completionRecordFailed:
            return ("Preparation Not Verified", "ScoreKeep could not verify that data preparation finished. No changes will be saved.", [])
        case .retryBlocked:
            return ("Retry Not Available", "ScoreKeep cannot safely retry from the saved evidence on this device. No changes will be saved.", [])
        case .retryInProgress:
            return ("Preparing Your Data", "ScoreKeep is checking the saved data again. No changes can be made until this finishes.", [])
        case .startupCompleted:
            return ("ScoreKeep Is Ready", "Saved data opened successfully.", [])
        }
    }
}

enum ScoreKeepProductionStartupStatus: Hashable {
    case loading
    case ready(ModelContainer, SimpleTeamCreationRoutingService, Bool)
    case proposedMigrationExecutionRequired
    case blocked(ScoreKeepProductionStartupRecoveryPresentation)

    static func == (lhs: ScoreKeepProductionStartupStatus, rhs: ScoreKeepProductionStartupStatus) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.proposedMigrationExecutionRequired, .proposedMigrationExecutionRequired):
            return true
        case (.blocked(let lhsPresentation), .blocked(let rhsPresentation)):
            return lhsPresentation == rhsPresentation
        case (.ready, .ready):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .loading:
            hasher.combine("loading")
        case .ready:
            hasher.combine("ready")
        case .proposedMigrationExecutionRequired:
            hasher.combine("proposedMigrationExecutionRequired")
        case .blocked(let presentation):
            hasher.combine("blocked")
            hasher.combine(presentation)
        }
    }
}

@MainActor
final class ScoreKeepProductionStartupModel: ObservableObject {
    @Published private(set) var status: ScoreKeepProductionStartupStatus = .loading
    private var didStart = false
    private var retryInProgress = false

    func start() {
        guard didStart == false else { return }
        didStart = true
        runStartup(allowJournalResume: false)
    }

    func retry() {
        guard case .blocked(let presentation) = status, presentation.retryAllowed else {
            status = .blocked(recoveryPresentation(
                code: .retryBlocked,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: "notAssessed",
                backupStatus: "uncertain",
                migrationPhase: "blocked",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        guard retryInProgress == false else { return }
        retryInProgress = true
        status = .blocked(recoveryPresentation(
            code: presentation.diagnosticCode,
            protectedDataState: currentProtectedDataState(),
            capacityStatus: "reassessing",
            sourceStatus: "reassessing",
            backupStatus: "reassessing",
            migrationPhase: "retrying",
            targetVerification: "notRun",
            retryAllowed: false,
            retryInProgress: true
        ))
        runStartup(allowJournalResume: true)
        retryInProgress = false
    }

    func protectedDataBecameAvailable() {
        guard case .blocked(let presentation) = status,
              presentation.diagnosticCode == .protectedDataUnavailable else { return }
        status = .blocked(recoveryPresentation(
            code: .migrationInterruptedRetryable,
            protectedDataState: .becameAvailable,
            capacityStatus: "notAssessed",
            sourceStatus: "notAssessed",
            backupStatus: "uncertain",
            migrationPhase: "protectedDataAvailable",
            targetVerification: "notRun",
            retryAllowed: true
        ))
    }

    func protectedDataWillBecomeUnavailable() {
        guard case .ready = status else { return }
        status = .blocked(recoveryPresentation(
            code: .protectedDataUnavailable,
            protectedDataState: .willBecomeUnavailable,
            capacityStatus: "notAssessed",
            sourceStatus: "notAssessed",
            backupStatus: "uncertain",
            migrationPhase: "protectedDataUnavailable",
            targetVerification: "notRun",
            retryAllowed: false
        ))
    }

    private func runStartup(allowJournalResume: Bool) {
        #if SCOREKEEP_MIGRATION_TEST_PROPOSED
        startDisposableProposedRehearsalOrExecution()
        #else
        if ScoreKeepProductionStartupRouteApproval.simpleTeamCreationProductionEnabled {
            startProductionProposedIfComplete(allowJournalResume: allowJournalResume)
        } else {
            startLegacyCompatibleProduction()
        }
        #endif
    }

    private func startLegacyCompatibleProduction() {
        do {
            let container = try ModelContainer(for: Game.self)
            let service = SimpleTeamCreationRoutingService()
            status = .ready(container, service, false)
        } catch {
            status = .blocked(recoveryPresentation(
                code: .proposedOpenFailed,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: "legacyCompatible",
                backupStatus: "notRequired",
                migrationPhase: "legacyCompatibleOpenFailed",
                targetVerification: "notRun",
                retryAllowed: true
            ))
        }
    }

    private func startProductionProposedIfComplete(fileManager: FileManager = .default, allowJournalResume: Bool = false) {
        let protectedDataState = currentProtectedDataState()
        guard protectedDataState == .available || protectedDataState == .unknownOrUnsupported else {
            status = .blocked(recoveryPresentation(
                code: .protectedDataUnavailable,
                protectedDataState: protectedDataState,
                capacityStatus: "notAssessed",
                sourceStatus: "notAssessed",
                backupStatus: "uncertain",
                migrationPhase: "protectedDataUnavailable",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        let root = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot(fileManager: fileManager)
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
        let journalStore = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent(), fileManager: fileManager)
        let journal = journalStore.load()
        if let journalError = journal.error {
            status = .blocked(recoveryPresentation(
                code: diagnosticCode(for: journalError),
                protectedDataState: protectedDataState,
                capacityStatus: "notAssessed",
                sourceStatus: "uncertain",
                backupStatus: "uncertain",
                migrationPhase: "journalUnreadable",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        if let record = journal.record, record.phase == .completionRecorded {
            let targetURL = layout.operationTemporaryTargetURL(operationIdentity: record.operationIdentity)
            let targetAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL, fileManager: fileManager)
            let activeAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: layout.activeStore, fileManager: fileManager)
            switch ScoreKeepCompletedJournalRecoveryRouter.route(
                target: targetAssessment,
                active: activeAssessment,
                journalSourceClassification: record.sourceClassification,
                backupVerified: record.backupVerificationDisposition == .backupVerified
            ) {
            case .openCompletedTargetAsV3:
                openProposedContainer(
                    at: targetURL,
                    sourceClassification: .existingProposedV3Store,
                    routeEnabled: true,
                    disposableIndicator: false
                )
            case .openActiveStoreAsV3:
                openProposedContainer(
                    at: layout.activeStore,
                    sourceClassification: .existingProposedV3Store,
                    routeEnabled: true,
                    disposableIndicator: false
                )
            case .recoverCompletedTargetV2ToFreshV3:
                status = .blocked(recoveryPresentation(
                    code: .migrationRecoveryRequired,
                    protectedDataState: protectedDataState,
                    capacityStatus: "notAssessed",
                    sourceStatus: targetAssessment.sourceClassification.rawValue,
                    backupStatus: record.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: "semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums",
                    targetVerification: "notRun",
                    retryAllowed: false
                ))
            case .recoverActiveV1ToFreshV3:
                status = .blocked(recoveryPresentation(
                    code: .migrationRecoveryRequired,
                    protectedDataState: protectedDataState,
                    capacityStatus: "notAssessed",
                    sourceStatus: activeAssessment.sourceClassification.rawValue,
                    backupStatus: record.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: "semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums",
                    targetVerification: "notRun",
                    retryAllowed: false
                ))
            case .activeV2RequiresFreshPreparation, .failClosed:
                status = .blocked(recoveryPresentation(
                    code: .migrationRecoveryRequired,
                    protectedDataState: protectedDataState,
                    capacityStatus: "notAssessed",
                    sourceStatus: activeAssessment.sourceClassification.rawValue,
                    backupStatus: record.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: "completedJournalTargetInvalid",
                    targetVerification: targetAssessment.sourceClassification.rawValue,
                    retryAllowed: targetAssessment.sourceClassification != .contradictoryMetadata
                ))
            }
            return
        }
        if let record = journal.record, allowJournalResume == false {
            let recovery = ScoreKeepMigrationOrchestrator.reconcile(record)
            let retryAllowed = Self.retryAllowed(for: recovery)
            status = .blocked(recoveryPresentation(
                code: retryAllowed ? .migrationInterruptedRetryable : .migrationRecoveryRequired,
                protectedDataState: protectedDataState,
                capacityStatus: "notAssessed",
                sourceStatus: record.sourceClassification.rawValue,
                backupStatus: record.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: record.phase.rawValue,
                targetVerification: record.postOpenVerificationDisposition,
                retryAllowed: retryAllowed
            ))
            return
        }
        runProductionMigration(layout: layout, journalStore: journalStore, fileManager: fileManager)
    }

    private func recoverCompletedJournalV2Target(
        record: ScoreKeepMigrationJournalRecord,
        sourceURL: URL,
        sourceAssessment: ScoreKeepProductionStoreMetadataAssessment,
        layout: ScoreKeepProductionMigrationLayout,
        fileManager: FileManager
    ) {
        let family: ScoreKeepStoreFamilyDescriptor
        do {
            family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL, fileManager: fileManager)
        } catch {
            status = .blocked(recoveryPresentation(
                code: .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: ScoreKeepSourceStoreClassification.existingProposedV2Store.rawValue,
                backupStatus: record.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: "completedJournalV2TargetIncomplete",
                targetVerification: "existingProposedV2Store",
                retryAllowed: true
            ))
            return
        }

        let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(
            input: ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: family.members.reduce(UInt64(0)) { $0 + $1.byteCount }),
            volume: ScoreKeepMigrationCapacityCalculator.queryVolume(at: layout.applicationSupportRoot)
        )
        guard capacity.mayProceed else {
            status = .blocked(recoveryPresentation(
                code: capacity.disposition == .insufficient || capacity.disposition == .safetyMarginNotMet ? .capacityInsufficient : .capacityUnavailable,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: capacity.diagnosticCode,
                sourceStatus: ScoreKeepSourceStoreClassification.existingProposedV2Store.rawValue,
                backupStatus: "present",
                migrationPhase: "completedJournalV2TargetRecovery",
                targetVerification: "existingProposedV2Store",
                retryAllowed: true
            ))
            return
        }

        let recoveryPlan = completedJournalV2RecoveryPlan(
            staleRecord: record,
            sourceStoreIdentity: family.diagnosticIdentity,
            layout: layout,
            fileManager: fileManager
        )
        guard let recoveryPlan else {
            status = .blocked(recoveryPresentation(
                code: .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "capacity.sufficient",
                sourceStatus: ScoreKeepSourceStoreClassification.existingProposedV2Store.rawValue,
                backupStatus: "present",
                migrationPhase: "completedJournalV2TargetRecoveryExhausted",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        let recoveryIdentity = recoveryPlan.operationIdentity
        let sourceStoreFileName = sourceURL.lastPathComponent
        let backupURL = layout.operationBackupStoreURL(operationIdentity: recoveryIdentity, storeFileName: sourceStoreFileName)
        let targetURL = layout.operationTemporaryTargetURL(operationIdentity: recoveryIdentity, storeFileName: sourceStoreFileName)
        let recoveryJournalStore = recoveryPlan.journalStore
        do {
            var preservedBaseline: ScoreKeepMigrationBaselineRecord?
            let result = try ScoreKeepMigrationOrchestrator.run(
                input: ScoreKeepMigrationOrchestratorInput(
                    operationIdentity: recoveryIdentity,
                    sourceStoreURL: sourceURL,
                    backupStoreURL: backupURL,
                    targetStoreURL: targetURL,
                    sourceClassification: .existingProposedV2Store,
                    disableState: .proposedTransitionExplicitlyAuthorized,
                    authorizationEvidence: "scorekeep-next-completed-journal-v2-target-recovery",
                    sourceClosureEvidence: .closedForProductionStartup,
                    sourceLocation: .disposableMigrationTarget,
                    sourcePreservationAuthorizationScope: .productionTransitionExplicitlyAuthorized,
                    allowIncompleteBackupRemoval: false,
                    interruptionPoint: nil,
                    factoryInjection: nil,
                    semanticRestoreVerifier: { restoreURL in
                        let record: ScoreKeepMigrationBaselineRecord
                        do {
                            record = try ScoreKeepCompletedJournalV2SourceBaseline.failClosedBecauseFrozenV2SemanticVerifierUnavailable(
                                url: restoreURL,
                                fileManager: fileManager
                            )
                        } catch {
                            throw ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError(
                                diagnostic: ScoreKeepCompletedJournalV2SourceBaseline.sanitizedErrorIdentity(error)
                            )
                        }
                        preservedBaseline = record
                        return true
                    },
                    postOpenVerifier: { container in
                        let expectedBaseline: ScoreKeepMigrationBaselineRecord
                        if let preservedBaseline {
                            expectedBaseline = preservedBaseline
                        } else {
                            expectedBaseline = try ScoreKeepCompletedJournalV2SourceBaseline.failClosedBecauseFrozenV2SemanticVerifierUnavailable(
                                url: backupURL,
                                fileManager: fileManager
                            )
                        }
                        let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                        return record.gameCount == expectedBaseline.gameCount
                            && record.teamCount == expectedBaseline.teamCount
                            && record.playerCount == expectedBaseline.playerCount
                            && record.lineupCount == expectedBaseline.lineupCount
                            && record.atbatCount == expectedBaseline.atbatCount
                            && record.pitcherCount == expectedBaseline.pitcherCount
                            && record.teamCreationOperationEvidenceCount == expectedBaseline.teamCreationOperationEvidenceCount
                            && record.canonicalHistoryCount == 0
                            && record.canonicalEventCount == 0
                            && record.canonicalPayloadCount == 0
                            && record.canonicalOperationCount == 0
                            && record.canonicalCorrectionCount == 0
                    }
                ),
                journalStore: recoveryJournalStore
            )
            guard result.disposition == .completed, result.journal.phase == .completionRecorded else {
                let code = diagnosticCode(for: result)
                let migrationPhase = result.disposition == .sourcePreservationFailed
                    ? (result.failureDiagnosticIdentity ?? result.journal.phase.rawValue)
                    : result.journal.phase.rawValue
                status = .blocked(recoveryPresentation(
                    code: code,
                    protectedDataState: currentProtectedDataState(),
                    capacityStatus: "capacity.sufficient",
                    sourceStatus: ScoreKeepSourceStoreClassification.existingProposedV2Store.rawValue,
                    backupStatus: result.journal.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: migrationPhase,
                    targetVerification: result.journal.postOpenVerificationDisposition,
                    retryAllowed: Self.retryAllowed(for: result.recoveryRequirement)
                ))
                return
            }
            openProposedContainer(
                at: targetURL,
                sourceClassification: .existingProposedV3Store,
                routeEnabled: true,
                disposableIndicator: false
            )
        } catch {
            let loaded = recoveryJournalStore.load()
            let recovery = ScoreKeepMigrationOrchestrator.reconcile(loaded.record)
            let fallbackPhase = loaded.record == nil
                ? "completedJournalV2SourceBaselineFailed.\(ScoreKeepCompletedJournalV2SourceBaseline.sanitizedErrorIdentity(error))"
                : loaded.record?.phase.rawValue
            status = .blocked(recoveryPresentation(
                code: Self.retryAllowed(for: recovery) ? .migrationInterruptedRetryable : .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "capacity.sufficient",
                sourceStatus: ScoreKeepSourceStoreClassification.existingProposedV2Store.rawValue,
                backupStatus: loaded.record?.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: fallbackPhase ?? "completedJournalV2TargetRecovery",
                targetVerification: loaded.record?.postOpenVerificationDisposition ?? "notRun",
                retryAllowed: Self.retryAllowed(for: recovery)
            ))
        }
    }

    private func recoverActiveV1ThroughFreshV3(
        staleRecord: ScoreKeepMigrationJournalRecord,
        sourceURL: URL,
        layout: ScoreKeepProductionMigrationLayout,
        fileManager: FileManager
    ) {
        let sourceAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: sourceURL, fileManager: fileManager)
        guard sourceAssessment.sourceClassification == .proposedV1RecognizableStore else {
            status = .blocked(recoveryPresentation(
                code: .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: sourceAssessment.sourceClassification.rawValue,
                backupStatus: staleRecord.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: "completedJournalV1SourceInvalid",
                targetVerification: "notRun",
                retryAllowed: true
            ))
            return
        }

        let family: ScoreKeepStoreFamilyDescriptor
        do {
            family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL, fileManager: fileManager)
        } catch {
            status = .blocked(recoveryPresentation(
                code: .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
                backupStatus: staleRecord.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: "completedJournalV1SourceIncomplete",
                targetVerification: "notRun",
                retryAllowed: true
            ))
            return
        }

        let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(
            input: ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: family.members.reduce(UInt64(0)) { $0 + $1.byteCount }),
            volume: ScoreKeepMigrationCapacityCalculator.queryVolume(at: layout.applicationSupportRoot)
        )
        guard capacity.mayProceed else {
            status = .blocked(recoveryPresentation(
                code: capacity.disposition == .insufficient || capacity.disposition == .safetyMarginNotMet ? .capacityInsufficient : .capacityUnavailable,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: capacity.diagnosticCode,
                sourceStatus: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
                backupStatus: "present",
                migrationPhase: "completedJournalV1ToV3Recovery",
                targetVerification: "notRun",
                retryAllowed: true
            ))
            return
        }

        let recoveryPlan = completedJournalV1RecoveryPlan(
            staleRecord: staleRecord,
            sourceStoreIdentity: family.diagnosticIdentity,
            layout: layout,
            fileManager: fileManager
        )
        guard let recoveryPlan else {
            status = .blocked(recoveryPresentation(
                code: .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "capacity.sufficient",
                sourceStatus: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
                backupStatus: "present",
                migrationPhase: "completedJournalV1ToV3RecoveryExhausted",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }

        let recoveryIdentity = recoveryPlan.operationIdentity
        let backupURL = layout.operationBackupStoreURL(operationIdentity: recoveryIdentity)
        let v2URL = layout.operationTemporaryTargetStoreFamilyURL(
            operationIdentity: recoveryIdentity,
            familyDirectoryName: "V2IntermediateStoreFamily-v1",
            storeFileName: backupURL.lastPathComponent
        )
        let fallbackV2URL = layout.operationTemporaryTargetStoreFamilyURL(
            operationIdentity: recoveryIdentity,
            familyDirectoryName: "V2FallbackStoreFamily-v1",
            storeFileName: backupURL.lastPathComponent
        )
        let v3URL = layout.operationTemporaryTargetStoreFamilyURL(
            operationIdentity: recoveryIdentity,
            familyDirectoryName: "V3TargetStoreFamily-v1",
            storeFileName: backupURL.lastPathComponent
        )
        let recoveryJournalStore = recoveryPlan.journalStore

        var recoveryBoundary: ScoreKeepStagedV1RecoveryBoundary = .journalPreflight
        do {
            var journal = recoveryJournalStore.load().record ?? ScoreKeepMigrationJournalRecord.initial(
                operationIdentity: recoveryIdentity,
                sourceStoreDiagnosticIdentity: family.diagnosticIdentity,
                sourceClassification: .proposedV1RecognizableStore,
                disableState: .proposedTransitionExplicitlyAuthorized
            )
            if journal.phase < .preflightStarted {
                journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .preflightStarted)
                try recoveryJournalStore.save(journal)
            }
            if journal.phase < .sourceClassified {
                journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .sourceClassified)
                try recoveryJournalStore.save(journal)
            }

            let v2Baseline: ScoreKeepMigrationBaselineRecord
            var selectedV2URL = Self.v1FallbackSelected(journalStore: recoveryJournalStore, fileManager: fileManager) ? fallbackV2URL : v2URL
            if journal.phase >= .containerConstructed,
               ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager).sourceClassification == .existingProposedV2Store {
                recoveryBoundary = .v2IntermediateResumeOpen
                let v2Container = try ScoreKeepCompletedJournalV2SourceBaseline.proposedV2Container(url: selectedV2URL)
                v2Baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: v2Container.mainContext)
            } else {
                if journal.phase < .sourcePreservationStarted {
                    recoveryBoundary = .sourcePreservationStarted
                    journal = try ScoreKeepMigrationJournalTransition.advance(
                        journal,
                        to: .sourcePreservationStarted,
                        sourcePreservationDisposition: .started
                    )
                    try recoveryJournalStore.save(journal)
                }
                if journal.phase < .backupVerified {
                    recoveryBoundary = .sourceBackupCopy
                    let preservation = try Self.preserveStoreFamily(
                        from: sourceURL,
                        to: backupURL,
                        sourceLocation: .productionIntendedApplicationStore,
                        semanticRestoreVerifier: { restoreURL in
                            ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL, fileManager: fileManager).sourceClassification == .proposedV1RecognizableStore
                        },
                        fileManager: fileManager
                    )
                    recoveryBoundary = .sourceBackupJournalRecord
                    journal = try ScoreKeepMigrationJournalTransition.advance(
                        journal,
                        to: .backupVerified,
                        sourcePreservationDisposition: preservation.disposition,
                        backupIdentity: preservation.backupIdentity,
                        backupVerificationDisposition: .backupVerified,
                        retryClassification: .reuseVerifiedBackup
                    )
                    try recoveryJournalStore.save(journal)
                }

                try Self.validateV1RecoveryBackupSource(
                    backupURL: backupURL,
                    activeSourceIdentity: family.diagnosticIdentity,
                    journal: journal,
                    fileManager: fileManager
                )

                if journal.phase < .migrationAttemptStarted {
                    recoveryBoundary = .v1ToV2MigrationAttemptRecord
                    journal = try ScoreKeepMigrationJournalTransition.advance(journal, to: .migrationAttemptStarted)
                    try recoveryJournalStore.save(journal)
                }
                let fallbackSelected = Self.v1FallbackSelected(journalStore: recoveryJournalStore, fileManager: fileManager)
                selectedV2URL = fallbackSelected ? fallbackV2URL : v2URL
                if Self.storeFamilyPrimaryExists(selectedV2URL, fileManager: fileManager) == false {
                    recoveryBoundary = .v2IntermediateCopyFromBackup
                    _ = try Self.preserveStoreFamily(
                        from: backupURL,
                        to: selectedV2URL,
                        sourceLocation: .disposableMigrationTarget,
                        semanticRestoreVerifier: nil,
                        fileManager: fileManager
                    )
                    let copiedAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager)
                    try Self.recordV1FallbackBoundary(
                        .fallbackCopyVerified,
                        assessment: copiedAssessment,
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                }
                let v2Assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager)
                let v2Container: ModelContainer
                var automaticFallbackMaterialization = false
                if v2Assessment.sourceClassification == .existingProposedV2Store {
                    recoveryBoundary = .v2IntermediateResumeOpen
                    v2Container = try ScoreKeepCompletedJournalV2SourceBaseline.proposedV2Container(url: selectedV2URL)
                } else if v2Assessment.sourceClassification == .contradictoryMetadata, fallbackSelected == false {
                    try Self.recordV1FallbackSelection(journalStore: recoveryJournalStore, fileManager: fileManager)
                    selectedV2URL = fallbackV2URL
                    recoveryBoundary = .v2IntermediateCopyFromBackup
                    if Self.storeFamilyPrimaryExists(selectedV2URL, fileManager: fileManager) == false {
                        _ = try Self.preserveStoreFamily(
                            from: backupURL,
                            to: selectedV2URL,
                            sourceLocation: .disposableMigrationTarget,
                            semanticRestoreVerifier: nil,
                            fileManager: fileManager
                        )
                    }
                    let fallbackAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager)
                    try Self.recordV1FallbackBoundary(
                        .fallbackCopyVerified,
                        assessment: fallbackAssessment,
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                    guard fallbackAssessment.sourceClassification == .proposedV1RecognizableStore else {
                        recoveryBoundary = .v1ToV2MigrationContainerOpen
                        throw ScoreKeepStagedV1RecoveryError.v2IntermediateNotMigratable(fallbackAssessment)
                    }
                    recoveryBoundary = .v1ToV2MigrationContainerOpen
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationStarted,
                        assessment: fallbackAssessment,
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                    v2Container = try Self.automaticV2MaterializationContainer(url: selectedV2URL)
                    automaticFallbackMaterialization = true
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationOpened,
                        assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                } else if v2Assessment.sourceClassification == .proposedV1RecognizableStore, fallbackSelected {
                    recoveryBoundary = .v1ToV2MigrationContainerOpen
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationStarted,
                        assessment: v2Assessment,
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                    v2Container = try Self.automaticV2MaterializationContainer(url: selectedV2URL)
                    automaticFallbackMaterialization = true
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationOpened,
                        assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                } else if v2Assessment.sourceClassification == .proposedV1RecognizableStore {
                    recoveryBoundary = .v1ToV2MigrationContainerOpen
                    do {
                        v2Container = try Self.proposedV2MigratingFromV1Container(url: selectedV2URL)
                    } catch ScoreKeepStagedV1RecoveryError.v1ToV2ContainerOpenFailed(let report)
                        where report.diagnostic.contains("swiftDataWrapperNoUnderlyingError") {
                        try Self.recordV1FallbackSelection(journalStore: recoveryJournalStore, fileManager: fileManager)
                        selectedV2URL = fallbackV2URL
                        recoveryBoundary = .v2IntermediateCopyFromBackup
                        if Self.storeFamilyPrimaryExists(selectedV2URL, fileManager: fileManager) == false {
                            _ = try Self.preserveStoreFamily(
                                from: backupURL,
                                to: selectedV2URL,
                                sourceLocation: .disposableMigrationTarget,
                                semanticRestoreVerifier: nil,
                                fileManager: fileManager
                            )
                        }
                        let fallbackAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager)
                        try Self.recordV1FallbackBoundary(
                            .fallbackCopyVerified,
                            assessment: fallbackAssessment,
                            journalStore: recoveryJournalStore,
                            fileManager: fileManager
                        )
                        recoveryBoundary = .v1ToV2MigrationContainerOpen
                        try Self.recordV1FallbackBoundary(
                            .fallbackMaterializationStarted,
                            assessment: fallbackAssessment,
                            journalStore: recoveryJournalStore,
                            fileManager: fileManager
                        )
                        v2Container = try Self.automaticV2MaterializationContainer(url: selectedV2URL)
                        automaticFallbackMaterialization = true
                        try Self.recordV1FallbackBoundary(
                            .fallbackMaterializationOpened,
                            assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                            journalStore: recoveryJournalStore,
                            fileManager: fileManager
                        )
                    }
                } else {
                    recoveryBoundary = .v1ToV2MigrationContainerOpen
                    throw ScoreKeepStagedV1RecoveryError.v2IntermediateNotMigratable(v2Assessment)
                }
                if automaticFallbackMaterialization {
                    try v2Container.mainContext.save()
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationSaved,
                        assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                }
                recoveryBoundary = .v2IntermediateBaselineCapture
                v2Baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: v2Container.mainContext)
                if automaticFallbackMaterialization {
                    try Self.recordV1FallbackBoundary(
                        .fallbackMaterializationCompleted,
                        assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                        journalStore: recoveryJournalStore,
                        fileManager: fileManager
                    )
                }
                if journal.phase < .containerConstructed {
                    recoveryBoundary = .v2IntermediateJournalRecord
                    journal = try ScoreKeepMigrationJournalTransition.advance(
                        journal,
                        to: .containerConstructed,
                        containerConstructionDisposition: .openedCompatibleSourceAndTransitionedToProposedV3
                    )
                    try recoveryJournalStore.save(journal)
                }
            }
            recoveryBoundary = .fallbackV2VerificationStarted
            try Self.recordV1FallbackBoundary(
                .fallbackV2VerificationStarted,
                assessment: ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager),
                journalStore: recoveryJournalStore,
                fileManager: fileManager
            )
            recoveryBoundary = .v2IntermediateVerification
            guard ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL, fileManager: fileManager).sourceClassification == .existingProposedV2Store else {
                throw ScoreKeepStagedV1RecoveryError.v2VerificationFailed
            }

            if Self.directoryHasContents(v3URL.deletingLastPathComponent(), fileManager: fileManager) == false {
                recoveryBoundary = .v3DestinationCopyFromV2
                _ = try Self.preserveStoreFamily(
                    from: selectedV2URL,
                    to: v3URL,
                    sourceLocation: .disposableMigrationTarget,
                    semanticRestoreVerifier: nil,
                    fileManager: fileManager
                )
            }
            let v3Container: ModelContainer
            if ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: v3URL, fileManager: fileManager).sourceClassification == .existingProposedV3Store {
                recoveryBoundary = .openVerifiedV3Destination
                v3Container = try Self.proposedV3ExistingContainer(url: v3URL)
            } else {
                recoveryBoundary = .v2ToV3MigrationContainerOpen
                v3Container = try Self.proposedV3MigratingFromV2Container(url: v3URL)
            }
            recoveryBoundary = .v3DestinationBaselineCapture
            let v3Baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: v3Container.mainContext)
            recoveryBoundary = .v3Verification
            guard Self.baselineMatches(v3Baseline, v2Baseline),
                  v3Baseline.canonicalHistoryCount == 0,
                  v3Baseline.canonicalEventCount == 0,
                  v3Baseline.canonicalPayloadCount == 0,
                  v3Baseline.canonicalOperationCount == 0,
                  v3Baseline.canonicalCorrectionCount == 0,
                  ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: v3URL, fileManager: fileManager).sourceClassification == .existingProposedV3Store else {
                throw ScoreKeepStagedV1RecoveryError.v3VerificationFailed
            }
            if journal.phase < .postOpenVerificationPassed {
                recoveryBoundary = .postOpenVerificationJournalRecord
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .postOpenVerificationPassed,
                    postOpenVerificationDisposition: "passed"
                )
                try recoveryJournalStore.save(journal)
            }
            if journal.phase < .completionRecorded {
                recoveryBoundary = .completionJournalRecord
                journal = try ScoreKeepMigrationJournalTransition.advance(
                    journal,
                    to: .completionRecorded,
                    completionDisposition: "stagedV1ToV3RecoveryRecorded",
                    retryClassification: .noRetryRequired,
                    recoveryRequirement: .noRecoveryRequired
                )
                try recoveryJournalStore.save(journal)
            }

            recoveryBoundary = .openVerifiedV3Destination
            openProposedContainer(
                at: v3URL,
                sourceClassification: .existingProposedV3Store,
                routeEnabled: true,
                disposableIndicator: false
            )
        } catch {
            status = .blocked(recoveryPresentation(
                code: .migrationInterruptedRetryable,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "capacity.sufficient",
                sourceStatus: ScoreKeepSourceStoreClassification.proposedV1RecognizableStore.rawValue,
                backupStatus: "present",
                migrationPhase: "completedJournalV1ToV3Recovery.\(recoveryBoundary.rawValue).\(Self.stagedV1RecoveryErrorIdentity(error))",
                targetVerification: "notRun",
                retryAllowed: true
            ))
        }
    }

    private func runProductionMigration(
        layout: ScoreKeepProductionMigrationLayout,
        journalStore: ScoreKeepMigrationJournalStore,
        fileManager: FileManager
    ) {
        let family: ScoreKeepStoreFamilyDescriptor?
        do {
            family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore, fileManager: fileManager)
        } catch {
            family = nil
            if fileManager.fileExists(atPath: layout.activeStore.path + "-wal") || fileManager.fileExists(atPath: layout.activeStore.path + "-shm") {
                status = .blocked(recoveryPresentation(
                    code: .sourceIncomplete,
                    protectedDataState: currentProtectedDataState(),
                    capacityStatus: "notAssessed",
                    sourceStatus: "incomplete",
                    backupStatus: "uncertain",
                    migrationPhase: "notStarted",
                    targetVerification: "notRun",
                    retryAllowed: false
                ))
                return
            }
        }
        let metadataAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: layout.activeStore, fileManager: fileManager)
        let sourceClassification = family == nil ? .noStoreExists : metadataAssessment.sourceClassification
        let supportedStartupClassifications: Set<ScoreKeepSourceStoreClassification> = [
            .noStoreExists,
            .existingProposedV2Store,
            .existingProposedV3Store,
            .convertedProposedV3Store
        ]
        guard supportedStartupClassifications.contains(sourceClassification) else {
            status = .blocked(recoveryPresentation(
                code: .sourceMissing,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: sourceClassification.rawValue,
                backupStatus: "uncertain",
                migrationPhase: "notStarted",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        if sourceClassification == .existingProposedV3Store || sourceClassification == .convertedProposedV3Store {
            openProposedContainer(
                at: layout.activeStore,
                sourceClassification: sourceClassification,
                routeEnabled: true,
                disposableIndicator: false
            )
            return
        }
        let operationIdentity = makeOperationIdentity(sourceStoreIdentity: family?.diagnosticIdentity ?? "no-existing-store", sourceClassification: sourceClassification)
        let targetURL = layout.operationTemporaryTargetURL(operationIdentity: operationIdentity)
        let backupURL = layout.operationBackupStoreURL(operationIdentity: operationIdentity)

        if let family {
            let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(
                input: ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: family.members.reduce(UInt64(0)) { $0 + $1.byteCount }),
                volume: ScoreKeepMigrationCapacityCalculator.queryVolume(at: layout.applicationSupportRoot)
            )
            guard capacity.mayProceed else {
                status = .blocked(recoveryPresentation(
                    code: capacity.disposition == .insufficient || capacity.disposition == .safetyMarginNotMet ? .capacityInsufficient : .capacityUnavailable,
                    protectedDataState: currentProtectedDataState(),
                    capacityStatus: capacity.diagnosticCode,
                    sourceStatus: sourceClassification.rawValue,
                    backupStatus: "absent",
                    migrationPhase: "notStarted",
                    targetVerification: "notRun",
                    retryAllowed: true
                ))
                return
            }
        }

        var preservedBaseline: ScoreKeepMigrationBaselineRecord?
        do {
            let result = try ScoreKeepMigrationOrchestrator.run(
                input: ScoreKeepMigrationOrchestratorInput(
                    operationIdentity: operationIdentity,
                    sourceStoreURL: layout.activeStore,
                    backupStoreURL: backupURL,
                    targetStoreURL: targetURL,
                    sourceClassification: sourceClassification,
                    disableState: .proposedTransitionExplicitlyAuthorized,
                    authorizationEvidence: "scorekeep-next-production-simple-team-route-activation",
                    sourceClosureEvidence: .closedForProductionStartup,
                    sourceLocation: .productionIntendedApplicationStore,
                    sourcePreservationAuthorizationScope: .productionTransitionExplicitlyAuthorized,
                    allowIncompleteBackupRemoval: false,
                    interruptionPoint: nil,
                    factoryInjection: nil,
                    semanticRestoreVerifier: sourceClassification.requiresMigration ? { restoreURL in
                        if sourceClassification == .existingProposedV2Store {
                            return ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: restoreURL, fileManager: fileManager).sourceClassification == .existingProposedV2Store
                        }
                        let restored = try Self.currentUnversionedContainer(url: restoreURL, allowsSave: false)
                        let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: restored.mainContext)
                        preservedBaseline = record
                        return true
                    } : nil,
                    postOpenVerifier: { container in
                        guard let baseline = preservedBaseline else { return sourceClassification == .noStoreExists }
                        let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                        return Self.baselineMatches(record, baseline)
                    }
                ),
                journalStore: journalStore
            )
            guard result.disposition == .completed, result.journal.phase == .completionRecorded else {
                let code = diagnosticCode(for: result)
                let retryAllowed = Self.retryAllowed(for: result.recoveryRequirement)
                status = .blocked(recoveryPresentation(
                    code: code,
                    protectedDataState: currentProtectedDataState(),
                    capacityStatus: "capacity.sufficient",
                    sourceStatus: sourceClassification.rawValue,
                    backupStatus: result.journal.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: result.journal.phase.rawValue,
                    targetVerification: result.journal.postOpenVerificationDisposition,
                    retryAllowed: retryAllowed
                ))
                return
            }
            guard sourceClassification != .existingProposedV2Store else {
                status = .blocked(recoveryPresentation(
                    code: .postMigrationVerificationFailed,
                    protectedDataState: currentProtectedDataState(),
                    capacityStatus: "capacity.sufficient",
                    sourceStatus: sourceClassification.rawValue,
                    backupStatus: result.journal.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                    migrationPhase: result.journal.phase.rawValue,
                    targetVerification: "pendingTask3.22D",
                    retryAllowed: false
                ))
                return
            }
            openProposedContainer(
                at: targetURL,
                sourceClassification: sourceClassification,
                routeEnabled: true,
                disposableIndicator: false
            )
        } catch {
            let loaded = journalStore.load()
            let recovery = ScoreKeepMigrationOrchestrator.reconcile(loaded.record)
            status = .blocked(recoveryPresentation(
                code: Self.retryAllowed(for: recovery) ? .migrationInterruptedRetryable : .migrationRecoveryRequired,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: family == nil ? "notRequiredForEmptyStore" : "capacity.sufficient",
                sourceStatus: sourceClassification.rawValue,
                backupStatus: loaded.record?.backupVerificationDisposition == .backupVerified ? "present" : "uncertain",
                migrationPhase: loaded.record?.phase.rawValue ?? "notStarted",
                targetVerification: loaded.record?.postOpenVerificationDisposition ?? "notRun",
                retryAllowed: Self.retryAllowed(for: recovery)
            ))
        }
    }

    private func startDisposableProposedRehearsalOrExecution(fileManager: FileManager = .default) {
        guard ScoreKeepProductionStartupRouteApproval.disposableProposedNormalUIRehearsalEnabled else {
            status = .proposedMigrationExecutionRequired
            return
        }
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate()
        guard safety.identity.isDisposableMigrationTestIdentity, safety.mode == .proposedV3Migration else {
            status = .blocked(recoveryPresentation(
                code: .retryBlocked,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: "disposableIdentityInvalid",
                backupStatus: "uncertain",
                migrationPhase: "blocked",
                targetVerification: "notRun",
                retryAllowed: false
            ))
            return
        }
        let root = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot(fileManager: fileManager)
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
        let journal = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent(), fileManager: fileManager).load()
        guard let record = journal.record, record.phase == .completionRecorded else {
            status = .proposedMigrationExecutionRequired
            return
        }
        let targetURL = layout.operationTemporaryTargetURL(operationIdentity: record.operationIdentity)
        openProposedContainer(
            at: targetURL,
            sourceClassification: record.sourceClassification,
            routeEnabled: true,
            disposableIndicator: true
        )
    }

    private func openProposedContainer(
        at storeURL: URL,
        sourceClassification: ScoreKeepSourceStoreClassification,
        routeEnabled: Bool,
        disposableIndicator: Bool
    ) {
        let result = ScoreKeepProposedContainerFactory.construct(
            ScoreKeepProposedContainerFactoryInput(
                storeLocation: .disposableMigrationTarget(url: storeURL, requiresFreshDestination: false),
                writabilityMode: .writable,
                startupIntent: .productionTransitionPreparation,
                sourceClassification: sourceClassification,
                routeChoice: .proposedV3Active
            )
        )
        guard let container = result.container else {
            status = .blocked(recoveryPresentation(
                code: .proposedOpenFailed,
                protectedDataState: currentProtectedDataState(),
                capacityStatus: "notAssessed",
                sourceStatus: sourceClassification.rawValue,
                backupStatus: "uncertain",
                migrationPhase: "completionRecorded",
                targetVerification: result.diagnostics.verificationDisposition,
                retryAllowed: true
            ))
            return
        }

        let readiness = CanonicalTeamCreationWriteReadinessSnapshot(
            storeOpenedSuccessfully: true,
            sourceVersionState: .supportedCurrent,
            migrationState: .complete,
            cutoverApprovalPresent: routeEnabled
        )
        let service = SimpleTeamCreationRoutingService(
            container: container,
            routeSelection: routeEnabled ? .proposed : .legacy,
            readiness: readiness,
            activeContainerAuthority: "proposedV3",
            migrationCompletionState: "completed"
        )
        status = .ready(container, service, disposableIndicator)
    }

    private func recoveryPresentation(
        code: ScoreKeepProductionStartupDiagnosticCode,
        protectedDataState: ScoreKeepProtectedDataObservationState,
        capacityStatus: String,
        sourceStatus: String,
        backupStatus: String,
        migrationPhase: String,
        targetVerification: String,
        retryAllowed: Bool,
        retryInProgress: Bool = false
    ) -> ScoreKeepProductionStartupRecoveryPresentation {
        ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: code,
            protectedDataState: protectedDataState,
            capacityStatus: capacityStatus,
            sourceStatus: sourceStatus,
            backupStatus: backupStatus,
            migrationPhase: migrationPhase,
            targetVerification: targetVerification,
            retryAllowed: retryAllowed,
            retryInProgress: retryInProgress
        )
    }

    private func currentProtectedDataState() -> ScoreKeepProtectedDataObservationState {
        #if canImport(UIKit)
        return UIApplication.shared.isProtectedDataAvailable ? .available : .unavailable
        #else
        return .unknownOrUnsupported
        #endif
    }

    private func diagnosticCode(for error: ScoreKeepMigrationJournalError) -> ScoreKeepProductionStartupDiagnosticCode {
        switch error {
        case .unsupportedJournalVersion:
            return .journalUnsupported
        case .decodingFailed, .missingJournal, .phaseRegression, .conflictingOperationIdentity,
             .conflictingSourceIdentity, .completionRequiresVerifiedBackup, .completionRequiresPostOpenVerification,
             .uncertaintyCannotBeErased, .completedJournalConflictsWithTarget, .atomicReplacementFailed,
             .authorizationRequired:
            return .journalCorrupt
        }
    }

    private func diagnosticCode(for result: ScoreKeepMigrationOrchestratorResult) -> ScoreKeepProductionStartupDiagnosticCode {
        switch result.disposition {
        case .completed:
            return .startupCompleted
        case .interrupted:
            return .migrationInterruptedRetryable
        case .disabled, .ownershipConflict, .recoveryRequired, .writesProhibited:
            return .migrationRecoveryRequired
        case .sourcePreservationFailed:
            return .backupVerificationFailed
        case .workspaceCreationFailed:
            return .migrationRecoveryRequired
        case .constructionFailed:
            return .proposedOpenFailed
        case .destinationVerificationPending, .destinationVerified:
            return .postMigrationVerificationFailed
        case .verificationFailed:
            return .postMigrationVerificationFailed
        case .completionEvidenceFailed:
            return .completionRecordFailed
        }
    }

    private static func retryAllowed(for recovery: ScoreKeepMigrationRecoveryRequirement) -> Bool {
        switch recovery {
        case .retryPreflightWithSameOperationIdentity, .reuseVerifiedBackup, .discardIncompleteDisposableTarget, .verifyExistingTarget:
            return true
        case .noRecoveryRequired, .discardIncompleteTestOwnedBackup, .restoreFromVerifiedBackup, .requireManualReview,
             .unsupportedAutomaticRecovery, .doNotReopenThroughLegacy, .doNotRetryMigration, .writesRemainProhibited:
            return false
        }
    }

    private static func currentUnversionedContainer(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Lineup.self, Pitcher.self])
        let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func proposedV2MigratingFromV1Container(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)
        let configuration = ModelConfiguration("ScoreKeepStagedRecoveryV2", url: url, allowsSave: true)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ScoreKeepProposedTeamCreationEvidenceMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            let report = ScoreKeepSanitizedPersistentStoreErrorIdentity.makeReport(for: error)
            throw ScoreKeepStagedV1RecoveryError.v1ToV2ContainerOpenFailed(
                report
            )
        }
    }

    private static func automaticV2MaterializationContainer(url: URL) throws -> ModelContainer {
        let schema = Schema([
            Game.self,
            Team.self,
            Player.self,
            Atbat.self,
            Lineup.self,
            Pitcher.self,
            TeamCreationOperationEvidenceRecord.self
        ])
        let configuration = ModelConfiguration("ScoreKeepStagedRecoveryV2AutomaticMaterialization", schema: schema, url: url, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func v1FallbackSelected(
        journalStore: ScoreKeepMigrationJournalStore,
        fileManager: FileManager
    ) -> Bool {
        fileManager.fileExists(atPath: v1FallbackSelectionURL(journalStore: journalStore).path)
    }

    private static func recordV1FallbackSelection(
        journalStore: ScoreKeepMigrationJournalStore,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: journalStore.directory, withIntermediateDirectories: true)
        let markerURL = v1FallbackSelectionURL(journalStore: journalStore)
        guard fileManager.fileExists(atPath: markerURL.path) == false else { return }
        try Data("selected\n".utf8).write(to: markerURL, options: [.atomic])
    }

    private static func v1FallbackSelectionURL(journalStore: ScoreKeepMigrationJournalStore) -> URL {
        journalStore.directory.appendingPathComponent("V1AutomaticV2FallbackSelected-v1.marker", isDirectory: false)
    }

    private static func recordV1FallbackBoundary(
        _ boundary: ScoreKeepStagedV1RecoveryBoundary,
        assessment: ScoreKeepProductionStoreMetadataAssessment,
        journalStore: ScoreKeepMigrationJournalStore,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: journalStore.directory, withIntermediateDirectories: true)
        let content = [
            "boundary.\(boundary.rawValue)",
            assessment.sanitizedDiagnosticSummary
        ].joined(separator: "\n")
        try Data((content + "\n").utf8).write(
            to: v1FallbackBoundaryURL(boundary, journalStore: journalStore),
            options: [.atomic]
        )
    }

    private static func v1FallbackBoundaryURL(
        _ boundary: ScoreKeepStagedV1RecoveryBoundary,
        journalStore: ScoreKeepMigrationJournalStore
    ) -> URL {
        journalStore.directory.appendingPathComponent("V1Fallback-\(boundary.rawValue)-v1.marker", isDirectory: false)
    }

    private static func proposedV3MigratingFromV2Container(url _: URL) throws -> ModelContainer {
        throw ScoreKeepCompletedJournalV2SourceBaseline.BaselineError.semanticVerifierUnavailable(
            "currentTargetV2AndV3DuplicateEffectiveChecksums"
        )
    }

    private static func proposedV3ExistingContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration("ScoreKeepStagedRecoveryExistingV3", url: url, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func preserveStoreFamily(
        from sourceURL: URL,
        to destinationURL: URL,
        sourceLocation: ScoreKeepStartupStoreLocation.Kind,
        semanticRestoreVerifier: ((URL) throws -> Bool)?,
        fileManager: FileManager
    ) throws -> ScoreKeepSourcePreservationEvidence {
        try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: sourceURL,
                backupStoreURL: destinationURL,
                sourceLocation: sourceLocation,
                sourceClosureEvidence: .closedForProductionStartup,
                allowIncompleteTestOwnedBackupRemoval: false,
                semanticRestoreVerifier: semanticRestoreVerifier,
                authorizationScope: sourceLocation == .productionIntendedApplicationStore ? .productionTransitionExplicitlyAuthorized : .testOwnedDisposable
            ),
            fileManager: fileManager
        )
    }

    private static func validateV1RecoveryBackupSource(
        backupURL: URL,
        activeSourceIdentity: String,
        journal: ScoreKeepMigrationJournalRecord,
        fileManager: FileManager
    ) throws {
        let backupAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL, fileManager: fileManager)
        guard backupAssessment.sourceClassification == .proposedV1RecognizableStore else {
            throw ScoreKeepStagedV1RecoveryError.backupSourceVersionMismatch(backupAssessment)
        }
        guard journal.sourceStoreDiagnosticIdentity == activeSourceIdentity,
              journal.backupIdentity == backupAssessment.familyDiagnosticIdentity else {
            throw ScoreKeepStagedV1RecoveryError.backupSourceIdentityMismatch
        }
    }

    private static func stagedV1RecoveryErrorIdentity(_ error: Error) -> String {
        switch error {
        case ScoreKeepStagedV1RecoveryError.v2VerificationFailed:
            return "v2VerificationFailed"
        case ScoreKeepStagedV1RecoveryError.v3VerificationFailed:
            return "v3VerificationFailed"
        case ScoreKeepStagedV1RecoveryError.backupSourceVersionMismatch(let assessment):
            return "backupSourceVersionMismatch.\(assessment.sanitizedDiagnosticSummary)"
        case ScoreKeepStagedV1RecoveryError.backupSourceIdentityMismatch:
            return "backupSourceIdentityMismatch"
        case ScoreKeepStagedV1RecoveryError.v2IntermediateNotMigratable(let assessment):
            return "v2IntermediateNotMigratable.\(assessment.sanitizedDiagnosticSummary)"
        case ScoreKeepStagedV1RecoveryError.v1ToV2ContainerOpenFailed(let report):
            return "v1ToV2ContainerOpenFailed.\(report.diagnostic)"
        default:
            return ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: error)
        }
    }

    private static func baselineMatches(_ lhs: ScoreKeepMigrationBaselineRecord, _ rhs: ScoreKeepMigrationBaselineRecord) -> Bool {
        lhs.gameCount == rhs.gameCount
            && lhs.teamCount == rhs.teamCount
            && lhs.playerCount == rhs.playerCount
            && lhs.lineupCount == rhs.lineupCount
            && lhs.atbatCount == rhs.atbatCount
            && lhs.pitcherCount == rhs.pitcherCount
            && lhs.teamCreationOperationEvidenceCount == rhs.teamCreationOperationEvidenceCount
            && lhs.canonicalHistoryCount == rhs.canonicalHistoryCount
            && lhs.canonicalEventCount == rhs.canonicalEventCount
            && lhs.canonicalPayloadCount == rhs.canonicalPayloadCount
            && lhs.canonicalOperationCount == rhs.canonicalOperationCount
            && lhs.canonicalCorrectionCount == rhs.canonicalCorrectionCount
            && lhs.stableIdentityFingerprint == rhs.stableIdentityFingerprint
            && lhs.relationshipFingerprint == rhs.relationshipFingerprint
            && lhs.orderingFingerprint == rhs.orderingFingerprint
            && lhs.scoreEvidence == rhs.scoreEvidence
            && lhs.substitutionEvidence == rhs.substitutionEvidence
            && lhs.mediaOwnershipFingerprint == rhs.mediaOwnershipFingerprint
            && lhs.difficultRunnerSequence.status == rhs.difficultRunnerSequence.status
    }

    private func makeOperationIdentity(sourceStoreIdentity: String, sourceClassification: ScoreKeepSourceStoreClassification) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceStoreIdentity,
            sourceSchema: sourceClassification,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: 1,
            operationUUID: deterministicUUID(seed: sourceStoreIdentity)
        )
    }

    private func makeCompletedJournalV2RecoveryOperationIdentity(
        staleRecord: ScoreKeepMigrationJournalRecord,
        sourceStoreIdentity: String,
        generationOffset: Int
    ) -> ScoreKeepMigrationOperationIdentity {
        let applicationGeneration = staleRecord.operationIdentity.applicationMigrationGeneration + generationOffset
        let seed = "completed-journal-v2-target-recovery-\(staleRecord.operationIdentity.diagnosticToken)-\(sourceStoreIdentity)-generation-\(applicationGeneration)"
        return ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceStoreIdentity,
            sourceSchema: .existingProposedV2Store,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: applicationGeneration,
            operationUUID: deterministicUUID(seed: seed)
        )
    }

    private func makeCompletedJournalV1RecoveryOperationIdentity(
        staleRecord: ScoreKeepMigrationJournalRecord,
        sourceStoreIdentity: String,
        generationOffset: Int
    ) -> ScoreKeepMigrationOperationIdentity {
        let applicationGeneration = staleRecord.operationIdentity.applicationMigrationGeneration + generationOffset
        let seed = "completed-journal-v1-active-source-recovery-\(staleRecord.operationIdentity.diagnosticToken)-\(sourceStoreIdentity)-generation-\(applicationGeneration)"
        return ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceStoreIdentity,
            sourceSchema: .proposedV1RecognizableStore,
            targetSchema: .proposedV3,
            applicationMigrationGeneration: applicationGeneration,
            operationUUID: deterministicUUID(seed: seed)
        )
    }

    private struct CompletedJournalV2RecoveryPlan {
        let operationIdentity: ScoreKeepMigrationOperationIdentity
        let journalStore: ScoreKeepMigrationJournalStore
    }

    private func completedJournalV2RecoveryPlan(
        staleRecord: ScoreKeepMigrationJournalRecord,
        sourceStoreIdentity: String,
        layout: ScoreKeepProductionMigrationLayout,
        fileManager: FileManager
    ) -> CompletedJournalV2RecoveryPlan? {
        let selectedGenerationOffset = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { generationOffset in
            let identity = makeCompletedJournalV2RecoveryOperationIdentity(
                staleRecord: staleRecord,
                sourceStoreIdentity: sourceStoreIdentity,
                generationOffset: generationOffset
            )
            let journalStore = ScoreKeepMigrationJournalStore(
                directory: completedJournalV2RecoveryJournalDirectory(layout: layout, operationIdentity: identity),
                fileManager: fileManager
            )
            let loaded = journalStore.load()
            if loaded.error != nil {
                return .unreadable
            }
            let backupURL = layout.operationBackupStoreURL(operationIdentity: identity)
            let targetURL = layout.operationTemporaryTargetURL(operationIdentity: identity)
            return ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(
                for: loaded.record?.phase,
                hasPreservedPreBackupArtifacts: Self.hasPreservedPreBackupArtifacts(
                    phase: loaded.record?.phase,
                    artifactDirectories: [
                        backupURL.deletingLastPathComponent(),
                        targetURL.deletingLastPathComponent()
                    ],
                    fileManager: fileManager
                )
            )
        }
        guard let selectedGenerationOffset else {
            return nil
        }
        let identity = makeCompletedJournalV2RecoveryOperationIdentity(
            staleRecord: staleRecord,
            sourceStoreIdentity: sourceStoreIdentity,
            generationOffset: selectedGenerationOffset
        )
        let journalStore = ScoreKeepMigrationJournalStore(
            directory: completedJournalV2RecoveryJournalDirectory(layout: layout, operationIdentity: identity),
            fileManager: fileManager
        )
        return CompletedJournalV2RecoveryPlan(operationIdentity: identity, journalStore: journalStore)
    }

    private func completedJournalV1RecoveryPlan(
        staleRecord: ScoreKeepMigrationJournalRecord,
        sourceStoreIdentity: String,
        layout: ScoreKeepProductionMigrationLayout,
        fileManager: FileManager
    ) -> CompletedJournalV2RecoveryPlan? {
        let selectedGenerationOffset = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { generationOffset in
            let identity = makeCompletedJournalV1RecoveryOperationIdentity(
                staleRecord: staleRecord,
                sourceStoreIdentity: sourceStoreIdentity,
                generationOffset: generationOffset
            )
            let journalStore = ScoreKeepMigrationJournalStore(
                directory: completedJournalV1RecoveryJournalDirectory(layout: layout, operationIdentity: identity),
                fileManager: fileManager
            )
            let loaded = journalStore.load()
            if loaded.error != nil {
                return .unreadable
            }
            let backupURL = layout.operationBackupStoreURL(operationIdentity: identity)
            let v2URL = layout.operationTemporaryTargetStoreFamilyURL(
                operationIdentity: identity,
                familyDirectoryName: "V2IntermediateStoreFamily-v1",
                storeFileName: backupURL.lastPathComponent
            )
            let fallbackV2URL = layout.operationTemporaryTargetStoreFamilyURL(
                operationIdentity: identity,
                familyDirectoryName: "V2FallbackStoreFamily-v1",
                storeFileName: backupURL.lastPathComponent
            )
            let v3URL = layout.operationTemporaryTargetStoreFamilyURL(
                operationIdentity: identity,
                familyDirectoryName: "V3TargetStoreFamily-v1",
                storeFileName: backupURL.lastPathComponent
            )
            return ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(
                for: loaded.record?.phase,
                hasPreservedPreBackupArtifacts: Self.hasPreservedPreBackupArtifacts(
                    phase: loaded.record?.phase,
                    artifactDirectories: [
                        backupURL.deletingLastPathComponent(),
                        v2URL.deletingLastPathComponent(),
                        fallbackV2URL.deletingLastPathComponent(),
                        v3URL.deletingLastPathComponent()
                    ],
                    fileManager: fileManager
                )
            )
        }
        guard let selectedGenerationOffset else {
            return nil
        }
        let identity = makeCompletedJournalV1RecoveryOperationIdentity(
            staleRecord: staleRecord,
            sourceStoreIdentity: sourceStoreIdentity,
            generationOffset: selectedGenerationOffset
        )
        let journalStore = ScoreKeepMigrationJournalStore(
            directory: completedJournalV1RecoveryJournalDirectory(layout: layout, operationIdentity: identity),
            fileManager: fileManager
        )
        return CompletedJournalV2RecoveryPlan(operationIdentity: identity, journalStore: journalStore)
    }

    private func completedJournalV2RecoveryJournalDirectory(
        layout: ScoreKeepProductionMigrationLayout,
        operationIdentity: ScoreKeepMigrationOperationIdentity
    ) -> URL {
        layout.migrationControlRoot
            .appendingPathComponent("CompletedJournalV2TargetRecovery-v1", isDirectory: true)
            .appendingPathComponent("operation-\(operationIdentity.operationUUID.uuidString.lowercased())", isDirectory: true)
    }

    private func completedJournalV1RecoveryJournalDirectory(
        layout: ScoreKeepProductionMigrationLayout,
        operationIdentity: ScoreKeepMigrationOperationIdentity
    ) -> URL {
        layout.migrationControlRoot
            .appendingPathComponent("CompletedJournalV1ActiveSourceRecovery-v1", isDirectory: true)
            .appendingPathComponent("operation-\(operationIdentity.operationUUID.uuidString.lowercased())", isDirectory: true)
    }

    private func deterministicUUID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func hasPreservedPreBackupArtifacts(
        phase: ScoreKeepMigrationJournalPhase?,
        artifactDirectories: [URL],
        fileManager: FileManager
    ) -> Bool {
        switch phase {
        case nil, .noEvidence, .preflightStarted, .sourceClassified, .sourcePreservationStarted:
            return artifactDirectories.contains { directoryHasContents($0, fileManager: fileManager) }
        case .backupVerified, .workspaceCreationStarted, .workspaceVerified,
             .migrationAttemptStarted, .containerConstructed, .destinationVerificationPending,
             .destinationVerificationInProgress, .destinationMetadataVerified,
             .legacyReconciliationVerified, .canonicalZeroVerified, .destinationVerificationSucceeded,
             .destinationVerificationFailed,
             .postOpenVerificationStarted, .postOpenVerificationPassed, .completionRecorded,
             .recoveryRequired, .failedSafely, .completionUncertain, .disabled:
            return false
        }
    }

    private static func directoryHasContents(_ directory: URL, fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: directory.path) else { return false }
        return ((try? fileManager.contentsOfDirectory(atPath: directory.path))?.isEmpty == false)
    }

    private static func storeFamilyPrimaryExists(_ storeURL: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: storeURL.path)
    }
}

struct ScoreKeepProductionStartupHost<Content: View>: View {
    @StateObject private var startup = ScoreKeepProductionStartupModel()
    let content: () -> Content

    var body: some View {
        Group {
            switch startup.status {
            case .loading:
                ProgressView()
            case .ready(let container, let service, let disposableIndicator):
                ZStack(alignment: .top) {
                    content()
                        .modelContainer(container)
                        .environmentObject(service)
                    if disposableIndicator {
                        DisposableRehearsalSummaryBanner(container: container, service: service)
                    }
                }
            case .proposedMigrationExecutionRequired:
                ScoreKeepPhysicalMigrationExecutionView()
            case .blocked(let presentation):
                ScoreKeepStartupBlockedView(presentation: presentation, retry: startup.retry)
            }
        }
        .task {
            startup.start()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            startup.protectedDataBecameAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            startup.protectedDataWillBecomeUnavailable()
        }
        #endif
    }
}

private struct DisposableRehearsalSummaryBanner: View {
    let container: ModelContainer
    @ObservedObject var service: SimpleTeamCreationRoutingService
    @State private var copyConfirmationMessage = "Copy Summary"

    var body: some View {
        HStack(spacing: 10) {
            Text("Disposable Test Data Only")
                .font(.caption)
                .bold()
            Spacer(minLength: 8)
            Button(copyConfirmationMessage) {
                copySummary()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(.yellow.opacity(0.9))
    }

    private func copySummary() {
        let preflight = ScoreKeepPhysicalMigrationExecutionPreflight.assess(
            protectedDataState: ScoreKeepPhysicalMigrationExecutionView.initialProtectedDataStateForRehearsalSummary()
        )
        let summary = SimpleTeamCreationRoutingRehearsalSummary.make(
            container: container,
            diagnostics: service.lastDiagnostics,
            disposableBundleStatus: preflight.bundleIdentityStatus,
            migrationJournalStatus: preflight.migrationIsComplete ? "completedMigrationJournalRecognized" : preflight.journalStatus,
            migrationComparisonEvidence: preflight.postMigrationBaselineStatus,
            immutableLegacyBaselineEvidence: preflight.baselineStatus
        )
        #if canImport(UIKit)
        UIPasteboard.general.string = summary.copyableSummary
        #endif
        copyConfirmationMessage = "✓ Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copyConfirmationMessage = "Copy Summary"
        }
    }
}

private struct ScoreKeepStartupBlockedView: View {
    let presentation: ScoreKeepProductionStartupRecoveryPresentation
    let retry: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 18) {
            Text(presentation.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(presentation.explanation)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                if presentation.actions.contains(.unlockDevice) {
                    Text("Unlock this device, then try again.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Unlock this device, then try again.")
                }
                if presentation.actions.contains(.freeUpStorage) {
                    Text("Free up device storage before retrying.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Free up device storage before retrying.")
                }
                if presentation.actions.contains(.retry) {
                    Button("Retry") {
                        retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(presentation.retryAllowed == false)
                    .accessibilityLabel("Retry opening ScoreKeep data")
                }
                if presentation.actions.contains(.copySupportSummary) {
                    Button(copied ? "Copied" : "Copy Support Summary") {
                        copySupportSummary()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel(copied ? "Support summary copied" : "Copy support summary")
                }
            }
        }
        .padding()
        .frame(maxWidth: 520)
    }

    private func copySupportSummary() {
        #if canImport(UIKit)
        UIPasteboard.general.string = presentation.supportSummary
        #endif
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

}
