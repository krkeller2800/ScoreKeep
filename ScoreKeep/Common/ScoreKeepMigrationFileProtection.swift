import Foundation

enum ScoreKeepMigrationArtifactKind: String, CaseIterable, Hashable, Sendable {
    case journal
    case backupDirectory
    case backupPrimaryFile
    case backupSidecar
    case temporaryTarget
    case recoveryCopy
    case diagnosticState
}

enum ScoreKeepMigrationFileProtectionPolicy: String, CaseIterable, Hashable, Sendable {
    case inheritActiveStoreProtection
    case completeProtection
    case completeUntilFirstUserAuthentication
    case completeUnlessOpen
    case noExplicitOverridePlatformDefaultRequired
    case furtherDeviceProofRequired
}

enum ScoreKeepMigrationFileProtectionDisposition: String, CaseIterable, Hashable, Sendable {
    case appliedAndVerified
    case appliedVerificationUnsupported
    case unsupportedPlatform
    case missingItem
    case pathOutsideAuthorizedRoot
    case symbolicLinkEscape
    case applicationFailed
    case verificationFailed
    case noExplicitOverrideRequired
}

struct ScoreKeepMigrationFileProtectionResult: Hashable, Sendable {
    let disposition: ScoreKeepMigrationFileProtectionDisposition
    let policy: ScoreKeepMigrationFileProtectionPolicy
    let diagnosticCode: String

    var permitsProductionActivationWhenMandatory: Bool {
        disposition == .appliedAndVerified || disposition == .appliedVerificationUnsupported || disposition == .noExplicitOverrideRequired
    }
}

enum ScoreKeepMigrationFileProtectionPolicyResolver {
    static func policy(for artifact: ScoreKeepMigrationArtifactKind) -> ScoreKeepMigrationFileProtectionPolicy {
        switch artifact {
        case .journal:
            return .completeUntilFirstUserAuthentication
        case .backupDirectory, .backupPrimaryFile, .backupSidecar, .temporaryTarget, .recoveryCopy:
            return .inheritActiveStoreProtection
        case .diagnosticState:
            return .completeUntilFirstUserAuthentication
        }
    }
}

enum ScoreKeepMigrationFileProtectionApplicator {
    static func apply(
        artifact: ScoreKeepMigrationArtifactKind,
        url: URL,
        authorizedRoot: URL,
        inheritedSourceProtection: FileProtectionType? = nil,
        fileManager: FileManager = .default
    ) -> ScoreKeepMigrationFileProtectionResult {
        let policy = ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: artifact)
        let resolvedRoot = authorizedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard ScoreKeepProductionPathValidator.contains(resolvedRoot, resolvedURL) else {
            return result(.pathOutsideAuthorizedRoot, policy: policy)
        }
        guard fileManager.fileExists(atPath: resolvedURL.path) else {
            return result(.missingItem, policy: policy)
        }
        guard let targetProtection = fileProtectionType(for: policy, inheritedSourceProtection: inheritedSourceProtection) else {
            return result(policy == .noExplicitOverridePlatformDefaultRequired ? .noExplicitOverrideRequired : .unsupportedPlatform, policy: policy)
        }
        do {
            try fileManager.setAttributes([.protectionKey: targetProtection], ofItemAtPath: resolvedURL.path)
        } catch {
            return result(.applicationFailed, policy: policy)
        }
        guard let observed = try? fileManager.attributesOfItem(atPath: resolvedURL.path)[.protectionKey] as? FileProtectionType else {
            return result(.appliedVerificationUnsupported, policy: policy)
        }
        return observed == targetProtection ? result(.appliedAndVerified, policy: policy) : result(.verificationFailed, policy: policy)
    }

    static func assessedCurrentProtection(url: URL, fileManager: FileManager = .default) -> FileProtectionType? {
        try? fileManager.attributesOfItem(atPath: url.path)[.protectionKey] as? FileProtectionType
    }

    private static func fileProtectionType(for policy: ScoreKeepMigrationFileProtectionPolicy, inheritedSourceProtection: FileProtectionType?) -> FileProtectionType? {
        switch policy {
        case .inheritActiveStoreProtection:
            return inheritedSourceProtection ?? .completeUntilFirstUserAuthentication
        case .completeProtection:
            return .complete
        case .completeUntilFirstUserAuthentication:
            return .completeUntilFirstUserAuthentication
        case .completeUnlessOpen:
            return .completeUnlessOpen
        case .noExplicitOverridePlatformDefaultRequired, .furtherDeviceProofRequired:
            return nil
        }
    }

    private static func result(_ disposition: ScoreKeepMigrationFileProtectionDisposition, policy: ScoreKeepMigrationFileProtectionPolicy) -> ScoreKeepMigrationFileProtectionResult {
        ScoreKeepMigrationFileProtectionResult(disposition: disposition, policy: policy, diagnosticCode: "protection.\(disposition.rawValue)")
    }
}
