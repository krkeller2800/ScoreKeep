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
            Text("Proposed V3 Migration")
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

    static func initialProtectedDataStateForRehearsalSummary() -> ScoreKeepProtectedDataObservationState {
        #if canImport(UIKit)
        return UIApplication.shared.isProtectedDataAvailable ? .available : .unavailable
        #else
        return .unknownOrUnsupported
        #endif
    }

    private static func initialProtectedDataState() -> ScoreKeepProtectedDataObservationState {
        initialProtectedDataStateForRehearsalSummary()
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
            && safety.mode == .proposedV3Migration
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
            let backupURL = layout.operationBackupStoreURL(operationIdentity: operationIdentity)
            postMigrationBaselineStatus = (try? ScoreKeepPhysicalMigrationExecutor.freshProposedComparison(targetURL: targetURL, backupURL: backupURL, baseline: record)) ?? "comparisonFailedRequiresReview"
        } else {
            postMigrationBaselineStatus = "notRun"
        }

        var codes: [String] = []
        if protectedDataState != .available { codes.append("migration.start.blocked.protectedDataUnavailable") }
        if safety.identity.isDisposableMigrationTestIdentity == false { codes.append("migration.start.blocked.invalidBundle") }
        if safety.mode != .proposedV3Migration { codes.append("migration.start.blocked.invalidMode") }
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
            targetSchema: .proposedV3,
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
        var semanticBackupBaseline: ScoreKeepMigrationBaselineRecord?
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
                    semanticBackupBaseline = restoredRecord
                    return baselineMatches(restoredRecord, baseline)
                },
                semanticBaselineMismatchDiagnosticLines: {
                    guard let semanticBackupBaseline else {
                        return ["baselineMismatch.fields=unavailable"]
                    }
                    return ScoreKeepMigrationBaselineCapture.baselineMismatchDiagnosticLines(expected: baseline, actual: semanticBackupBaseline)
                },
                postOpenVerifier: { container in
                    let record = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
                    return baselineMatches(record, baseline)
                }
            ),
            journalStore: journalStore
        )
        let freshComparison = try freshProposedComparison(targetURL: targetURL, backupURL: backupURL, baseline: baseline)
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
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration("ScoreKeepPhysicalMigrationFreshVerification", url: url, allowsSave: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func freshProposedComparison(targetURL: URL, backupURL: URL? = nil, baseline: ScoreKeepMigrationBaselineRecord) throws -> String {
        if let backupURL {
            let backupAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: backupURL)
            guard backupAssessment.sourceClassification == .existingProposedV2Store else {
                return "backupMetadataMismatch.\(backupAssessment.sourceClassification.rawValue)"
            }
        }
        let targetAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: targetURL)
        guard targetAssessment.sourceClassification == .existingProposedV3Store else {
            return "targetMetadataMismatch.\(targetAssessment.sourceClassification.rawValue)"
        }
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
            && lhs.canonicalHistoryCount == rhs.canonicalHistoryCount
            && lhs.canonicalEventCount == rhs.canonicalEventCount
            && lhs.canonicalPayloadCount == rhs.canonicalPayloadCount
            && lhs.canonicalOperationCount == rhs.canonicalOperationCount
            && lhs.canonicalCorrectionCount == rhs.canonicalCorrectionCount
            && lhs.legacyScoringOperationEvidenceCount == rhs.legacyScoringOperationEvidenceCount
            && lhs.stableIdentityFingerprint == rhs.stableIdentityFingerprint
            && lhs.relationshipFingerprint == rhs.relationshipFingerprint
            && lhs.orderingFingerprint == rhs.orderingFingerprint
            && lhs.scoreEvidence == rhs.scoreEvidence
            && lhs.substitutionEvidence == rhs.substitutionEvidence
            && lhs.mediaOwnershipFingerprint == rhs.mediaOwnershipFingerprint
            && lhs.difficultRunnerSequence.status == rhs.difficultRunnerSequence.status
    }
}

enum ScoreKeepPostMigrationComparisonStatus: String, Hashable, Sendable {
    case matchesStoredLegacyBaseline
    case authorizedAdditiveChangeMatches
    case mismatchRequiresReview
}

struct ScoreKeepPostMigrationComparisonResult: Hashable, Sendable {
    let status: ScoreKeepPostMigrationComparisonStatus
    let diagnosticCodes: [String]
}

@MainActor
enum ScoreKeepPostMigrationAuthorizedAdditiveComparison {
    static func compare(
        proposedContainer: ModelContainer,
        originalContainer: ModelContainer,
        storedBaseline: ScoreKeepMigrationBaselineRecord
    ) throws -> ScoreKeepPostMigrationComparisonResult {
        let proposedContext = ModelContext(proposedContainer)
        proposedContext.autosaveEnabled = false
        let originalContext = ModelContext(originalContainer)
        originalContext.autosaveEnabled = false

        let proposedRecord = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: proposedContext)
        let originalRecord = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: originalContext)
        guard baselineMatches(originalRecord, storedBaseline) else {
            return result(.mismatchRequiresReview, "storedBaselineDoesNotMatchBackup")
        }

        let proposedSnapshot = try ScoreKeepBaseballIntegritySnapshot.capture(modelContext: proposedContext)
        let originalSnapshot = try ScoreKeepBaseballIntegritySnapshot.capture(modelContext: originalContext)
        let evidence = try proposedContext.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>())
        if proposedSnapshot == originalSnapshot && evidence.isEmpty {
            return result(.matchesStoredLegacyBaseline, "exactPostMigrationBaselineMatch")
        }
        let proposedBaselineDiagnostics = baselineDifferenceDiagnostics(proposedRecord, storedBaseline)
        if evidence.isEmpty {
            return result(
                .mismatchRequiresReview,
                ["originalBaseballRecordsChanged"] + proposedSnapshot.differenceDiagnostics(from: originalSnapshot) + proposedBaselineDiagnostics + ["operationEvidenceAbsent"]
            )
        }

        let completedEvidence = evidence.filter {
            $0.phase == CanonicalTeamCreationOperationPhase.completed.rawValue
                && $0.completionProof == CanonicalTeamCreationCompletionProof.completionMarkerRecorded.rawValue
        }
        guard evidence.count == 1, completedEvidence.count == 1, let routedTeamIdentity = completedEvidence.first?.targetTeamIdentity else {
            return result(.mismatchRequiresReview, "operationEvidenceUnexpected")
        }

        let teams = try proposedContext.fetch(FetchDescriptor<Team>())
        let routedTeams = teams.filter { $0.ident == routedTeamIdentity }
        guard routedTeams.count == 1, let routedTeam = routedTeams.first else {
            return result(.mismatchRequiresReview, "routedTeamMissingOrDuplicated")
        }
        guard routedTeam.players.isEmpty, routedTeam.games.isEmpty, routedTeam.logo == nil else {
            return result(.mismatchRequiresReview, "routedTeamHasUnexpectedRelationshipsOrMedia")
        }
        guard proposedRecord.gameCount == storedBaseline.gameCount,
              proposedRecord.teamCount == storedBaseline.teamCount + 1,
              proposedRecord.playerCount == storedBaseline.playerCount,
              proposedRecord.lineupCount == storedBaseline.lineupCount,
              proposedRecord.atbatCount == storedBaseline.atbatCount,
              proposedRecord.pitcherCount == storedBaseline.pitcherCount,
              proposedRecord.scoreEvidence == storedBaseline.scoreEvidence,
              proposedRecord.substitutionEvidence == storedBaseline.substitutionEvidence,
              proposedRecord.difficultRunnerSequence.status == storedBaseline.difficultRunnerSequence.status else {
            return result(
                .mismatchRequiresReview,
                ["baselineCountsOrCriticalFingerprintsUnexpected"] + proposedBaselineDiagnostics
            )
        }

        let proposedWithoutRoutedTeam = try ScoreKeepBaseballIntegritySnapshot.capture(
            modelContext: proposedContext,
            excludingTeamIdentities: [routedTeamIdentity]
        )
        guard proposedWithoutRoutedTeam == originalSnapshot else {
            return result(
                .mismatchRequiresReview,
                ["originalBaseballRecordsChanged"] + proposedWithoutRoutedTeam.differenceDiagnostics(from: originalSnapshot)
            )
        }

        return result(
            .authorizedAdditiveChangeMatches,
            "originalGamesUnchanged",
            "originalTeamsUnchanged",
            "originalPlayersUnchanged",
            "originalLineupsUnchanged",
            "originalAtbatsUnchanged",
            "originalPitchersUnchanged",
            "scoreFingerprintUnchanged:\(storedBaseline.scoreEvidence)",
            "substitutionFingerprintUnchanged:\(storedBaseline.substitutionEvidence)",
            "runnerEvidenceUnchanged:\(storedBaseline.difficultRunnerSequence.status)",
            "oneAuthorizedTeamAdded",
            "oneDurableOperationEvidenceRecord"
        )
    }

    private static func result(_ status: ScoreKeepPostMigrationComparisonStatus, _ codes: String...) -> ScoreKeepPostMigrationComparisonResult {
        ScoreKeepPostMigrationComparisonResult(status: status, diagnosticCodes: codes)
    }

    private static func result(_ status: ScoreKeepPostMigrationComparisonStatus, _ codes: [String]) -> ScoreKeepPostMigrationComparisonResult {
        ScoreKeepPostMigrationComparisonResult(status: status, diagnosticCodes: codes)
    }

    private static func baselineMatches(_ lhs: ScoreKeepMigrationBaselineRecord, _ rhs: ScoreKeepMigrationBaselineRecord) -> Bool {
        lhs.gameCount == rhs.gameCount
            && lhs.teamCount == rhs.teamCount
            && lhs.playerCount == rhs.playerCount
            && lhs.lineupCount == rhs.lineupCount
            && lhs.atbatCount == rhs.atbatCount
            && lhs.pitcherCount == rhs.pitcherCount
            && lhs.canonicalHistoryCount == rhs.canonicalHistoryCount
            && lhs.canonicalEventCount == rhs.canonicalEventCount
            && lhs.canonicalPayloadCount == rhs.canonicalPayloadCount
            && lhs.canonicalOperationCount == rhs.canonicalOperationCount
            && lhs.canonicalCorrectionCount == rhs.canonicalCorrectionCount
            && lhs.legacyScoringOperationEvidenceCount == rhs.legacyScoringOperationEvidenceCount
            && lhs.stableIdentityFingerprint == rhs.stableIdentityFingerprint
            && lhs.relationshipFingerprint == rhs.relationshipFingerprint
            && lhs.orderingFingerprint == rhs.orderingFingerprint
            && lhs.scoreEvidence == rhs.scoreEvidence
            && lhs.substitutionEvidence == rhs.substitutionEvidence
            && lhs.mediaOwnershipFingerprint == rhs.mediaOwnershipFingerprint
            && lhs.difficultRunnerSequence.status == rhs.difficultRunnerSequence.status
    }

    private static func baselineDifferenceDiagnostics(_ lhs: ScoreKeepMigrationBaselineRecord, _ rhs: ScoreKeepMigrationBaselineRecord) -> [String] {
        var codes: [String] = []
        if lhs.gameCount != rhs.gameCount { codes.append("gameCountDiffers") }
        if lhs.teamCount != rhs.teamCount { codes.append("teamCountDiffers") }
        if lhs.playerCount != rhs.playerCount { codes.append("playerCountDiffers") }
        if lhs.lineupCount != rhs.lineupCount { codes.append("lineupCountDiffers") }
        if lhs.atbatCount != rhs.atbatCount { codes.append("atbatCountDiffers") }
        if lhs.pitcherCount != rhs.pitcherCount { codes.append("pitcherCountDiffers") }
        if lhs.canonicalHistoryCount != rhs.canonicalHistoryCount { codes.append("canonicalHistoryCountDiffers") }
        if lhs.canonicalEventCount != rhs.canonicalEventCount { codes.append("canonicalEventCountDiffers") }
        if lhs.canonicalPayloadCount != rhs.canonicalPayloadCount { codes.append("canonicalPayloadCountDiffers") }
        if lhs.canonicalOperationCount != rhs.canonicalOperationCount { codes.append("canonicalOperationCountDiffers") }
        if lhs.canonicalCorrectionCount != rhs.canonicalCorrectionCount { codes.append("canonicalCorrectionCountDiffers") }
        if lhs.legacyScoringOperationEvidenceCount != rhs.legacyScoringOperationEvidenceCount { codes.append("legacyScoringOperationEvidenceCountDiffers") }
        if lhs.stableIdentityFingerprint != rhs.stableIdentityFingerprint { codes.append("stableIdentityFingerprintDiffers") }
        if lhs.relationshipFingerprint != rhs.relationshipFingerprint { codes.append("relationshipFingerprintDiffers") }
        if lhs.orderingFingerprint != rhs.orderingFingerprint { codes.append("relationshipOrderingFingerprintDiffers") }
        if lhs.scoreEvidence != rhs.scoreEvidence { codes.append("scoreFingerprintDiffers") }
        if lhs.substitutionEvidence != rhs.substitutionEvidence { codes.append("substitutionFingerprintDiffers") }
        if lhs.mediaOwnershipFingerprint != rhs.mediaOwnershipFingerprint { codes.append("mediaFingerprintDiffers") }
        if lhs.difficultRunnerSequence.status != rhs.difficultRunnerSequence.status { codes.append("runnerEvidenceDiffers") }
        return codes
    }
}

private struct ScoreKeepBaseballIntegritySnapshot: Hashable {
    let games: [String]
    let teams: [String]
    let players: [String]
    let lineups: [String]
    let atbats: [String]
    let pitchers: [String]

    func differenceDiagnostics(from original: ScoreKeepBaseballIntegritySnapshot) -> [String] {
        var codes: [String] = []
        if games != original.games { codes.append("gameRecordsDiffer") }
        if teams != original.teams { codes.append("teamRecordsDiffer") }
        if players != original.players { codes.append("playerRecordsDiffer") }
        if lineups != original.lineups { codes.append("lineupRecordsDiffer") }
        if atbats != original.atbats { codes.append("atbatRecordsDiffer") }
        if pitchers != original.pitchers { codes.append("pitcherRecordsDiffer") }
        return codes
    }

    @MainActor
    static func capture(modelContext: ModelContext, excludingTeamIdentities: Set<UUID> = []) throws -> ScoreKeepBaseballIntegritySnapshot {
        let games = try modelContext.fetch(FetchDescriptor<Game>())
        let teams = try modelContext.fetch(FetchDescriptor<Team>()).filter { excludingTeamIdentities.contains($0.ident) == false }
        let players = try modelContext.fetch(FetchDescriptor<Player>())
        let lineups = try modelContext.fetch(FetchDescriptor<Lineup>())
        let atbats = try modelContext.fetch(FetchDescriptor<Atbat>())
        let pitchers = try modelContext.fetch(FetchDescriptor<Pitcher>())
        return ScoreKeepBaseballIntegritySnapshot(
            games: games.map(gameEvidence).sorted(),
            teams: teams.map { teamEvidence($0, games: games) }.sorted(),
            players: players.map(playerEvidence).sorted(),
            lineups: lineups.map(lineupEvidence).sorted(),
            atbats: atbats.map(atbatEvidence).sorted(),
            pitchers: pitchers.map(pitcherEvidence).sorted()
        )
    }

    private static func gameEvidence(_ game: Game) -> String {
        [
            "game", game.ident.uuidString,
            game.date,
            game.location,
            game.highLights,
            String(game.hscore),
            String(game.vscore),
            String(game.everyOneHits),
            String(game.numInnings),
            game.vteam?.ident.uuidString ?? "nil",
            game.hteam?.ident.uuidString ?? "nil",
            game.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
            game.atbats.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.lineups.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.pitchers.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.replaced.map { $0.identifier.uuidString }.joined(separator: ","),
            game.incomings.map { $0.identifier.uuidString }.joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func teamEvidence(_ team: Team, games: [Game]) -> String {
        let canonicalGameIdentities = games.filter {
            $0.hteam?.ident == team.ident || $0.vteam?.ident == team.ident
        }
        .map { $0.ident.uuidString }
        .sorted()
        .joined(separator: ",")
        return [
            "team", team.ident.uuidString,
            team.name,
            team.coach,
            team.details,
            team.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
            canonicalGameIdentities,
            dataFingerprint(team.logo)
        ].joined(separator: "|")
    }

    private static func playerEvidence(_ player: Player) -> String {
        [
            "player", player.identifier.uuidString,
            player.name,
            player.number,
            player.position,
            player.batDir,
            String(player.batOrder),
            player.team?.ident.uuidString ?? "nil",
            player.atbat.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            dataFingerprint(player.photo)
        ].joined(separator: "|")
    }

    private static func lineupEvidence(_ lineup: Lineup) -> String {
        [
            "lineup", lineup.ident.uuidString,
            String(lineup.everyoneHits),
            lineup.game.ident.uuidString,
            lineup.team.ident.uuidString,
            String(lineup.inning),
            lineup.players.sorted { lhs, rhs in
                lhs.batOrder == rhs.batOrder ? lhs.identifier.uuidString < rhs.identifier.uuidString : lhs.batOrder < rhs.batOrder
            }
            .map { $0.identifier.uuidString }
            .joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func atbatEvidence(_ atbat: Atbat) -> String {
        [
            "atbat", atbat.ident.uuidString,
            atbat.game.ident.uuidString,
            atbat.team.ident.uuidString,
            atbat.player.identifier.uuidString,
            atbat.result,
            atbat.maxbase,
            String(atbat.batOrder),
            atbat.outAt,
            String(Double(atbat.inning)),
            String(atbat.seq),
            String(atbat.col),
            String(atbat.rbis),
            String(atbat.outs),
            String(atbat.sacFly),
            String(atbat.sacBunt),
            String(atbat.stolenBases),
            String(atbat.earnedRun),
            atbat.playRec,
            String(atbat.endOfInning)
        ].joined(separator: "|")
    }

    private static func pitcherEvidence(_ pitcher: Pitcher) -> String {
        [
            "pitcher", pitcher.ident.uuidString,
            pitcher.player.identifier.uuidString,
            pitcher.team.ident.uuidString,
            pitcher.game.ident.uuidString,
            String(pitcher.startInn),
            String(pitcher.sOuts),
            String(pitcher.sBats),
            String(pitcher.endInn),
            String(pitcher.eOuts),
            String(pitcher.eBats),
            String(pitcher.strikeOuts),
            String(pitcher.walks),
            String(pitcher.hits),
            String(pitcher.runs),
            String(pitcher.won)
        ].joined(separator: "|")
    }

    private static func dataFingerprint(_ data: Data?) -> String {
        guard let data, data.isEmpty == false else { return "absent" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}
