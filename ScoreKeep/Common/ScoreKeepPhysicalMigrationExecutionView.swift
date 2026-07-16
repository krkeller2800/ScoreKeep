import CryptoKit
import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ScoreKeepPhysicalMigrationExecutionView: View {
    @State private var protectedDataState: ScoreKeepProtectedDataObservationState = Self.initialProtectedDataState()
    @State private var preflight = ScoreKeepPhysicalMigrationExecutionPreflight.assess(protectedDataState: Self.initialProtectedDataState())
    @State private var result: ScoreKeepPhysicalMigrationExecutionResult?
    @State private var isRunning = false
    @State private var copyConfirmationMessage = "Copy Summary"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    statusBlock
                    if let result {
                        resultBlock(result)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            Divider()
            controls
                .padding(20)
                .background(.background)
        }
        .font(.body)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataState = .becameAvailable
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataState = .willBecomeUnavailable
            refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ScoreKeep Migration Test")
                .font(.title2.weight(.semibold))
            Text("Proposed V2 Migration")
                .font(.headline)
            Text("Disposable Test Data Only")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
        }
        .accessibilityIdentifier("ScoreKeepMigrationExecutionHeader")
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Protected Data: \(preflight.protectedDataState.rawValue)")
            Text("Bundle: \(preflight.bundleIdentityStatus)")
            Text("Baseline: \(preflight.baselineStatus)")
            Text("Store Family: \(preflight.storeFamilyStatus)")
            Text("Journal: \(preflight.journalStatus)")
            Text("Backup: \(preflight.backupStatus)")
            Text("Capacity: \(preflight.capacityStatus)")
            Text("Readiness: \(preflight.readinessStatus)")
            Text("Post-Migration Baseline: \(preflight.postMigrationBaselineStatus)")
            Text("Runner Sequence: \(preflight.runnerSequenceStatus)")
        }
        .font(.callout)
        .textSelection(.enabled)
    }

    private func resultBlock(_ result: ScoreKeepPhysicalMigrationExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Last Result: \(result.disposition)")
            Text("Migration Phase: \(result.migrationPhase)")
            Text("Backup: \(result.backupStatus)")
            Text("Post-Migration Baseline: \(result.baselineComparisonStatus)")
            Text("Writes: \(result.writeReadiness)")
            Text("Codes: \(result.diagnosticCodes.joined(separator: ","))")
        }
        .font(.callout.monospaced())
        .textSelection(.enabled)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Refresh Checks") {
                refresh()
            }
            .buttonStyle(.bordered)

            Button(copyConfirmationMessage) {
                copySummary()
            }
            .buttonStyle(.bordered)

            Button(isRunning ? "Migration Running" : "Start Controlled Migration") {
                startMigration()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || preflight.isReadyForFinalAuthorization == false)
        }
    }

    private func refresh() {
        preflight = ScoreKeepPhysicalMigrationExecutionPreflight.assess(protectedDataState: protectedDataState)
    }

    private func copySummary() {
        UIPasteboard.general.string = preflight.copyableSummary(result: result)
        copyConfirmationMessage = "✓ Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copyConfirmationMessage = "Copy Summary"
        }
    }

    private func startMigration() {
        guard preflight.isReadyForFinalAuthorization else { return }
        isRunning = true
        do {
            result = try ScoreKeepPhysicalMigrationExecutor.run(preflight: preflight)
        } catch {
            result = ScoreKeepPhysicalMigrationExecutionResult.failure(message: String(describing: error))
        }
        isRunning = false
        refresh()
    }

    private static func initialProtectedDataState() -> ScoreKeepProtectedDataObservationState {
        #if canImport(UIKit)
        return UIApplication.shared.isProtectedDataAvailable ? .available : .unavailable
        #else
        return .unknownOrUnsupported
        #endif
    }
}

struct ScoreKeepPhysicalMigrationExecutionPreflight: Hashable, Sendable {
    let protectedDataState: ScoreKeepProtectedDataObservationState
    let safety: ScoreKeepPhysicalMigrationTestSafety
    let baselineLoadResult: ScoreKeepMigrationBaselineLoadResult
    let layout: ScoreKeepProductionMigrationLayout
    let storeFamilyStatus: String
    let storeFamilyIdentity: String?
    let operationIdentity: ScoreKeepMigrationOperationIdentity?
    let journalStatus: String
    let backupStatus: String
    let capacityStatus: String
    let postMigrationBaselineStatus: String
    let readinessCodes: [String]

    var baselineStatus: String { baselineLoadResult.statusMessage }
    var runnerSequenceStatus: String { baselineLoadResult.record?.difficultRunnerSequence.status ?? "unavailable" }
    var bundleIdentityStatus: String { safety.identity.isDisposableMigrationTestIdentity ? "disposableMigrationTest" : "invalid" }
    var migrationIsComplete: Bool { journalStatus == ScoreKeepMigrationJournalPhase.completionRecorded.rawValue }
    var readinessStatus: String {
        if migrationIsComplete { return "completedMigrationRecorded" }
        return isReadyForFinalAuthorization ? "readyForFinalManualAuthorization" : "blocked"
    }

    var isReadyForFinalAuthorization: Bool {
        migrationIsComplete == false
            && protectedDataState == .available
            && safety.identity.isDisposableMigrationTestIdentity
            && safety.mode == .proposedV2Migration
            && baselineLoadResult.record != nil
            && storeFamilyIdentity != nil
            && operationIdentity != nil
            && capacityStatus == "capacity.sufficient"
    }

    @MainActor
    static func assess(protectedDataState: ScoreKeepProtectedDataObservationState, fileManager: FileManager = .default) -> ScoreKeepPhysicalMigrationExecutionPreflight {
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate()
        let applicationSupportRoot = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot(fileManager: fileManager)
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: applicationSupportRoot)
        let baseline = ScoreKeepMigrationBaselineCapture.loadResult(fileManager: fileManager, applicationSupportRoot: applicationSupportRoot)
        let family = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore, fileManager: fileManager)
        let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(
            input: ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: family?.members.reduce(UInt64(0)) { $0 + $1.byteCount } ?? 0),
            volume: ScoreKeepMigrationCapacityCalculator.queryVolume(at: layout.applicationSupportRoot)
        )
        let journalStore = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent(), fileManager: fileManager)
        let journal = journalStore.load().record
        let operationIdentity = journal?.operationIdentity ?? family.map { makeOperationIdentity(sourceStoreIdentity: $0.diagnosticIdentity) }
        let backupStatus: String
        if let operationIdentity {
            let backupURL = layout.operationBackupStoreURL(operationIdentity: operationIdentity)
            backupStatus = (try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL, fileManager: fileManager)) == nil ? "absent" : "present"
        } else {
            backupStatus = "absent"
        }
        let postMigrationBaselineStatus: String
        if journal?.phase == .completionRecorded, let operationIdentity, let record = baseline.record {
            let targetURL = layout.operationTemporaryTargetURL(operationIdentity: operationIdentity)
            postMigrationBaselineStatus = (try? ScoreKeepPhysicalMigrationExecutor.freshProposedComparison(targetURL: targetURL, baseline: record)) ?? "comparisonFailedRequiresReview"
        } else {
            postMigrationBaselineStatus = "notRun"
        }

        var codes: [String] = []
        if protectedDataState != .available { codes.append("migration.start.blocked.protectedDataUnavailable") }
        if safety.identity.isDisposableMigrationTestIdentity == false { codes.append("migration.start.blocked.invalidBundle") }
        if safety.mode != .proposedV2Migration { codes.append("migration.start.blocked.invalidMode") }
        if baseline.record == nil { codes.append("migration.start.blocked.baselineMissing") }
        if family == nil { codes.append("migration.start.blocked.storeFamilyMissing") }
        if journal?.phase == .completionRecorded { codes.append("migration.completed.reauthorizationBlocked") }
        if capacity.diagnosticCode != "capacity.sufficient" { codes.append(capacity.diagnosticCode) }

        return ScoreKeepPhysicalMigrationExecutionPreflight(
            protectedDataState: protectedDataState,
            safety: safety,
            baselineLoadResult: baseline,
            layout: layout,
            storeFamilyStatus: family.map { $0.fileNames.joined(separator: ",") } ?? "missing",
            storeFamilyIdentity: family?.diagnosticIdentity,
            operationIdentity: operationIdentity,
            journalStatus: journal.map { $0.phase.rawValue } ?? "absent",
            backupStatus: backupStatus,
            capacityStatus: capacity.diagnosticCode,
            postMigrationBaselineStatus: postMigrationBaselineStatus,
            readinessCodes: codes
        )
    }

    func copyableSummary(result: ScoreKeepPhysicalMigrationExecutionResult?) -> String {
        var lines = [
            "ScoreKeep Migration Execution Checkpoint",
            "Mode: \(safety.mode.displayTitle)",
            "Bundle: \(bundleIdentityStatus)",
            "Protected Data: \(protectedDataState.rawValue)",
            "Baseline: \(baselineStatus)",
            "Store Family: \(storeFamilyStatus)",
            "Journal: \(journalStatus)",
            "Backup: \(backupStatus)",
            "Capacity: \(capacityStatus)",
            "Readiness: \(readinessStatus)",
            "Post-Migration Baseline: \(postMigrationBaselineStatus)",
            "Runner Sequence: \(runnerSequenceStatus)",
            "Codes: \(readinessCodes.joined(separator: ","))"
        ]
        if let record = baselineLoadResult.record {
            lines.append("")
            lines.append(record.summary)
        }
        if let result {
            lines.append("")
            lines.append(result.summary)
        }
        return lines.joined(separator: "\n")
    }

    private static func makeOperationIdentity(sourceStoreIdentity: String) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: sourceStoreIdentity,
            sourceSchema: .populatedCurrentUnversionedStore,
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: deterministicUUID(seed: sourceStoreIdentity)
        )
    }

    private static func deterministicUUID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

struct ScoreKeepPhysicalMigrationExecutionResult: Hashable, Sendable {
    let disposition: String
    let migrationPhase: String
    let backupStatus: String
    let baselineComparisonStatus: String
    let writeReadiness: String
    let diagnosticCodes: [String]

    var summary: String {
        [
            "Migration Result: \(disposition)",
            "Migration Phase: \(migrationPhase)",
            "Backup: \(backupStatus)",
            "Baseline Comparison: \(baselineComparisonStatus)",
            "Writes: \(writeReadiness)",
            "Codes: \(diagnosticCodes.joined(separator: ","))"
        ].joined(separator: "\n")
    }

    static func failure(message: String) -> ScoreKeepPhysicalMigrationExecutionResult {
        ScoreKeepPhysicalMigrationExecutionResult(
            disposition: "failedBeforeResult",
            migrationPhase: "unknown",
            backupStatus: "unknown",
            baselineComparisonStatus: "notRun",
            writeReadiness: "prohibited",
            diagnosticCodes: ["migration.execution.error", String(message.prefix(80))]
        )
    }
}

@MainActor
enum ScoreKeepPhysicalMigrationExecutor {
    static func run(preflight: ScoreKeepPhysicalMigrationExecutionPreflight, fileManager: FileManager = .default) throws -> ScoreKeepPhysicalMigrationExecutionResult {
        guard preflight.isReadyForFinalAuthorization else {
            return ScoreKeepPhysicalMigrationExecutionResult(
                disposition: "blockedBeforeAuthorization",
                migrationPhase: preflight.journalStatus,
                backupStatus: preflight.backupStatus,
                baselineComparisonStatus: preflight.baselineStatus,
                writeReadiness: "prohibited",
                diagnosticCodes: preflight.readinessCodes
            )
        }
        guard let operationIdentity = preflight.operationIdentity,
              let baseline = preflight.baselineLoadResult.record else {
            return ScoreKeepPhysicalMigrationExecutionResult.failure(message: "missing operation identity or baseline")
        }

        let backupURL = preflight.layout.operationBackupStoreURL(operationIdentity: operationIdentity)
        let targetURL = preflight.layout.operationTemporaryTargetURL(operationIdentity: operationIdentity)
        let journalStore = ScoreKeepMigrationJournalStore(directory: preflight.layout.journal.deletingLastPathComponent(), fileManager: fileManager)
        let result = try ScoreKeepMigrationOrchestrator.run(
            input: ScoreKeepMigrationOrchestratorInput(
                operationIdentity: operationIdentity,
                sourceStoreURL: preflight.layout.activeStore,
                backupStoreURL: backupURL,
                targetStoreURL: targetURL,
                sourceClassification: .populatedCurrentUnversionedStore,
                disableState: .proposedTransitionExplicitlyAuthorized,
                authorizationEvidence: "physical-device-disposable-test-authorization",
                sourceClosureEvidence: .closedForDisposableVerification,
                interruptionPoint: nil,
                factoryInjection: nil,
                semanticRestoreVerifier: { restoreURL in
                    let restored = try currentUnversionedContainer(url: restoreURL, allowsSave: false)
                    let restoredRecord = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: restored.mainContext)
                    return baselineMatches(restoredRecord, baseline)
                },
                postOpenVerifier: { container in
                    let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                    return baselineMatches(record, baseline)
                }
            ),
            journalStore: journalStore
        )
        let freshComparison = try freshProposedComparison(targetURL: targetURL, baseline: baseline)
        let backupPresent = (try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL, fileManager: fileManager)) == nil ? "absent" : "verifiedBackupPresent"
        return ScoreKeepPhysicalMigrationExecutionResult(
            disposition: result.disposition.rawValue,
            migrationPhase: result.journal.phase.rawValue,
            backupStatus: backupPresent,
            baselineComparisonStatus: freshComparison,
            writeReadiness: result.writeReadiness.permitsBaseballWrites ? "unexpectedlyPermitted" : "prohibited",
            diagnosticCodes: result.diagnostics.map(\.rawValue) + [baseline.difficultRunnerSequence.status]
        )
    }

    private static func currentUnversionedContainer(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Lineup.self, Pitcher.self])
        let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func proposedContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(ScoreKeepProposedVersionedSchema.V2.models)
        let configuration = ModelConfiguration("ScoreKeepPhysicalMigrationFreshVerification", schema: schema, url: url, allowsSave: false)
        return try ModelContainer(for: schema, migrationPlan: ScoreKeepProposedTeamCreationEvidenceMigrationPlan.self, configurations: [configuration])
    }

    static func freshProposedComparison(targetURL: URL, baseline: ScoreKeepMigrationBaselineRecord) throws -> String {
        let container = try proposedContainer(url: targetURL)
        let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
        return baselineMatches(record, baseline) ? "matchesStoredLegacyBaseline" : "mismatchRequiresReview"
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
}
