import CoreData
import Foundation

struct ScoreKeepSourceClosureEvidence: Hashable, Sendable {
    let sourceContainerReleased: Bool
    let sourceContextReleased: Bool
    let testAuthorityReleasedSourceAccess: Bool
    let noOtherKnownSourceAuthorityOpen: Bool

    var isClosed: Bool {
        sourceContainerReleased && sourceContextReleased && testAuthorityReleasedSourceAccess && noOtherKnownSourceAuthorityOpen
    }

    static let closedForDisposableVerification = ScoreKeepSourceClosureEvidence(
        sourceContainerReleased: true,
        sourceContextReleased: true,
        testAuthorityReleasedSourceAccess: true,
        noOtherKnownSourceAuthorityOpen: true
    )

    static let closedForProductionStartup = ScoreKeepSourceClosureEvidence(
        sourceContainerReleased: true,
        sourceContextReleased: true,
        testAuthorityReleasedSourceAccess: true,
        noOtherKnownSourceAuthorityOpen: true
    )
}

enum ScoreKeepSourcePreservationAuthorizationScope: String, Hashable, Sendable {
    case testOwnedDisposable
    case productionTransitionExplicitlyAuthorized
}

struct ScoreKeepSourcePreservationRequest {
    let sourceStoreURL: URL
    let backupStoreURL: URL
    let sourceLocation: ScoreKeepStartupStoreLocation.Kind
    let sourceClosureEvidence: ScoreKeepSourceClosureEvidence
    let allowIncompleteTestOwnedBackupRemoval: Bool
    let semanticRestoreVerifier: ((URL) throws -> Bool)?
    let makeSemanticRestoreCopyWritable: Bool
    let authorizationScope: ScoreKeepSourcePreservationAuthorizationScope
    let semanticDiagnosticContext: ScoreKeepSourcePreservationSemanticDiagnosticContext?
    let semanticDiagnosticSnapshotSink: ((String) -> Void)?
    let semanticBaselineMismatchDiagnosticLines: (() -> [String])?

    init(
        sourceStoreURL: URL,
        backupStoreURL: URL,
        sourceLocation: ScoreKeepStartupStoreLocation.Kind,
        sourceClosureEvidence: ScoreKeepSourceClosureEvidence,
        allowIncompleteTestOwnedBackupRemoval: Bool,
        semanticRestoreVerifier: ((URL) throws -> Bool)?,
        makeSemanticRestoreCopyWritable: Bool = false,
        authorizationScope: ScoreKeepSourcePreservationAuthorizationScope = .testOwnedDisposable,
        semanticDiagnosticContext: ScoreKeepSourcePreservationSemanticDiagnosticContext? = nil,
        semanticDiagnosticSnapshotSink: ((String) -> Void)? = nil,
        semanticBaselineMismatchDiagnosticLines: (() -> [String])? = nil
    ) {
        self.sourceStoreURL = sourceStoreURL
        self.backupStoreURL = backupStoreURL
        self.sourceLocation = sourceLocation
        self.sourceClosureEvidence = sourceClosureEvidence
        self.allowIncompleteTestOwnedBackupRemoval = allowIncompleteTestOwnedBackupRemoval
        self.semanticRestoreVerifier = semanticRestoreVerifier
        self.makeSemanticRestoreCopyWritable = makeSemanticRestoreCopyWritable
        self.authorizationScope = authorizationScope
        self.semanticDiagnosticContext = semanticDiagnosticContext
        self.semanticDiagnosticSnapshotSink = semanticDiagnosticSnapshotSink
        self.semanticBaselineMismatchDiagnosticLines = semanticBaselineMismatchDiagnosticLines
    }
}

struct ScoreKeepSourcePreservationSemanticDiagnosticContext: Equatable, Sendable {
    let sourceClassification: String
    let operationIdentity: String
    let configurationName: String
    let allowsSave: Bool
    let automaticMigrationOptionPresent: Bool
    let inferredMigrationOptionPresent: Bool
    let requestedModelVersion: String
    let requestedModelEntityHashes: [String]

    init(
        sourceClassification: String,
        operationIdentity: String,
        configurationName: String,
        allowsSave: Bool,
        automaticMigrationOptionPresent: Bool,
        inferredMigrationOptionPresent: Bool,
        requestedModelVersion: String,
        requestedModelEntityHashes: [String]
    ) {
        self.sourceClassification = sourceClassification
        self.operationIdentity = operationIdentity
        self.configurationName = configurationName
        self.allowsSave = allowsSave
        self.automaticMigrationOptionPresent = automaticMigrationOptionPresent
        self.inferredMigrationOptionPresent = inferredMigrationOptionPresent
        self.requestedModelVersion = requestedModelVersion
        self.requestedModelEntityHashes = requestedModelEntityHashes.sorted()
    }
}

struct ScoreKeepSourcePreservationEvidence: Hashable, Sendable {
    let sourceBefore: ScoreKeepStoreFamilyDescriptor
    let backupAfter: ScoreKeepStoreFamilyDescriptor
    let sourceAfter: ScoreKeepStoreFamilyDescriptor
    let backupIdentity: String
    let fileVerificationPassed: Bool
    let semanticVerificationPassed: Bool
    let disposition: ScoreKeepSourcePreservationDisposition
    let diagnosticCodes: [ScoreKeepMigrationJournalDiagnosticCode]
}

enum ScoreKeepSourcePreservationError: Error, Equatable {
    case productionPathRejected
    case sourceNotClosed
    case sourceUnavailable
    case destinationNotFresh
    case storeFamilyIncomplete
    case copyFailedBeforeCompletion
    case backupVerificationFailed(ScoreKeepSourcePreservationBackupVerificationFailure)
    case semanticVerificationFailed(ScoreKeepSourcePreservationSemanticVerificationFailure)
}

enum ScoreKeepSourcePreservationBackupVerificationFailure: String, Equatable, Sendable {
    case sourceDestinationIdentityCollision
    case sourceChanged
    case memberInventoryMismatch
    case primaryMismatch
    case walMismatch
    case shmMismatch
    case copiedIdentityMismatch
}

enum ScoreKeepSourcePreservationSemanticVerificationFailure: Equatable, Sendable {
    case semanticRestoreOpen(String)
    case semanticBaselineMismatch
}

struct ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError: Error, Equatable, Sendable {
    let diagnostic: String
}

struct ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport: Equatable, Sendable {
    let lines: [String]

    var boundedDiagnosticSection: String {
        lines.prefix(80).joined(separator: "\n")
    }
}

struct ScoreKeepSourcePreservationSemanticRestoreDiagnosticReportError: Error, Equatable, Sendable {
    let report: ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport
}

enum ScoreKeepSourcePreservationErrorIdentity {
    static func make(_ error: Error) -> String {
        guard let preservationError = error as? ScoreKeepSourcePreservationError else {
            return "backupVerificationFailed.unknown"
        }
        switch preservationError {
        case .productionPathRejected:
            return "backupVerificationFailed.productionPathRejected"
        case .sourceNotClosed:
            return "backupVerificationFailed.sourceNotClosed"
        case .sourceUnavailable:
            return "backupVerificationFailed.sourceUnavailable"
        case .destinationNotFresh:
            return "backupVerificationFailed.destinationNotFresh"
        case .storeFamilyIncomplete:
            return "backupVerificationFailed.storeFamilyIncomplete"
        case .copyFailedBeforeCompletion:
            return "backupVerificationFailed.copyFailedBeforeCompletion"
        case .backupVerificationFailed(let failure):
            return "backupVerificationFailed.\(failure.rawValue)"
        case .semanticVerificationFailed(let failure):
            switch failure {
            case .semanticRestoreOpen(let diagnostic):
                return "semanticRestoreOpen.\(sanitizedDiagnostic(diagnostic))"
            case .semanticBaselineMismatch:
                return "semanticRestoreOpen.semanticBaselineMismatch"
            }
        }
    }

    static func semanticRestoreOpenDiagnostic(for error: Error) -> String {
        if let report = error as? ScoreKeepSourcePreservationSemanticRestoreDiagnosticReportError {
            return report.report.boundedDiagnosticSection
        }
        if let diagnostic = error as? ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError {
            return diagnostic.diagnostic
        }
        let nsError = error as NSError
        return "unknown.\(sanitizedDiagnostic(nsError.domain)).\(nsError.code)"
    }

    private static func sanitizedDiagnostic(_ diagnostic: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._+-"))
        return String(diagnostic.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}

enum ScoreKeepSourcePreservationExecutor {
    static func preserve(_ request: ScoreKeepSourcePreservationRequest, fileManager: FileManager = .default) throws -> ScoreKeepSourcePreservationEvidence {
        guard request.sourceLocation != .productionIntendedApplicationStore || request.authorizationScope == .productionTransitionExplicitlyAuthorized else {
            throw ScoreKeepSourcePreservationError.productionPathRejected
        }
        guard request.sourceClosureEvidence.isClosed else {
            throw ScoreKeepSourcePreservationError.sourceNotClosed
        }
        guard fileManager.fileExists(atPath: request.sourceStoreURL.path) else {
            throw ScoreKeepSourcePreservationError.sourceUnavailable
        }
        let backupDirectory = request.backupStoreURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: backupDirectory.path) {
            let contents = (try? fileManager.contentsOfDirectory(atPath: backupDirectory.path)) ?? []
            guard contents.isEmpty else {
                throw ScoreKeepSourcePreservationError.destinationNotFresh
            }
        } else {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }

        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: request.sourceStoreURL, fileManager: fileManager)
        guard sourceBefore.isComplete else {
            throw ScoreKeepSourcePreservationError.storeFamilyIncomplete
        }

        do {
            for member in sourceBefore.members {
                let sourceMemberURL = request.sourceStoreURL.deletingLastPathComponent().appendingPathComponent(member.fileName)
                let backupMemberURL = backupDirectory.appendingPathComponent(member.fileName)
                try fileManager.copyItem(at: sourceMemberURL, to: backupMemberURL)
            }
        } catch {
            if request.allowIncompleteTestOwnedBackupRemoval {
                try? fileManager.removeItem(at: backupDirectory)
            }
            throw ScoreKeepSourcePreservationError.copyFailedBeforeCompletion
        }

        let backupAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: request.backupStoreURL, fileManager: fileManager)
        let sourceAfter = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: request.sourceStoreURL, fileManager: fileManager)
        if let verificationFailure = backupVerificationFailure(
            sourceBefore: sourceBefore,
            backupAfter: backupAfter,
            sourceAfter: sourceAfter,
            sourceURL: request.sourceStoreURL,
            backupURL: request.backupStoreURL
        ) {
            throw ScoreKeepSourcePreservationError.backupVerificationFailed(verificationFailure)
        }

        let semanticVerificationPassed: Bool
        if let semanticRestoreVerifier = request.semanticRestoreVerifier {
            let restoreURL = try freshRestoreURL(for: request.backupStoreURL, fileManager: fileManager)
            for member in backupAfter.members {
                let backupMemberURL = backupDirectory.appendingPathComponent(member.fileName)
                let restoreMemberURL = restoreURL.deletingLastPathComponent().appendingPathComponent(member.fileName)
                try fileManager.copyItem(at: backupMemberURL, to: restoreMemberURL)
            }
            if request.makeSemanticRestoreCopyWritable {
                do {
                    try makeRestoreCopyWritable(restoreURL: restoreURL, members: backupAfter.members, fileManager: fileManager)
                } catch {
                    guard request.semanticDiagnosticContext != nil else {
                        throw ScoreKeepSourcePreservationError.semanticVerificationFailed(
                            .semanticRestoreOpen("restoreCopyWritablePreparationFailed")
                        )
                    }
                    let failedPreparationDiagnostics = ScoreKeepSourcePreservationSemanticDiagnosticsCapture.capture(
                        context: request.semanticDiagnosticContext,
                        sourceURL: request.sourceStoreURL,
                        backupURL: request.backupStoreURL,
                        restoreURL: restoreURL,
                        phase: "restoreWritablePreparationFailed",
                        error: error,
                        beforeRestore: nil,
                        sourceBefore: sourceBefore,
                        backupAfter: backupAfter,
                        fileManager: fileManager
                    )
                    let diagnosticError = ScoreKeepSourcePreservationSemanticRestoreDiagnosticReportError(
                        report: ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport(lines: failedPreparationDiagnostics.lines)
                    )
                    request.semanticDiagnosticSnapshotSink?(diagnosticError.report.boundedDiagnosticSection)
                    throw ScoreKeepSourcePreservationError.semanticVerificationFailed(
                        .semanticRestoreOpen(ScoreKeepSourcePreservationErrorIdentity.semanticRestoreOpenDiagnostic(for: diagnosticError))
                    )
                }
            }
            let preOpenDiagnostics = ScoreKeepSourcePreservationSemanticDiagnosticsCapture.capture(
                context: request.semanticDiagnosticContext,
                sourceURL: request.sourceStoreURL,
                backupURL: request.backupStoreURL,
                restoreURL: restoreURL,
                phase: "beforeOpen",
                error: nil,
                beforeRestore: nil,
                sourceBefore: sourceBefore,
                backupAfter: backupAfter,
                fileManager: fileManager
            )
            if request.semanticDiagnosticContext != nil {
                request.semanticDiagnosticSnapshotSink?(
                    ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport(lines: preOpenDiagnostics.lines).boundedDiagnosticSection
                )
            }
            do {
                semanticVerificationPassed = try semanticRestoreVerifier(restoreURL)
                if request.semanticDiagnosticContext != nil {
                    let postOpenDiagnostics = ScoreKeepSourcePreservationSemanticDiagnosticsCapture.capture(
                        context: request.semanticDiagnosticContext,
                        sourceURL: request.sourceStoreURL,
                        backupURL: request.backupStoreURL,
                        restoreURL: restoreURL,
                        phase: semanticVerificationPassed ? "afterOpenSuccess" : "afterOpenBaselineMismatch",
                        error: semanticVerificationPassed ? nil : ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError(diagnostic: "semanticBaselineMismatch"),
                        beforeRestore: preOpenDiagnostics.restoreFamily,
                        sourceBefore: sourceBefore,
                        backupAfter: backupAfter,
                        additionalLines: semanticVerificationPassed ? [] : request.semanticBaselineMismatchDiagnosticLines?() ?? [],
                        fileManager: fileManager
                    )
                    request.semanticDiagnosticSnapshotSink?(
                        ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport(
                            lines: preOpenDiagnostics.lines + postOpenDiagnostics.lines
                        ).boundedDiagnosticSection
                    )
                }
            } catch {
                guard request.semanticDiagnosticContext != nil else {
                    throw ScoreKeepSourcePreservationError.semanticVerificationFailed(
                        .semanticRestoreOpen(ScoreKeepSourcePreservationErrorIdentity.semanticRestoreOpenDiagnostic(for: error))
                    )
                }
                let postOpenDiagnostics = ScoreKeepSourcePreservationSemanticDiagnosticsCapture.capture(
                    context: request.semanticDiagnosticContext,
                    sourceURL: request.sourceStoreURL,
                    backupURL: request.backupStoreURL,
                    restoreURL: restoreURL,
                    phase: "afterOpenFailure",
                    error: error,
                    beforeRestore: preOpenDiagnostics.restoreFamily,
                    sourceBefore: sourceBefore,
                    backupAfter: backupAfter,
                    fileManager: fileManager
                )
                let diagnosticError = ScoreKeepSourcePreservationSemanticRestoreDiagnosticReportError(
                    report: ScoreKeepSourcePreservationSemanticRestoreDiagnosticReport(
                        lines: preOpenDiagnostics.lines + postOpenDiagnostics.lines
                    )
                )
                request.semanticDiagnosticSnapshotSink?(diagnosticError.report.boundedDiagnosticSection)
                throw ScoreKeepSourcePreservationError.semanticVerificationFailed(
                    .semanticRestoreOpen(ScoreKeepSourcePreservationErrorIdentity.semanticRestoreOpenDiagnostic(for: diagnosticError))
                )
            }
        } else {
            semanticVerificationPassed = true
        }

        guard semanticVerificationPassed else {
            throw ScoreKeepSourcePreservationError.semanticVerificationFailed(.semanticBaselineMismatch)
        }

        return ScoreKeepSourcePreservationEvidence(
            sourceBefore: sourceBefore,
            backupAfter: backupAfter,
            sourceAfter: sourceAfter,
            backupIdentity: backupAfter.diagnosticIdentity,
            fileVerificationPassed: true,
            semanticVerificationPassed: true,
            disposition: .backupVerified,
            diagnosticCodes: []
        )
    }

    private static func makeRestoreCopyWritable(
        restoreURL: URL,
        members: [ScoreKeepStoreFamilyMember],
        fileManager: FileManager
    ) throws {
        let restoreDirectory = restoreURL.deletingLastPathComponent()
        try applyMinimumPermissions(0o700, to: restoreDirectory, fileManager: fileManager)
        for member in members {
            let memberURL = restoreDirectory.appendingPathComponent(member.fileName, isDirectory: false)
            try applyMinimumPermissions(0o600, to: memberURL, fileManager: fileManager)
        }
    }

    private static func applyMinimumPermissions(
        _ minimumPermissions: Int,
        to url: URL,
        fileManager: FileManager
    ) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let currentPermissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        let updatedPermissions = currentPermissions | minimumPermissions
        if updatedPermissions != currentPermissions {
            try fileManager.setAttributes([.posixPermissions: updatedPermissions], ofItemAtPath: url.path)
        }
        guard fileManager.isWritableFile(atPath: url.path) else {
            throw NSError(domain: "com.scorekeep.restore-writable-preparation", code: 1)
        }
    }

    private static func freshRestoreURL(for backupStoreURL: URL, fileManager: FileManager) throws -> URL {
        let restoreDirectory = backupStoreURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        return restoreDirectory.appendingPathComponent(backupStoreURL.lastPathComponent)
    }

    private static func backupVerificationFailure(
        sourceBefore: ScoreKeepStoreFamilyDescriptor,
        backupAfter: ScoreKeepStoreFamilyDescriptor,
        sourceAfter: ScoreKeepStoreFamilyDescriptor,
        sourceURL: URL,
        backupURL: URL
    ) -> ScoreKeepSourcePreservationBackupVerificationFailure? {
        guard sourceURL.deletingLastPathComponent().standardizedFileURL != backupURL.deletingLastPathComponent().standardizedFileURL else {
            return .sourceDestinationIdentityCollision
        }
        guard sourceBefore == sourceAfter else {
            return .sourceChanged
        }
        guard sourceBefore.storeFileName == backupAfter.storeFileName,
              sourceBefore.fileNames == backupAfter.fileNames else {
            return .memberInventoryMismatch
        }
        for sourceMember in sourceBefore.members {
            guard let backupMember = backupAfter.member(named: sourceMember.fileName) else {
                return .memberInventoryMismatch
            }
            guard backupMember.byteCount == sourceMember.byteCount,
                  backupMember.fingerprint == sourceMember.fingerprint else {
                switch sourceMember.role {
                case .primary:
                    return .primaryMismatch
                case .wal:
                    return .walMismatch
                case .shm:
                    return .shmMismatch
                case .unexpectedRelated:
                    return .memberInventoryMismatch
                }
            }
        }
        guard sourceBefore.diagnosticIdentity == backupAfter.diagnosticIdentity else {
            return .copiedIdentityMismatch
        }
        return nil
    }
}

private struct ScoreKeepSourcePreservationSemanticDiagnosticsSnapshot {
    let lines: [String]
    let restoreFamily: ScoreKeepStoreFamilyDescriptor?
}

private enum ScoreKeepSourcePreservationSemanticDiagnosticsCapture {
    static func capture(
        context: ScoreKeepSourcePreservationSemanticDiagnosticContext?,
        sourceURL: URL,
        backupURL: URL,
        restoreURL: URL,
        phase: String,
        error: Error?,
        beforeRestore: ScoreKeepStoreFamilyDescriptor?,
        sourceBefore: ScoreKeepStoreFamilyDescriptor,
        backupAfter: ScoreKeepStoreFamilyDescriptor,
        additionalLines: [String] = [],
        fileManager: FileManager
    ) -> ScoreKeepSourcePreservationSemanticDiagnosticsSnapshot {
        let restoreFamily = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: restoreURL, fileManager: fileManager)
        let sourceAfter = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL, fileManager: fileManager)
        let backupCurrent = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL, fileManager: fileManager)
        var lines: [String] = []

        lines.append("V1 Backup Semantic Verification Diagnostics")
        lines.append("phase=\(phase)")
        if let context {
            lines.append("sourceClassification=\(context.sourceClassification)")
            lines.append("operationIdentity=\(context.operationIdentity)")
            lines.append("configurationName=\(context.configurationName)")
            lines.append("allowsSave=\(context.allowsSave)")
            lines.append("automaticMigrationOptionPresent=\(context.automaticMigrationOptionPresent)")
            lines.append("inferredMigrationOptionPresent=\(context.inferredMigrationOptionPresent)")
            lines.append("requestedModelVersion=\(context.requestedModelVersion)")
            lines.append("requestedModelEntityHashes=\(context.requestedModelEntityHashes.joined(separator: ","))")
        } else {
            lines.append("diagnosticContext=unavailable")
        }
        if let error {
            lines.append("underlyingError=\(sanitizedError(error))")
        }
        lines.append(contentsOf: additionalLines.map { sanitize($0) })
        lines.append("restoreDirectory=\(directorySummary(restoreURL.deletingLastPathComponent(), fileManager: fileManager))")
        lines.append("sourceFingerprintBefore=\(sourceBefore.diagnosticIdentity)")
        lines.append("verifiedBackupFingerprintBefore=\(backupAfter.diagnosticIdentity)")
        lines.append("sourceFingerprintAfter=\(sourceAfter?.diagnosticIdentity ?? "unavailable")")
        lines.append("verifiedBackupFingerprintAfter=\(backupCurrent?.diagnosticIdentity ?? "unavailable")")
        lines.append("sourceUnchanged=\(sourceAfter == sourceBefore)")
        lines.append("verifiedBackupUnchanged=\(backupCurrent == backupAfter)")
        lines.append("restoreFingerprint=\(restoreFamily?.diagnosticIdentity ?? "unavailable")")
        lines.append("restoreFamilyChanged=\(restoreChangeSummary(beforeRestore, restoreFamily))")
        lines.append(contentsOf: familyLines(label: "source", url: sourceURL, descriptor: sourceAfter ?? sourceBefore, fileManager: fileManager))
        lines.append(contentsOf: familyLines(label: "verifiedBackup", url: backupURL, descriptor: backupCurrent ?? backupAfter, fileManager: fileManager))
        if let restoreFamily {
            lines.append(contentsOf: familyLines(label: "restoreCopy", url: restoreURL, descriptor: restoreFamily, fileManager: fileManager))
        } else {
            lines.append("restoreCopy.family=unavailable")
            lines.append(contentsOf: candidateMemberLines(label: "restoreCopy", storeURL: restoreURL, fileManager: fileManager))
        }
        lines.append(contentsOf: persistentStoreMetadataLines(storeURL: restoreURL))
        return ScoreKeepSourcePreservationSemanticDiagnosticsSnapshot(lines: lines, restoreFamily: restoreFamily)
    }

    private static func familyLines(
        label: String,
        url: URL,
        descriptor: ScoreKeepStoreFamilyDescriptor,
        fileManager: FileManager
    ) -> [String] {
        var lines = [
            "\(label).directoryIdentity=\(descriptor.sourceDirectoryIdentity)",
            "\(label).storeFileName=\(descriptor.storeFileName)",
            "\(label).members=\(descriptor.fileNames.joined(separator: ","))",
            "\(label).missingOptionalSidecars=\(descriptor.missingOptionalSidecars.joined(separator: ","))",
            "\(label).unexpectedRelatedFiles=\(descriptor.unexpectedRelatedFiles.joined(separator: ","))"
        ]
        let directory = url.deletingLastPathComponent()
        for member in descriptor.members {
            let memberURL = directory.appendingPathComponent(member.fileName, isDirectory: false)
            lines.append("\(label).\(member.role.rawValue)=\(memberSummary(member, url: memberURL, fileManager: fileManager))")
        }
        return lines
    }

    private static func candidateMemberLines(label: String, storeURL: URL, fileManager: FileManager) -> [String] {
        let directory = storeURL.deletingLastPathComponent()
        let names = [storeURL.lastPathComponent, storeURL.lastPathComponent + "-wal", storeURL.lastPathComponent + "-shm"]
        return names.map { name in
            let url = directory.appendingPathComponent(name, isDirectory: false)
            return "\(label).candidate.\(name)=\(fileSummary(url, fileManager: fileManager))"
        }
    }

    private static func memberSummary(
        _ member: ScoreKeepStoreFamilyMember,
        url: URL,
        fileManager: FileManager
    ) -> String {
        [
            "file=\(member.fileName)",
            "exists=\(fileManager.fileExists(atPath: url.path))",
            "bytes=\(member.byteCount)",
            "fingerprint=\(member.fingerprint)",
            fileSummary(url, fileManager: fileManager)
        ].joined(separator: ";")
    }

    private static func fileSummary(_ url: URL, fileManager: FileManager) -> String {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return "attributes=unavailable;writable=\(fileManager.isWritableFile(atPath: url.path))"
        }
        let permissions = (attributes[.posixPermissions] as? NSNumber).map { String(format: "%o", $0.intValue) } ?? "unavailable"
        let owner = (attributes[.ownerAccountID] as? NSNumber)?.stringValue ?? "unavailable"
        let group = (attributes[.groupOwnerAccountID] as? NSNumber)?.stringValue ?? "unavailable"
        let size = (attributes[.size] as? NSNumber).map { String($0.uint64Value) } ?? "unavailable"
        let modification = (attributes[.modificationDate] as? Date).map { String(Int($0.timeIntervalSince1970)) } ?? "unavailable"
        return "size=\(size);permissions=\(permissions);owner=\(owner);group=\(group);writable=\(fileManager.isWritableFile(atPath: url.path));modified=\(modification)"
    }

    private static func directorySummary(_ url: URL, fileManager: FileManager) -> String {
        let identity = ScoreKeepStoreFamilyDiscovery.digest(Data(url.lastPathComponent.utf8))
        return "identity=\(identity);\(fileSummary(url, fileManager: fileManager))"
    }

    private static func persistentStoreMetadataLines(storeURL: URL) -> [String] {
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            var lines = ["persistentStoreMetadata.keys=\(metadata.keys.map(String.init(describing:)).sorted().joined(separator: ","))"]
            if let identifiers = metadata[NSStoreModelVersionIdentifiersKey] {
                lines.append("persistentStoreMetadata.modelVersionIdentifiers=\(sanitize(String(describing: identifiers)))")
            } else {
                lines.append("persistentStoreMetadata.modelVersionIdentifiers=absent")
            }
            if let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data] {
                let values = hashes.keys.sorted().map { key in "\(key):\(hashes[key]?.map { String(format: "%02x", $0) }.joined() ?? "unavailable")" }
                lines.append("persistentStoreMetadata.entityVersionHashes=\(values.joined(separator: ","))")
            } else {
                lines.append("persistentStoreMetadata.entityVersionHashes=absent")
            }
            return lines
        } catch {
            return ["persistentStoreMetadata.error=\(sanitizedError(error))"]
        }
    }

    private static func restoreChangeSummary(_ before: ScoreKeepStoreFamilyDescriptor?, _ after: ScoreKeepStoreFamilyDescriptor?) -> String {
        guard let before else { return "notCompared" }
        guard let after else { return "removedOrUnavailable" }
        var changes: [String] = []
        let beforeMembers = Dictionary(uniqueKeysWithValues: before.members.map { ($0.fileName, $0) })
        let afterMembers = Dictionary(uniqueKeysWithValues: after.members.map { ($0.fileName, $0) })
        for name in Set(beforeMembers.keys).union(afterMembers.keys).sorted() {
            switch (beforeMembers[name], afterMembers[name]) {
            case (nil, .some):
                changes.append("\(name):created")
            case (.some, nil):
                changes.append("\(name):removed")
            case (.some(let lhs), .some(let rhs)) where lhs.byteCount != rhs.byteCount:
                changes.append("\(name):resized")
            case (.some(let lhs), .some(let rhs)) where lhs.fingerprint != rhs.fingerprint:
                changes.append("\(name):modified")
            default:
                break
            }
        }
        return changes.isEmpty ? "unchanged" : changes.joined(separator: ",")
    }

    private static func sanitizedError(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [
            "domain=\(sanitize(nsError.domain))",
            "code=\(nsError.code)"
        ]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlyingDomain=\(sanitize(underlying.domain))")
            parts.append("underlyingCode=\(underlying.code)")
        }
        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            parts.append("reason=\(sanitize(reason))")
        }
        if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
            parts.append("description=\(sanitize(description))")
        }
        return parts.joined(separator: ";")
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._+-,=:;[]() "))
        let sanitized = String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        return String(sanitized.prefix(240))
    }
}

enum ScoreKeepFileCoordinationAssessment: String, CaseIterable, Hashable, Sendable {
    case notUsedForClosedDisposableStoreFamily
    case futureProductionAssessmentRequired

    static let current: ScoreKeepFileCoordinationAssessment = .notUsedForClosedDisposableStoreFamily
}
