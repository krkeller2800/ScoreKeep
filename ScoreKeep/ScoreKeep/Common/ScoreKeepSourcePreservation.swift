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
    let authorizationScope: ScoreKeepSourcePreservationAuthorizationScope

    init(
        sourceStoreURL: URL,
        backupStoreURL: URL,
        sourceLocation: ScoreKeepStartupStoreLocation.Kind,
        sourceClosureEvidence: ScoreKeepSourceClosureEvidence,
        allowIncompleteTestOwnedBackupRemoval: Bool,
        semanticRestoreVerifier: ((URL) throws -> Bool)?,
        authorizationScope: ScoreKeepSourcePreservationAuthorizationScope = .testOwnedDisposable
    ) {
        self.sourceStoreURL = sourceStoreURL
        self.backupStoreURL = backupStoreURL
        self.sourceLocation = sourceLocation
        self.sourceClosureEvidence = sourceClosureEvidence
        self.allowIncompleteTestOwnedBackupRemoval = allowIncompleteTestOwnedBackupRemoval
        self.semanticRestoreVerifier = semanticRestoreVerifier
        self.authorizationScope = authorizationScope
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
            do {
                semanticVerificationPassed = try semanticRestoreVerifier(restoreURL)
            } catch {
                throw ScoreKeepSourcePreservationError.semanticVerificationFailed(
                    .semanticRestoreOpen(ScoreKeepSourcePreservationErrorIdentity.semanticRestoreOpenDiagnostic(for: error))
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

enum ScoreKeepFileCoordinationAssessment: String, CaseIterable, Hashable, Sendable {
    case notUsedForClosedDisposableStoreFamily
    case futureProductionAssessmentRequired

    static let current: ScoreKeepFileCoordinationAssessment = .notUsedForClosedDisposableStoreFamily
}
