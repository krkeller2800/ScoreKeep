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

enum ScoreKeepProductionStartupStatus: Hashable {
    case loading
    case ready(ModelContainer, SimpleTeamCreationRoutingService, Bool)
    case proposedMigrationExecutionRequired
    case blocked(String)

    static func == (lhs: ScoreKeepProductionStartupStatus, rhs: ScoreKeepProductionStartupStatus) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.proposedMigrationExecutionRequired, .proposedMigrationExecutionRequired):
            return true
        case (.blocked(let lhsMessage), .blocked(let rhsMessage)):
            return lhsMessage == rhsMessage
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
        case .blocked(let message):
            hasher.combine("blocked")
            hasher.combine(message)
        }
    }
}

@MainActor
final class ScoreKeepProductionStartupModel: ObservableObject {
    @Published private(set) var status: ScoreKeepProductionStartupStatus = .loading
    private var didStart = false

    func start() {
        guard didStart == false else { return }
        didStart = true

        #if SCOREKEEP_MIGRATION_TEST_PROPOSED
        startDisposableProposedRehearsalOrExecution()
        #else
        if ScoreKeepProductionStartupRouteApproval.simpleTeamCreationProductionEnabled {
            startProductionProposedIfComplete()
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
            status = .blocked("ScoreKeep cannot safely open your data right now.")
        }
    }

    private func startProductionProposedIfComplete(fileManager: FileManager = .default) {
        let root = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot(fileManager: fileManager)
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
        let journalStore = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent(), fileManager: fileManager)
        let journal = journalStore.load()
        guard journal.error == nil else {
            status = .blocked("ScoreKeep cannot safely open your data right now.")
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
        runProductionMigration(layout: layout, journalStore: journalStore, fileManager: fileManager)
    }

    private func runProductionMigration(
        layout: ScoreKeepProductionMigrationLayout,
        journalStore: ScoreKeepMigrationJournalStore,
        fileManager: FileManager
    ) {
        let family = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore, fileManager: fileManager)
        let sourceClassification: ScoreKeepSourceStoreClassification = family == nil ? .noStoreExists : .populatedCurrentUnversionedStore
        guard sourceClassification.isSupportedForProposedV2Startup else {
            status = .blocked("ScoreKeep cannot safely open your data right now.")
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
                status = .blocked("ScoreKeep needs more device storage before it can safely prepare your data.")
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
                status = .blocked("ScoreKeep could not verify your prepared data. No new changes will be saved.")
                return
            }
            openProposedContainer(
                at: targetURL,
                sourceClassification: sourceClassification,
                routeEnabled: true,
                disposableIndicator: false
            )
        } catch {
            status = .blocked("ScoreKeep could not safely prepare your data. No new changes will be saved.")
        }
    }

    private func startDisposableProposedRehearsalOrExecution(fileManager: FileManager = .default) {
        guard ScoreKeepProductionStartupRouteApproval.disposableProposedNormalUIRehearsalEnabled else {
            status = .proposedMigrationExecutionRequired
            return
        }
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate()
        guard safety.identity.isDisposableMigrationTestIdentity, safety.mode == .proposedV2Migration else {
            status = .blocked("This test build cannot safely open data.")
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
            status = .blocked("ScoreKeep cannot safely open your prepared data right now.")
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
            case .blocked(let message):
                ScoreKeepStartupBlockedView(message: message)
            }
        }
        .task {
            startup.start()
        }
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
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("No changes will be saved until ScoreKeep can open your data safely.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
