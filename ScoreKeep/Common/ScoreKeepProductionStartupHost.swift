import CryptoKit
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
            openProposedContainer(
                at: targetURL,
                sourceClassification: record.sourceClassification,
                routeEnabled: true,
                disposableIndicator: false
            )
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
        let sourceClassification: ScoreKeepSourceStoreClassification = family == nil ? .noStoreExists : .populatedCurrentUnversionedStore
        guard sourceClassification.isSupportedForProposedV2Startup else {
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
        guard safety.identity.isDisposableMigrationTestIdentity, safety.mode == .proposedV2Migration else {
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
                routeChoice: .proposedV2Active
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
            activeContainerAuthority: "proposedV2",
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
        case .constructionFailed:
            return .proposedOpenFailed
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

    private static func baselineMatches(_ lhs: ScoreKeepMigrationBaselineRecord, _ rhs: ScoreKeepMigrationBaselineRecord) -> Bool {
        lhs.gameCount == rhs.gameCount
            && lhs.teamCount == rhs.teamCount
            && lhs.playerCount == rhs.playerCount
            && lhs.lineupCount == rhs.lineupCount
            && lhs.atbatCount == rhs.atbatCount
            && lhs.pitcherCount == rhs.pitcherCount
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
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: deterministicUUID(seed: sourceStoreIdentity)
        )
    }

    private func deterministicUUID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
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
