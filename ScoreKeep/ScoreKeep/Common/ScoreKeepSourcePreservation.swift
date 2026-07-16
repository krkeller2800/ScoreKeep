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
}

struct ScoreKeepSourcePreservationRequest {
    let sourceStoreURL: URL
    let backupStoreURL: URL
    let sourceLocation: ScoreKeepStartupStoreLocation.Kind
    let sourceClosureEvidence: ScoreKeepSourceClosureEvidence
    let allowIncompleteTestOwnedBackupRemoval: Bool
    let semanticRestoreVerifier: ((URL) throws -> Bool)?
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
    case backupVerificationFailed
    case semanticVerificationFailed
}

enum ScoreKeepSourcePreservationExecutor {
    static func preserve(_ request: ScoreKeepSourcePreservationRequest, fileManager: FileManager = .default) throws -> ScoreKeepSourcePreservationEvidence {
        guard request.sourceLocation != .productionIntendedApplicationStore else {
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
        let fileVerificationPassed = try ScoreKeepStoreFamilyDiscovery.validateBackup(
            source: sourceBefore,
            backup: backupAfter,
            sourceURL: request.sourceStoreURL,
            backupURL: request.backupStoreURL
        ) && sourceBefore == sourceAfter

        guard fileVerificationPassed else {
            throw ScoreKeepSourcePreservationError.backupVerificationFailed
        }

        let semanticVerificationPassed: Bool
        if let semanticRestoreVerifier = request.semanticRestoreVerifier {
            let restoreURL = try freshRestoreURL(for: request.backupStoreURL, fileManager: fileManager)
            for member in backupAfter.members {
                let backupMemberURL = backupDirectory.appendingPathComponent(member.fileName)
                let restoreMemberURL = restoreURL.deletingLastPathComponent().appendingPathComponent(member.fileName)
                try fileManager.copyItem(at: backupMemberURL, to: restoreMemberURL)
            }
            semanticVerificationPassed = try semanticRestoreVerifier(restoreURL)
        } else {
            semanticVerificationPassed = true
        }

        guard semanticVerificationPassed else {
            throw ScoreKeepSourcePreservationError.semanticVerificationFailed
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

    private static func freshRestoreURL(for backupStoreURL: URL, fileManager: FileManager) throws -> URL {
        let restoreDirectory = backupStoreURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        return restoreDirectory.appendingPathComponent(backupStoreURL.lastPathComponent)
    }
}

enum ScoreKeepFileCoordinationAssessment: String, CaseIterable, Hashable, Sendable {
    case notUsedForClosedDisposableStoreFamily
    case futureProductionAssessmentRequired

    static let current: ScoreKeepFileCoordinationAssessment = .notUsedForClosedDisposableStoreFamily
}
