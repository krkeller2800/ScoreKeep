import Foundation

struct ScoreKeepDebugFreshMigrationAttemptResult: Hashable, Sendable {
    let archiveURL: URL
    let sourceFamilyIdentity: String

    var userMessage: String {
        "Fresh migration attempt prepared. Close and relaunch ScoreKeep."
    }
}

enum ScoreKeepDebugFreshMigrationAttemptError: Error, Equatable {
    case unavailableOutsideDebug
    case activeSourceMissing
    case activeSourceIncomplete
    case migrationControlDirectoryMissing
    case archiveDestinationExists
    case archiveRenameFailed
    case activeSourceChanged
}

enum ScoreKeepDebugFreshMigrationAttempt {
    static func prepare(
        layout: ScoreKeepProductionMigrationLayout,
        fileManager: FileManager = .default,
        debugBuildEnabled: Bool = isDebugBuild,
        archiveNameProvider: () -> String = defaultArchiveName
    ) throws -> ScoreKeepDebugFreshMigrationAttemptResult {
        guard debugBuildEnabled else { throw ScoreKeepDebugFreshMigrationAttemptError.unavailableOutsideDebug }

        let sourceBefore: ScoreKeepStoreFamilyDescriptor
        do {
            sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore, fileManager: fileManager)
        } catch ScoreKeepStoreFamilyError.primaryStoreMissing {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceMissing
        } catch ScoreKeepStoreFamilyError.sourceDirectoryUnavailable {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceMissing
        } catch {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceIncomplete
        }
        guard sourceBefore.missingPrimary == false else {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceMissing
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: layout.migrationControlRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ScoreKeepDebugFreshMigrationAttemptError.migrationControlDirectoryMissing
        }

        let archiveURL = layout.migrationControlRoot
            .deletingLastPathComponent()
            .appendingPathComponent(archiveNameProvider(), isDirectory: true)
        guard fileManager.fileExists(atPath: archiveURL.path) == false else {
            throw ScoreKeepDebugFreshMigrationAttemptError.archiveDestinationExists
        }

        do {
            try fileManager.moveItem(at: layout.migrationControlRoot, to: archiveURL)
        } catch {
            throw ScoreKeepDebugFreshMigrationAttemptError.archiveRenameFailed
        }

        let sourceAfter: ScoreKeepStoreFamilyDescriptor
        do {
            sourceAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore, fileManager: fileManager)
        } catch {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceChanged
        }
        guard sourceAfter == sourceBefore else {
            throw ScoreKeepDebugFreshMigrationAttemptError.activeSourceChanged
        }

        return ScoreKeepDebugFreshMigrationAttemptResult(
            archiveURL: archiveURL,
            sourceFamilyIdentity: sourceBefore.diagnosticIdentity
        )
    }

    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func defaultArchiveName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(ScoreKeepProductionMigrationLayout.migrationDirectoryName)-preserved-\(formatter.string(from: Date()))-\(UUID().uuidString.lowercased())"
    }
}
