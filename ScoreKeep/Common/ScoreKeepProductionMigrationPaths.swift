import Foundation

struct ScoreKeepProductionMigrationLayout: Hashable, Sendable {
    let applicationSupportRoot: URL
    let activeStore: URL
    let migrationControlRoot: URL
    let journal: URL
    let backupsRoot: URL
    let temporaryTargetsRoot: URL
    let incompleteTargetsRoot: URL
    let recoveryCopiesRoot: URL
    let diagnosticsState: URL
    let manualReviewRoot: URL
    let cleanupStagingRoot: URL

    static let activeStoreFileName = "default.store"
    static let migrationDirectoryName = "ScoreKeepMigrationControl-v1"
    static let journalDirectoryName = "Journal-v1"
    static let backupDirectoryName = "VerifiedBackups-v1"
    static let temporaryTargetDirectoryName = "TemporaryTargets-v1"
    static let incompleteTargetDirectoryName = "IncompleteTargets-v1"
    static let recoveryDirectoryName = "RecoveryCopies-v1"
    static let diagnosticDirectoryName = "Diagnostics-v1"
    static let manualReviewDirectoryName = "ManualReview-v1"
    static let cleanupStagingDirectoryName = "CleanupStaging-v1"

    static func resolve(applicationSupportRoot: URL) -> ScoreKeepProductionMigrationLayout {
        let root = applicationSupportRoot.standardizedFileURL
        let control = root.appendingPathComponent(migrationDirectoryName, isDirectory: true)
        return ScoreKeepProductionMigrationLayout(
            applicationSupportRoot: root,
            activeStore: root.appendingPathComponent(activeStoreFileName, isDirectory: false),
            migrationControlRoot: control,
            journal: control.appendingPathComponent(journalDirectoryName, isDirectory: true).appendingPathComponent("ScoreKeepMigrationJournal.json", isDirectory: false),
            backupsRoot: control.appendingPathComponent(backupDirectoryName, isDirectory: true),
            temporaryTargetsRoot: control.appendingPathComponent(temporaryTargetDirectoryName, isDirectory: true),
            incompleteTargetsRoot: control.appendingPathComponent(incompleteTargetDirectoryName, isDirectory: true),
            recoveryCopiesRoot: control.appendingPathComponent(recoveryDirectoryName, isDirectory: true),
            diagnosticsState: control.appendingPathComponent(diagnosticDirectoryName, isDirectory: true).appendingPathComponent("StartupDiagnostics.json", isDirectory: false),
            manualReviewRoot: control.appendingPathComponent(manualReviewDirectoryName, isDirectory: true),
            cleanupStagingRoot: control.appendingPathComponent(cleanupStagingDirectoryName, isDirectory: true)
        )
    }

    func operationBackupStoreURL(operationIdentity: ScoreKeepMigrationOperationIdentity, storeFileName: String = activeStoreFileName) -> URL {
        backupsRoot.appendingPathComponent(operationDirectoryName(for: operationIdentity), isDirectory: true).appendingPathComponent("StoreFamily", isDirectory: true).appendingPathComponent(storeFileName, isDirectory: false)
    }

    func operationTemporaryTargetURL(operationIdentity: ScoreKeepMigrationOperationIdentity, storeFileName: String = activeStoreFileName) -> URL {
        temporaryTargetsRoot.appendingPathComponent(operationDirectoryName(for: operationIdentity), isDirectory: true).appendingPathComponent(storeFileName, isDirectory: false)
    }

    func operationTemporaryTargetStoreFamilyURL(
        operationIdentity: ScoreKeepMigrationOperationIdentity,
        familyDirectoryName: String,
        storeFileName: String = activeStoreFileName
    ) -> URL {
        temporaryTargetsRoot
            .appendingPathComponent(operationDirectoryName(for: operationIdentity), isDirectory: true)
            .appendingPathComponent(familyDirectoryName, isDirectory: true)
            .appendingPathComponent(storeFileName, isDirectory: false)
    }

    func operationIncompleteTargetURL(operationIdentity: ScoreKeepMigrationOperationIdentity, storeFileName: String = activeStoreFileName) -> URL {
        incompleteTargetsRoot.appendingPathComponent(operationDirectoryName(for: operationIdentity), isDirectory: true).appendingPathComponent(storeFileName, isDirectory: false)
    }

    func operationRecoveryCopyURL(operationIdentity: ScoreKeepMigrationOperationIdentity, storeFileName: String = activeStoreFileName) -> URL {
        recoveryCopiesRoot.appendingPathComponent(operationDirectoryName(for: operationIdentity), isDirectory: true).appendingPathComponent(storeFileName, isDirectory: false)
    }

    private func operationDirectoryName(for operationIdentity: ScoreKeepMigrationOperationIdentity) -> String {
        "operation-generation-\(operationIdentity.applicationMigrationGeneration)-\(operationIdentity.operationUUID.uuidString.lowercased())"
    }
}

enum ScoreKeepProductionPathRole: String, CaseIterable, Hashable, Sendable {
    case applicationSupportRoot
    case activeStore
    case migrationControlRoot
    case migrationJournal
    case verifiedBackup
    case temporaryTarget
    case incompleteTarget
    case recoveryCopy
    case diagnosticState
    case manualReview
    case cleanupStaging
    case unsupportedLocation
    case testOwnedProductionLayoutSimulation
}

struct ScoreKeepProductionPathDescriptor: Hashable, Sendable {
    let role: ScoreKeepProductionPathRole
    let url: URL
    let redactedDiagnosticValue: String

    init(role: ScoreKeepProductionPathRole, url: URL) {
        self.role = role
        self.url = url.standardizedFileURL
        self.redactedDiagnosticValue = "path.\(role.rawValue)"
    }
}

enum ScoreKeepProductionPathValidationDisposition: String, CaseIterable, Hashable, Sendable {
    case valid
    case pathTraversalOutsideRoot
    case symbolicLinkEscape
    case sourceEqualsDestination
    case backupNestedInsideSourceFamily
    case temporaryTargetEqualsActiveStore
    case journalInsideDisposableTarget
    case cleanupCandidateOutsideMigrationRoot
    case productionPathRejectedForTestCleanup
    case nonOverlappingPathRequirementFailed
}

struct ScoreKeepProductionPathValidationResult: Hashable, Sendable {
    let disposition: ScoreKeepProductionPathValidationDisposition
    let diagnosticCode: String

    var isValid: Bool { disposition == .valid }
}

enum ScoreKeepDirectoryCreationIntent: String, CaseIterable, Hashable, Sendable {
    case readOnlyAssessment
    case authorizedPreflightControlRoot
    case journalParentBeforeIntent
    case backupOperationAfterIdentityKnown
    case temporaryTargetAfterBackupVerification
    case recoveryAfterRecoveryClassification
    case cleanupStagingAfterExplicitAuthorization
}

enum ScoreKeepDirectoryCreationDisposition: String, CaseIterable, Hashable, Sendable {
    case noCreationForReadOnlyAssessment
    case mayCreateEmptyDirectory
    case existingEmptyDirectoryAccepted
    case existingUnexpectedFileBlocksUse
    case existingNonEmptyDirectoryRequiresReconciliation
    case missingParentBlocksUse
}

enum ScoreKeepProductionStoreDiscoveryClassification: String, CaseIterable, Hashable, Sendable {
    case frameworkDefaultPathInferredFromDisposableEquivalence
    case discoverableSafelyWithoutOpeningStore
    case requiresActivationRunInspection
    case notSufficientlyProven
}

struct ScoreKeepProductionPathDryAssessment: Hashable, Sendable {
    let descriptors: [ScoreKeepProductionPathDescriptor]
    let validation: ScoreKeepProductionPathValidationResult
    let storeDiscovery: ScoreKeepProductionStoreDiscoveryClassification
    let createsDirectories: Bool
    let opensProductionStore: Bool
    let enumeratesProductionFiles: Bool

    static func assess(applicationSupportRoot: URL) -> ScoreKeepProductionPathDryAssessment {
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: applicationSupportRoot)
        let descriptors = [
            ScoreKeepProductionPathDescriptor(role: .applicationSupportRoot, url: layout.applicationSupportRoot),
            ScoreKeepProductionPathDescriptor(role: .activeStore, url: layout.activeStore),
            ScoreKeepProductionPathDescriptor(role: .migrationControlRoot, url: layout.migrationControlRoot),
            ScoreKeepProductionPathDescriptor(role: .migrationJournal, url: layout.journal),
            ScoreKeepProductionPathDescriptor(role: .verifiedBackup, url: layout.backupsRoot),
            ScoreKeepProductionPathDescriptor(role: .temporaryTarget, url: layout.temporaryTargetsRoot),
            ScoreKeepProductionPathDescriptor(role: .incompleteTarget, url: layout.incompleteTargetsRoot),
            ScoreKeepProductionPathDescriptor(role: .recoveryCopy, url: layout.recoveryCopiesRoot),
            ScoreKeepProductionPathDescriptor(role: .diagnosticState, url: layout.diagnosticsState),
            ScoreKeepProductionPathDescriptor(role: .manualReview, url: layout.manualReviewRoot),
            ScoreKeepProductionPathDescriptor(role: .cleanupStaging, url: layout.cleanupStagingRoot)
        ]
        return ScoreKeepProductionPathDryAssessment(
            descriptors: descriptors,
            validation: ScoreKeepProductionPathValidator.validate(layout: layout),
            storeDiscovery: .frameworkDefaultPathInferredFromDisposableEquivalence,
            createsDirectories: false,
            opensProductionStore: false,
            enumeratesProductionFiles: false
        )
    }
}

enum ScoreKeepProductionPathValidator {
    static func validate(layout: ScoreKeepProductionMigrationLayout, fileManager: FileManager = .default) -> ScoreKeepProductionPathValidationResult {
        let root = resolved(layout.applicationSupportRoot, fileManager: fileManager)
        let active = resolved(layout.activeStore, fileManager: fileManager)
        let control = resolved(layout.migrationControlRoot, fileManager: fileManager)
        let journal = resolved(layout.journal, fileManager: fileManager)
        let backup = resolved(layout.backupsRoot, fileManager: fileManager)
        let temporary = resolved(layout.temporaryTargetsRoot, fileManager: fileManager)
        let recovery = resolved(layout.recoveryCopiesRoot, fileManager: fileManager)
        let diagnostics = resolved(layout.diagnosticsState, fileManager: fileManager)

        guard contains(root, active) && contains(root, control) && contains(root, journal) && contains(root, backup) && contains(root, temporary) && contains(root, recovery) && contains(root, diagnostics) else {
            return result(.pathTraversalOutsideRoot)
        }
        guard active != backup && active.deletingLastPathComponent() != backup else { return result(.sourceEqualsDestination) }
        guard contains(control, journal) && contains(control, backup) && contains(control, temporary) && contains(control, recovery) && contains(control, diagnostics) else {
            return result(.nonOverlappingPathRequirementFailed)
        }
        guard backup.standardizedFileURL.path.hasPrefix(active.standardizedFileURL.path + "/") == false else { return result(.backupNestedInsideSourceFamily) }
        guard temporary != active && temporary != active.deletingLastPathComponent() else { return result(.temporaryTargetEqualsActiveStore) }
        guard contains(temporary, journal) == false else { return result(.journalInsideDisposableTarget) }
        return result(.valid)
    }

    static func validateCleanupCandidate(_ candidate: URL, layout: ScoreKeepProductionMigrationLayout, testOwnedRoot: URL?, fileManager: FileManager = .default) -> ScoreKeepProductionPathValidationResult {
        let resolvedCandidate = resolved(candidate, fileManager: fileManager)
        let control = resolved(layout.migrationControlRoot, fileManager: fileManager)
        guard contains(control, resolvedCandidate) else { return result(.cleanupCandidateOutsideMigrationRoot) }
        guard let testOwnedRoot, contains(resolved(testOwnedRoot, fileManager: fileManager), resolvedCandidate) else {
            return result(.productionPathRejectedForTestCleanup)
        }
        return result(.valid)
    }

    static func contains(_ parent: URL, _ child: URL) -> Bool {
        let parentComponents = parent.standardizedFileURL.pathComponents
        let childComponents = child.standardizedFileURL.pathComponents
        guard childComponents.count >= parentComponents.count else { return false }
        return Array(childComponents.prefix(parentComponents.count)) == parentComponents
    }

    private static func resolved(_ url: URL, fileManager: FileManager) -> URL {
        let standardized = url.standardizedFileURL
        if fileManager.fileExists(atPath: standardized.path) {
            return standardized.resolvingSymlinksInPath()
        }
        return standardized
    }

    private static func result(_ disposition: ScoreKeepProductionPathValidationDisposition) -> ScoreKeepProductionPathValidationResult {
        ScoreKeepProductionPathValidationResult(disposition: disposition, diagnosticCode: "paths.\(disposition.rawValue)")
    }
}

enum ScoreKeepDirectoryCreationPolicy {
    static func assess(url: URL, intent: ScoreKeepDirectoryCreationIntent, fileManager: FileManager = .default) -> ScoreKeepDirectoryCreationDisposition {
        if intent == .readOnlyAssessment { return .noCreationForReadOnlyAssessment }
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { return .existingUnexpectedFileBlocksUse }
            let contents = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
            return contents.isEmpty ? .existingEmptyDirectoryAccepted : .existingNonEmptyDirectoryRequiresReconciliation
        }
        let parent = url.deletingLastPathComponent()
        var parentIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory), parentIsDirectory.boolValue else {
            return .missingParentBlocksUse
        }
        return .mayCreateEmptyDirectory
    }
}
