import Foundation
#if canImport(Testing)
import Testing
@testable import ScoreKeep

@Suite("Production migration pre-open journal")
struct ScoreKeepMigrationJournalTests {
    @Test("journal persists across fresh instances and simulated relaunch")
    func journalPersistsAcrossFreshInstancesAndSimulatedRelaunch() throws {
        let store = try journalStore()
        let operation = operationIdentity(storeIdentity: "source-a")
        var record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operation,
            sourceStoreDiagnosticIdentity: "source-a",
            sourceClassification: .populatedCurrentUnversionedStore
        )

        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .preflightStarted)
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .sourceClassified)
        try store.save(record)

        let relaunched = ScoreKeepMigrationJournalStore(directory: store.directory).load()
        #expect(relaunched.record?.operationIdentity == operation)
        #expect(relaunched.record?.phase == .sourceClassified)
        #expect(relaunched.record?.transitionGeneration == 2)
        #expect(relaunched.error == nil)
    }

    @Test("malformed and unsupported journal versions fail closed")
    func malformedAndUnsupportedJournalVersionsFailClosed() throws {
        let malformed = try journalStore()
        try Data("not-json".utf8).write(to: malformed.journalURL)
        let malformedLoad = malformed.load()
        #expect(malformedLoad.record == nil)
        #expect(malformedLoad.error == .decodingFailed)
        #expect(malformedLoad.diagnosticCodes == [.journalUnreadable])

        let unsupported = try journalStore()
        var record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operationIdentity(storeIdentity: "source-b"),
            sourceStoreDiagnosticIdentity: "source-b",
            sourceClassification: .emptyCurrentUnversionedStore
        )
        record.journalSchemaVersion = 99
        let encoder = JSONEncoder()
        try encoder.encode(record).write(to: unsupported.journalURL)
        let unsupportedLoad = unsupported.load()
        #expect(unsupportedLoad.record == nil)
        #expect(unsupportedLoad.error == .unsupportedJournalVersion(99))
        #expect(unsupportedLoad.diagnosticCodes == [.journalVersionUnsupported])
    }

    @Test("transition rules reject regression conflicts and incomplete completion")
    func transitionRulesRejectRegressionConflictsAndIncompleteCompletion() throws {
        let operation = operationIdentity(storeIdentity: "source-c")
        var record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operation,
            sourceStoreDiagnosticIdentity: "source-c",
            sourceClassification: .populatedCurrentUnversionedStore
        )
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .preflightStarted)
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .sourceClassified)

        #expect(throws: ScoreKeepMigrationJournalError.phaseRegression(from: .sourceClassified, to: .preflightStarted)) {
            try ScoreKeepMigrationJournalTransition.advance(record, to: .preflightStarted)
        }
        #expect(throws: ScoreKeepMigrationJournalError.conflictingOperationIdentity) {
            try ScoreKeepMigrationJournalTransition.advance(
                record,
                to: .sourcePreservationStarted,
                operationIdentity: operationIdentity(storeIdentity: "source-c", uuid: UUID(uuidString: "00000000-0000-0000-0000-000000008002")!)
            )
        }
        #expect(throws: ScoreKeepMigrationJournalError.conflictingSourceIdentity) {
            try ScoreKeepMigrationJournalTransition.advance(record, to: .sourcePreservationStarted, sourceStoreDiagnosticIdentity: "other")
        }
        #expect(throws: ScoreKeepMigrationJournalError.completionRequiresVerifiedBackup) {
            try ScoreKeepMigrationJournalTransition.advance(record, to: .completionRecorded, postOpenVerificationDisposition: "passed")
        }
    }

    @Test("disable state and ownership fail closed and reject dual authority")
    func disableStateAndOwnershipFailClosedAndRejectDualAuthority() throws {
        #expect(ScoreKeepSchemaRouteDisableState.currentDefault == .legacyRouteRequired)
        let missingState = try ScoreKeepSchemaRouteDisableAuthority.resolve(state: nil, authorizationEvidence: nil)
        #expect(missingState == .unsafe)
        #expect(throws: ScoreKeepMigrationJournalError.authorizationRequired) {
            try ScoreKeepSchemaRouteDisableAuthority.resolve(state: .proposedTransitionExplicitlyAuthorized, authorizationEvidence: nil)
        }
        let authorized = try ScoreKeepSchemaRouteDisableAuthority.resolve(state: .proposedTransitionExplicitlyAuthorized, authorizationEvidence: "local-explicit-test-authorization")
        #expect(authorized == .proposedTransitionExplicitlyAuthorized)

        let legacy = ScoreKeepStartupOwnershipAuthority.claim(current: .noOwner, requested: .legacyContainerSelected)
        #expect(legacy == .legacyContainerSelected)
        let conflict = ScoreKeepStartupOwnershipAuthority.claim(current: legacy, requested: .proposedContainerSelected)
        #expect(conflict == .conflictingOwners)
        #expect(conflict.blocksWrites)
    }

    @Test("atomic replacement preserves prior valid journal after failed replacement")
    func atomicReplacementPreservesPriorValidJournalAfterFailedReplacement() throws {
        let store = try journalStore()
        let operation = operationIdentity(storeIdentity: "source-d")
        let record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operation,
            sourceStoreDiagnosticIdentity: "source-d",
            sourceClassification: .populatedCurrentUnversionedStore
        )
        try store.save(record)

        let invalidDirectoryStore = ScoreKeepMigrationJournalStore(
            directory: store.journalURL,
            fileName: "nested-journal"
        )
        var didThrow = false
        do {
            try invalidDirectoryStore.save(record)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
        #expect(store.load().record == record)
    }

    private func journalStore() throws -> ScoreKeepMigrationJournalStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepMigrationJournalTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ScoreKeepMigrationJournalStore(directory: directory)
    }

    private func operationIdentity(
        storeIdentity: String,
        uuid: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000008001")!
    ) -> ScoreKeepMigrationOperationIdentity {
        ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: storeIdentity,
            sourceSchema: .populatedCurrentUnversionedStore,
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: uuid
        )
    }

    @Test("empty store creation successfully advances to completion recorded")
    func emptyStoreCreationAdvancesToCompletionRecorded() throws {
        let operation = operationIdentity(storeIdentity: "source-empty")
        var record = ScoreKeepMigrationJournalRecord.initial(
            operationIdentity: operation,
            sourceStoreDiagnosticIdentity: "source-empty",
            sourceClassification: .emptyCurrentUnversionedStore
        )
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .preflightStarted)
        record = try ScoreKeepMigrationJournalTransition.advance(record, to: .sourceClassified)
        record = try ScoreKeepMigrationJournalTransition.advance(
            record,
            to: .backupVerified,
            sourcePreservationDisposition: .notRequiredForNewEmptyStore,
            backupVerificationDisposition: .notRequiredForNewEmptyStore,
            retryClassification: .noRetryRequired
        )
        record = try ScoreKeepMigrationJournalTransition.advance(
            record,
            to: .postOpenVerificationPassed,
            postOpenVerificationDisposition: "passed"
        )

        // This must not throw completionRequiresVerifiedBackup after our fix.
        record = try ScoreKeepMigrationJournalTransition.advance(
            record,
            to: .completionRecorded,
            completionDisposition: "sidecarCompletionRecorded",
            retryClassification: .noRetryRequired,
            recoveryRequirement: .noRecoveryRequired
        )
        #expect(record.phase == .completionRecorded)
    }
}
#endif
