import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Migration file protection policy")
struct ScoreKeepMigrationFileProtectionTests {
    @Test("artifact policies select startup-safe and source-inheriting protection")
    func artifactPoliciesAreSelected() {
        #expect(ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: .journal) == .completeUntilFirstUserAuthentication)
        #expect(ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: .diagnosticState) == .completeUntilFirstUserAuthentication)
        #expect(ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: .backupPrimaryFile) == .inheritActiveStoreProtection)
        #expect(ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: .temporaryTarget) == .inheritActiveStoreProtection)
        #expect(ScoreKeepMigrationFileProtectionPolicyResolver.policy(for: .recoveryCopy) == .inheritActiveStoreProtection)
    }

    @Test("protection application is restricted to injected authorized roots")
    func protectionApplicationRequiresAuthorizedRoot() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        try environment.createControlDirectories()
        let journal = environment.layout.journal
        try environment.createSmallFile(journal)
        let outside = environment.root.deletingLastPathComponent().appendingPathComponent("outside.json")
        try environment.createSmallFile(outside)
        let result = ScoreKeepMigrationFileProtectionApplicator.apply(artifact: .journal, url: journal, authorizedRoot: environment.layout.migrationControlRoot)
        #expect(result.permitsProductionActivationWhenMandatory || result.disposition == .applicationFailed)
        #expect(ScoreKeepMigrationFileProtectionApplicator.apply(artifact: .journal, url: outside, authorizedRoot: environment.layout.migrationControlRoot).disposition == .pathOutsideAuthorizedRoot)
    }

    @Test("missing files and copied backup sidecars are classified explicitly")
    func missingAndBackupSidecarsClassify() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        try environment.createControlDirectories()
        let missing = environment.layout.backupsRoot.appendingPathComponent("missing.store")
        #expect(ScoreKeepMigrationFileProtectionApplicator.apply(artifact: .backupPrimaryFile, url: missing, authorizedRoot: environment.layout.migrationControlRoot).disposition == .missingItem)
        let primary = environment.layout.backupsRoot.appendingPathComponent("operation").appendingPathComponent("ScoreKeep.store")
        let wal = environment.layout.backupsRoot.appendingPathComponent("operation").appendingPathComponent("ScoreKeep.store-wal")
        try environment.createSmallFile(primary)
        try FileManager.default.copyItem(at: primary, to: wal)
        let primaryResult = ScoreKeepMigrationFileProtectionApplicator.apply(artifact: .backupPrimaryFile, url: primary, authorizedRoot: environment.layout.migrationControlRoot)
        let sidecarResult = ScoreKeepMigrationFileProtectionApplicator.apply(artifact: .backupSidecar, url: wal, authorizedRoot: environment.layout.migrationControlRoot)
        #expect(primaryResult.diagnosticCode.hasPrefix("protection."))
        #expect(sidecarResult.diagnosticCode.hasPrefix("protection."))
    }
}
