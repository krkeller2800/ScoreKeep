import Foundation
import Testing
@testable import ScoreKeep

@Suite("Production startup recovery")
struct ProductionStartupRecoveryTests {
    @Test("recovery presentations are deterministic privacy safe and action scoped")
    func recoveryPresentationsArePrivacySafeAndActionScoped() {
        for code in ScoreKeepProductionStartupDiagnosticCode.allCases {
            let presentation = ScoreKeepProductionStartupRecoveryPresentation.make(
                diagnosticCode: code,
                protectedDataState: .available,
                capacityStatus: "capacity.sufficient",
                sourceStatus: "populatedCurrentUnversionedStore",
                backupStatus: "present",
                migrationPhase: "backupVerified",
                targetVerification: "notRun",
                retryAllowed: code == .migrationInterruptedRetryable || code == .capacityInsufficient
            )

            #expect(presentation.supportSummary.contains("/") == false)
            #expect(presentation.supportSummary.contains(".store") == false)
            #expect(presentation.supportSummary.contains("Proposed V2") == false)
            #expect(presentation.supportSummary.contains("00000000-0000-0000-0000") == false)
            #expect(presentation.title.contains("Proposed") == false)
            #expect(presentation.explanation.contains("journal") == false)
            #expect(presentation.actions.contains(.copySupportSummary))
        }
    }

    @Test("protected data capacity recovery and retry states expose only safe actions")
    func blockedStatesExposeOnlySafeActions() {
        let protected = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .protectedDataUnavailable,
            protectedDataState: .unavailable,
            capacityStatus: "notAssessed",
            sourceStatus: "notAssessed",
            backupStatus: "uncertain",
            migrationPhase: "protectedDataUnavailable",
            targetVerification: "notRun",
            retryAllowed: false
        )
        #expect(protected.actions.contains(.unlockDevice))
        #expect(protected.actions.contains(.retry) == false)
        #expect(protected.retryAllowed == false)

        let capacity = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .capacityInsufficient,
            protectedDataState: .available,
            capacityStatus: "capacity.insufficient",
            sourceStatus: "populatedCurrentUnversionedStore",
            backupStatus: "absent",
            migrationPhase: "notStarted",
            targetVerification: "notRun",
            retryAllowed: true
        )
        #expect(capacity.actions.contains(.freeUpStorage))
        #expect(capacity.actions.contains(.retry))
        #expect(capacity.retryAllowed)

        let retrying = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .migrationInterruptedRetryable,
            protectedDataState: .available,
            capacityStatus: "reassessing",
            sourceStatus: "reassessing",
            backupStatus: "reassessing",
            migrationPhase: "retrying",
            targetVerification: "notRun",
            retryAllowed: false,
            retryInProgress: true
        )
        #expect(retrying.diagnosticCode == .retryInProgress)
        #expect(retrying.actions.contains(.retry) == false)
        #expect(retrying.retryAllowed == false)
    }

    @Test("journal and orchestrator outcomes fail closed without writable UI")
    func startupOutcomeMappingsFailClosed() {
        for disposition in ScoreKeepMigrationOrchestratorDisposition.allCases {
            let code = ScoreKeepStartupOutcomePolicy.map(orchestratorDisposition: disposition)
            let workflow = ScoreKeepStartupOutcomePolicy.workflow(for: code)
            if disposition != .completed && disposition != .disabled {
                #expect(workflow.mayWriteRecords == false)
            }
        }

        let corrupt = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .journalCorrupt,
            protectedDataState: .available,
            capacityStatus: "notAssessed",
            sourceStatus: "uncertain",
            backupStatus: "uncertain",
            migrationPhase: "journalUnreadable",
            targetVerification: "notRun",
            retryAllowed: false
        )
        #expect(corrupt.retryAllowed == false)
        #expect(corrupt.actions.contains(.retry) == false)
        #expect(corrupt.actions == [.copySupportSummary])
    }

    @Test("post migration verification failure currently reports retry allowed without retry action")
    func postMigrationVerificationFailureReportsRetryAllowedWithoutRetryAction() {
        let presentation = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .postMigrationVerificationFailed,
            protectedDataState: .available,
            capacityStatus: "capacity.sufficient",
            sourceStatus: "proposedV1RecognizableStore",
            backupStatus: "present",
            migrationPhase: "recoveryRequired",
            targetVerification: "failed",
            retryAllowed: true
        )

        #expect(presentation.retryAllowed)
        #expect(presentation.supportSummary.contains("Retry: allowed"))
        #expect(presentation.actions.contains(.retry) == false)
    }

    @Test("post-open mismatch diagnostics persist and appear in support summary")
    @MainActor
    func postOpenMismatchDiagnosticsPersistAndAppearInSupportSummary() throws {
        let layout = try migrationLayout()
        let expected = baselineRecord(gameCount: 1, stableIdentityFingerprint: "expected-stable-identity")
        let actual = baselineRecord(gameCount: 2, stableIdentityFingerprint: "actual-stable-identity")
        let mismatchLines = ScoreKeepMigrationBaselineCapture.baselineMismatchDiagnosticLines(expected: expected, actual: actual)
        let verification = ScoreKeepProductionStartupModel.PostOpenMigrationBaselineVerificationResult(
            passed: false,
            diagnosticCodes: [.postOpenBaselineMismatchCounts, .postOpenBaselineMismatchStableIdentity],
            mismatchDiagnosticLines: mismatchLines
        )

        ScoreKeepProductionStartupModel.persistPostOpenBaselineMismatchDiagnosticSection(
            verification.mismatchDiagnosticSection,
            layout: layout,
            fileManager: .default
        )

        let persisted = try #require(ScoreKeepProductionStartupModel.persistedPostOpenBaselineMismatchDiagnosticSection(
            layout: layout,
            fileManager: .default
        ))
        let presentation = ScoreKeepProductionStartupRecoveryPresentation.make(
            diagnosticCode: .postMigrationVerificationFailed,
            protectedDataState: .available,
            capacityStatus: "capacity.sufficient",
            sourceStatus: "proposedV1RecognizableStore",
            backupStatus: "present",
            migrationPhase: "recoveryRequired",
            targetVerification: "failed",
            retryAllowed: true,
            additionalSupportSection: persisted
        )

        #expect(persisted.contains("Post-Open Baseline Mismatch Diagnostics"))
        #expect(persisted.contains("baselineMismatch.field=gameCount;expected=1;actual=2"))
        #expect(persisted.contains("baselineMismatch.field=stableIdentityFingerprint;expected=len="))
        #expect(persisted.contains("expected-stable-identity") == false)
        #expect(presentation.supportSummary.contains("Post-Open Baseline Mismatch Diagnostics"))
        #expect(presentation.supportSummary.contains("baselineMismatch.field=gameCount;expected=1;actual=2"))
        #expect(presentation.supportSummary.contains("/") == false)
        #expect(presentation.supportSummary.contains(".store") == false)
    }

    @Test("post-open and V1 backup diagnostics remain separate")
    @MainActor
    func postOpenAndV1BackupDiagnosticsRemainSeparate() throws {
        let layout = try migrationLayout()

        ScoreKeepProductionStartupModel.persistV1BackupVerificationDiagnosticSection(
            "V1 Backup Semantic Verification Diagnostics\nphase=afterOpenFailure",
            layout: layout,
            fileManager: .default
        )
        ScoreKeepProductionStartupModel.persistPostOpenBaselineMismatchDiagnosticSection(
            "Post-Open Baseline Mismatch Diagnostics\nbaselineMismatch.field=gameCount;expected=1;actual=2",
            layout: layout,
            fileManager: .default
        )

        let backupSection = try #require(ScoreKeepProductionStartupModel.persistedV1BackupVerificationDiagnosticSection(
            layout: layout,
            fileManager: .default
        ))
        let postOpenSection = try #require(ScoreKeepProductionStartupModel.persistedPostOpenBaselineMismatchDiagnosticSection(
            layout: layout,
            fileManager: .default
        ))

        #expect(backupSection.contains("V1 Backup Semantic Verification Diagnostics"))
        #expect(backupSection.contains("Post-Open Baseline Mismatch Diagnostics") == false)
        #expect(postOpenSection.contains("Post-Open Baseline Mismatch Diagnostics"))
        #expect(postOpenSection.contains("V1 Backup Semantic Verification Diagnostics") == false)
        #expect(ScoreKeepProductionStartupModel.persistedMigrationDiagnosticSection(
            for: .backupVerificationFailed,
            layout: layout,
            fileManager: .default
        ) == backupSection)
        #expect(ScoreKeepProductionStartupModel.persistedMigrationDiagnosticSection(
            for: .postMigrationVerificationFailed,
            layout: layout,
            fileManager: .default
        ) == postOpenSection)
        #expect(ScoreKeepProductionStartupModel.persistedMigrationDiagnosticSection(
            for: .migrationRecoveryRequired,
            layout: layout,
            fileManager: .default
        ) == nil)
    }

    @Test("successful post-open verification clears stale mismatch diagnostics")
    @MainActor
    func successfulPostOpenVerificationClearsStaleMismatchDiagnostics() throws {
        let layout = try migrationLayout()

        ScoreKeepProductionStartupModel.persistV1BackupVerificationDiagnosticSection(
            "V1 Backup Semantic Verification Diagnostics\nphase=afterOpenSuccess",
            layout: layout,
            fileManager: .default
        )
        ScoreKeepProductionStartupModel.persistPostOpenBaselineMismatchDiagnosticSection(
            "Post-Open Baseline Mismatch Diagnostics\nbaselineMismatch.field=gameCount;expected=1;actual=2",
            layout: layout,
            fileManager: .default
        )

        let successfulVerification = ScoreKeepProductionStartupModel.PostOpenMigrationBaselineVerificationResult(
            passed: true,
            diagnosticCodes: [],
            mismatchDiagnosticLines: []
        )
        ScoreKeepProductionStartupModel.persistPostOpenBaselineMismatchDiagnosticSection(
            successfulVerification.mismatchDiagnosticSection,
            layout: layout,
            fileManager: .default
        )

        #expect(ScoreKeepProductionStartupModel.persistedPostOpenBaselineMismatchDiagnosticSection(layout: layout, fileManager: .default) == nil)
        #expect(ScoreKeepProductionStartupModel.persistedV1BackupVerificationDiagnosticSection(layout: layout, fileManager: .default)?.contains("V1 Backup Semantic Verification Diagnostics") == true)
    }

    @Test("debug fresh migration attempt archives control directory and preserves active source family")
    func debugFreshMigrationAttemptArchivesControlDirectoryAndPreservesActiveSourceFamily() throws {
        let layout = try migrationLayout()
        try makeActiveSourceFamily(layout: layout, includeSidecars: true)
        try makeMigrationControlDirectory(layout: layout)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore)

        let result = try ScoreKeepDebugFreshMigrationAttempt.prepare(
            layout: layout,
            debugBuildEnabled: true,
            archiveNameProvider: { "ScoreKeepMigrationControl-v1-preserved-fixed" }
        )

        #expect(result.archiveURL.lastPathComponent == "ScoreKeepMigrationControl-v1-preserved-fixed")
        #expect(FileManager.default.fileExists(atPath: layout.migrationControlRoot.path) == false)
        #expect(FileManager.default.fileExists(atPath: result.archiveURL.appendingPathComponent("marker.txt").path))
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore) == sourceBefore)
        #expect(FileManager.default.fileExists(atPath: layout.activeStore.path))
        #expect(FileManager.default.fileExists(atPath: layout.activeStore.path + "-wal"))
        #expect(FileManager.default.fileExists(atPath: layout.activeStore.path + "-shm"))
        #expect(result.userMessage == "Fresh migration attempt prepared. Close and relaunch ScoreKeep.")
    }

    @Test("debug fresh migration attempt fails closed on archive collision")
    func debugFreshMigrationAttemptFailsClosedOnArchiveCollision() throws {
        let layout = try migrationLayout()
        try makeActiveSourceFamily(layout: layout, includeSidecars: false)
        try makeMigrationControlDirectory(layout: layout)
        let archiveURL = layout.migrationControlRoot
            .deletingLastPathComponent()
            .appendingPathComponent("ScoreKeepMigrationControl-v1-preserved-collision", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore)

        #expect(throws: ScoreKeepDebugFreshMigrationAttemptError.archiveDestinationExists) {
            try ScoreKeepDebugFreshMigrationAttempt.prepare(
                layout: layout,
                debugBuildEnabled: true,
                archiveNameProvider: { archiveURL.lastPathComponent }
            )
        }

        #expect(FileManager.default.fileExists(atPath: layout.migrationControlRoot.appendingPathComponent("marker.txt").path))
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore) == sourceBefore)
    }

    @Test("debug fresh migration attempt fails closed when archive rename fails")
    func debugFreshMigrationAttemptFailsClosedWhenArchiveRenameFails() throws {
        let layout = try migrationLayout()
        try makeActiveSourceFamily(layout: layout, includeSidecars: true)
        try makeMigrationControlDirectory(layout: layout)
        let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore)

        #expect(throws: ScoreKeepDebugFreshMigrationAttemptError.archiveRenameFailed) {
            try ScoreKeepDebugFreshMigrationAttempt.prepare(
                layout: layout,
                fileManager: RenameFailureFileManager(),
                debugBuildEnabled: true,
                archiveNameProvider: { "ScoreKeepMigrationControl-v1-preserved-rename-failure" }
            )
        }

        #expect(FileManager.default.fileExists(atPath: layout.migrationControlRoot.appendingPathComponent("marker.txt").path))
        #expect(try ScoreKeepStoreFamilyDiscovery.discover(storeURL: layout.activeStore) == sourceBefore)
    }

    @Test("fresh migration attempt is unavailable when debug gate is disabled")
    func freshMigrationAttemptIsUnavailableWhenDebugGateIsDisabled() throws {
        let layout = try migrationLayout()
        try makeActiveSourceFamily(layout: layout, includeSidecars: true)
        try makeMigrationControlDirectory(layout: layout)

        #expect(throws: ScoreKeepDebugFreshMigrationAttemptError.unavailableOutsideDebug) {
            try ScoreKeepDebugFreshMigrationAttempt.prepare(layout: layout, debugBuildEnabled: false)
        }

        #expect(FileManager.default.fileExists(atPath: layout.migrationControlRoot.appendingPathComponent("marker.txt").path))
    }

    private func migrationLayout() throws -> ScoreKeepProductionMigrationLayout {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProductionStartupRecoveryTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
    }

    private func makeActiveSourceFamily(layout: ScoreKeepProductionMigrationLayout, includeSidecars: Bool) throws {
        try Data([0x53, 0x4b]).write(to: layout.activeStore)
        if includeSidecars {
            try Data([0x57, 0x41, 0x4c]).write(to: URL(fileURLWithPath: layout.activeStore.path + "-wal"))
            try Data([0x53, 0x48, 0x4d]).write(to: URL(fileURLWithPath: layout.activeStore.path + "-shm"))
        }
    }

    private func makeMigrationControlDirectory(layout: ScoreKeepProductionMigrationLayout) throws {
        try FileManager.default.createDirectory(at: layout.migrationControlRoot, withIntermediateDirectories: true)
        try Data([0x01]).write(to: layout.migrationControlRoot.appendingPathComponent("marker.txt"))
    }

    private func baselineRecord(gameCount: Int, stableIdentityFingerprint: String) -> ScoreKeepMigrationBaselineRecord {
        ScoreKeepMigrationBaselineRecord(
            schemaVersion: 1,
            schemaClassification: "currentUnversionedLegacySwiftData",
            gameCount: gameCount,
            teamCount: 0,
            playerCount: 0,
            lineupCount: 0,
            atbatCount: 0,
            pitcherCount: 0,
            teamCreationOperationEvidenceCount: 0,
            canonicalHistoryCount: 0,
            canonicalEventCount: 0,
            canonicalPayloadCount: 0,
            canonicalOperationCount: 0,
            canonicalCorrectionCount: 0,
            legacyScoringOperationEvidenceCount: 0,
            stableIdentityFingerprint: stableIdentityFingerprint,
            relationshipFingerprint: "same-relationship",
            orderingFingerprint: "same-ordering",
            scoreEvidence: "same-score",
            substitutionEvidence: "same-substitution",
            mediaOwnershipFingerprint: "same-media",
            importSourceClassification: "same-import",
            difficultRunnerSequence: ScoreKeepDifficultRunnerSequenceEvidence(
                status: "same-runner",
                runnerIdentityFingerprint: nil,
                originatingAtbatFingerprint: nil,
                interveningAtbatOrderFingerprint: nil,
                runnerOutEvidence: "same-runner-out",
                thirdOutClassification: "same-third-out",
                inningBoundary: "same-boundary",
                nextBatterEvidence: "same-next-batter",
                scoreBeforeBoundary: "same-score-before",
                scoreAfterBoundary: "same-score-after",
                unsupportedFacts: []
            ),
            capturedAt: Date(timeIntervalSince1970: 0),
            status: "ok",
            diagnosticCodes: []
        )
    }

    private final class RenameFailureFileManager: FileManager, @unchecked Sendable {
        override func moveItem(at srcURL: URL, to dstURL: URL) throws {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}
