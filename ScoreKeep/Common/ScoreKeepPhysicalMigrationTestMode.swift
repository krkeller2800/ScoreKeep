import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ScoreKeepPhysicalMigrationTestIdentity: Hashable, Sendable {
    static let disposableBundleIdentifier = "com.komakode.ScoreKeepMigrationTest"
    static let productionBundleIdentifier = "Komakode.ScoreKeep"
    static let displayName = "ScoreKeep Migration Test"

    let bundleIdentifier: String

    var isDisposableMigrationTestIdentity: Bool {
        bundleIdentifier == Self.disposableBundleIdentifier
    }

    var isProductionIdentity: Bool {
        bundleIdentifier == Self.productionBundleIdentifier
    }
}

enum ScoreKeepPhysicalMigrationTestMode: String, CaseIterable, Codable, Hashable, Sendable {
    case production
    case legacyStore
    case proposedV3Migration

    static var compiledMode: ScoreKeepPhysicalMigrationTestMode {
        #if SCOREKEEP_MIGRATION_TEST_PROPOSED
        return .proposedV3Migration
        #elseif SCOREKEEP_MIGRATION_TEST_LEGACY
        return .legacyStore
        #else
        return .production
        #endif
    }

    var displayTitle: String {
        switch self {
        case .production:
            return "Production"
        case .legacyStore:
            return "Legacy Store"
        case .proposedV3Migration:
            return "Proposed V3 Migration"
        }
    }

    var containerModeDescription: String {
        switch self {
        case .production:
            return "Production legacy SwiftData"
        case .legacyStore:
            return "Unversioned legacy SwiftData"
        case .proposedV3Migration:
            return "Prepared Proposed V3, disabled"
        }
    }
}

enum ScoreKeepPhysicalMigrationTestAuthorization: String, Codable, Hashable, Sendable {
    case notMigrationTestBuild
    case authorizedLegacyOnly
    case proposedMigrationDisabledPendingManualBaseline
    case invalidBundleModePairing

    var permitsProposedMigration: Bool { false }
}

struct ScoreKeepPhysicalMigrationTestSafety: Hashable, Sendable {
    let identity: ScoreKeepPhysicalMigrationTestIdentity
    let mode: ScoreKeepPhysicalMigrationTestMode
    let authorization: ScoreKeepPhysicalMigrationTestAuthorization
    let stableDiagnosticCodes: [String]

    static func evaluate(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "unknown",
        mode: ScoreKeepPhysicalMigrationTestMode = .compiledMode
    ) -> ScoreKeepPhysicalMigrationTestSafety {
        let identity = ScoreKeepPhysicalMigrationTestIdentity(bundleIdentifier: bundleIdentifier)
        if mode == .production {
            return ScoreKeepPhysicalMigrationTestSafety(
                identity: identity,
                mode: mode,
                authorization: .notMigrationTestBuild,
                stableDiagnosticCodes: ["migrationTest.productionMode"]
            )
        }
        guard identity.isDisposableMigrationTestIdentity else {
            return ScoreKeepPhysicalMigrationTestSafety(
                identity: identity,
                mode: mode,
                authorization: .invalidBundleModePairing,
                stableDiagnosticCodes: ["migrationTest.invalidBundleModePairing"]
            )
        }
        switch mode {
        case .legacyStore:
            return ScoreKeepPhysicalMigrationTestSafety(
                identity: identity,
                mode: mode,
                authorization: .authorizedLegacyOnly,
                stableDiagnosticCodes: ["migrationTest.legacyOnly", "migrationTest.proposedNotRun"]
            )
        case .proposedV3Migration:
            return ScoreKeepPhysicalMigrationTestSafety(
                identity: identity,
                mode: mode,
                authorization: .proposedMigrationDisabledPendingManualBaseline,
                stableDiagnosticCodes: ["migrationTest.proposedDisabled", "migrationTest.requiresManualBaseline"]
            )
        case .production:
            return ScoreKeepPhysicalMigrationTestSafety.evaluate(bundleIdentifier: bundleIdentifier, mode: .production)
        }
    }
}

enum ScoreKeepProtectedDataObservationState: String, Codable, Hashable, Sendable {
    case available
    case unavailable
    case becameAvailable
    case willBecomeUnavailable
    case unknownOrUnsupported
}

struct ScoreKeepPhysicalDeviceDiagnostics: Codable, Hashable, Sendable {
    let mode: ScoreKeepPhysicalMigrationTestMode
    let bundleIdentityClassification: String
    let containerMode: String
    let protectedDataState: ScoreKeepProtectedDataObservationState
    let storeRole: String
    let storeFileName: String
    let storeFamilyMembersPresent: [String]
    let fileProtectionClassifications: [String]
    let migrationJournalPresence: String
    let verifiedBackupPresence: String
    let migrationPhase: String
    let startupOwnership: String
    let disableState: String
    let proposedWriteReadiness: String
    let capacityDiagnostic: String
    let baselineStatus: String
    let stableDiagnosticCodes: [String]

    static func current(
        protectedDataState: ScoreKeepProtectedDataObservationState,
        baselineStatus: String,
        fileManager: FileManager = .default
    ) -> ScoreKeepPhysicalDeviceDiagnostics {
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate()
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: applicationSupportRoot(fileManager: fileManager))
        let storeMembers = storeFamilyMembers(for: layout.activeStore, fileManager: fileManager)
        let storeBytes = storeFamilyAllocatedBytes(for: layout.activeStore, fileManager: fileManager)
        let capacity = ScoreKeepMigrationCapacityCalculator.evaluate(
            input: ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: storeBytes),
            volume: ScoreKeepMigrationCapacityCalculator.queryVolume(at: layout.applicationSupportRoot)
        )
        return ScoreKeepPhysicalDeviceDiagnostics(
            mode: safety.mode,
            bundleIdentityClassification: safety.identity.isDisposableMigrationTestIdentity ? "disposableMigrationTest" : (safety.identity.isProductionIdentity ? "production" : "unexpected"),
            containerMode: safety.mode.containerModeDescription,
            protectedDataState: protectedDataState,
            storeRole: "activeLegacyStore",
            storeFileName: layout.activeStore.lastPathComponent,
            storeFamilyMembersPresent: storeMembers,
            fileProtectionClassifications: fileProtectionClassifications(for: layout.activeStore, fileManager: fileManager),
            migrationJournalPresence: fileManager.fileExists(atPath: layout.journal.path) ? "present" : "absent",
            verifiedBackupPresence: directoryHasContents(layout.backupsRoot, fileManager: fileManager) ? "present" : "absent",
            migrationPhase: "notStarted",
            startupOwnership: safety.mode == .legacyStore ? "legacySelected" : "none",
            disableState: safety.authorization.rawValue,
            proposedWriteReadiness: "prohibited",
            capacityDiagnostic: capacity.diagnosticCode,
            baselineStatus: baselineStatus,
            stableDiagnosticCodes: safety.stableDiagnosticCodes + [capacity.diagnosticCode]
        )
    }

    var copyableSummary: String {
        var lines: [String] = []
        lines.append("ScoreKeep Migration Test Summary")
        lines.append("Mode: \(mode.displayTitle)")
        lines.append("Bundle: \(bundleIdentityClassification)")
        lines.append("Container: \(containerMode)")
        lines.append("Protected Data: \(protectedDataState.rawValue)")
        lines.append("Store: \(storeRole) / \(storeFileName)")
        lines.append("Store Family: \(storeFamilyMembersPresent.joined(separator: ","))")
        lines.append("Protection: \(fileProtectionClassifications.joined(separator: ","))")
        lines.append("Journal: \(migrationJournalPresence)")
        lines.append("Backup: \(verifiedBackupPresence)")
        lines.append("Migration Phase: \(migrationPhase)")
        lines.append("Startup Ownership: \(startupOwnership)")
        lines.append("Disable State: \(disableState)")
        lines.append("Proposed Writes: \(proposedWriteReadiness)")
        lines.append("Capacity: \(capacityDiagnostic)")
        lines.append("Baseline: \(baselineStatus)")
        lines.append("Codes: \(stableDiagnosticCodes.joined(separator: ","))")
        return lines.joined(separator: "\n")
    }

    static func applicationSupportRoot(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    }

    static func baselineSidecarURL(fileManager: FileManager = .default) -> URL {
        baselineSidecarURL(fileManager: fileManager, applicationSupportRoot: nil)
    }

    static func baselineSidecarURL(fileManager: FileManager = .default, applicationSupportRoot: URL?) -> URL {
        (applicationSupportRoot ?? self.applicationSupportRoot(fileManager: fileManager))
            .appendingPathComponent("ScoreKeepMigrationTestDiagnostics-v1", isDirectory: true)
            .appendingPathComponent("ScoreKeepPhysicalMigrationBaseline-v1.json", isDirectory: false)
    }

    private static func storeFamilyMembers(for storeURL: URL, fileManager: FileManager) -> [String] {
        let directory = storeURL.deletingLastPathComponent()
        let candidates = [storeURL.lastPathComponent, storeURL.lastPathComponent + "-wal", storeURL.lastPathComponent + "-shm"]
        return candidates.filter { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) }
    }

    private static func storeFamilyAllocatedBytes(for storeURL: URL, fileManager: FileManager) -> UInt64 {
        let directory = storeURL.deletingLastPathComponent()
        return storeFamilyMembers(for: storeURL, fileManager: fileManager).reduce(UInt64(0)) { total, fileName in
            let url = directory.appendingPathComponent(fileName)
            let size = (try? url.resourceValues(forKeys: [.fileAllocatedSizeKey]).fileAllocatedSize).map(UInt64.init) ?? 0
            return total + size
        }
    }

    private static func fileProtectionClassifications(for storeURL: URL, fileManager: FileManager) -> [String] {
        let directory = storeURL.deletingLastPathComponent()
        let members = storeFamilyMembers(for: storeURL, fileManager: fileManager)
        guard members.isEmpty == false else { return ["storeFamilyAbsent"] }
        return members.map { fileName in
            let url = directory.appendingPathComponent(fileName)
            let protection = ScoreKeepMigrationFileProtectionApplicator.assessedCurrentProtection(url: url, fileManager: fileManager)?.rawValue ?? "unavailable"
            return "\(fileName):\(protection)"
        }
    }

    private static func directoryHasContents(_ url: URL, fileManager: FileManager) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else { return false }
        return contents.isEmpty == false
    }
}
