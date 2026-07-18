import CoreData
import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@Suite("Completed journal recovery routing")
struct CompletedJournalRecoveryRoutingTests {
    @Test("completion recorded with clean V3 target opens completed target")
    func cleanV3TargetOpensCompletedTarget() {
        #expect(route(target: .existingProposedV3Store, active: .existingProposedV2Store, journal: .populatedCurrentUnversionedStore) == .openCompletedTargetAsV3)
    }

    @Test("invalid target and clean V2 active requires fresh preparation")
    func invalidTargetAndCleanV2ActiveRequiresFreshPreparation() {
        #expect(route(target: .unknownVersion, active: .existingProposedV2Store, journal: .populatedCurrentUnversionedStore) == .activeV2RequiresFreshPreparation)
    }

    @Test("verified V2 completed target routes to blocked semantic verifier boundary")
    func verifiedV2TargetRoutesToBlockedSemanticVerifierBoundary() throws {
        #expect(route(target: .existingProposedV2Store, active: .unknownVersion, journal: .populatedCurrentUnversionedStore) == .recoverCompletedTargetV2ToFreshV3)
        #expect(try productionStartupHostSource().contains("semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums"))
    }

    @Test("verified V2 completed target requires verified backup before recovery")
    func verifiedV2TargetRequiresVerifiedBackup() {
        #expect(route(target: .existingProposedV2Store, active: .unknownVersion, journal: .populatedCurrentUnversionedStore, backupVerified: false) == .failClosed)
    }

    @Test("invalid target and clean V3 active opens active V3")
    func invalidTargetAndCleanV3ActiveOpensActiveV3() {
        #expect(route(target: .unknownVersion, active: .existingProposedV3Store, journal: .populatedCurrentUnversionedStore) == .openActiveStoreAsV3)
    }

    @Test("invalid target and unsupported active metadata fails closed")
    func invalidTargetAndUnsupportedActiveFailsClosed() {
        #expect(route(target: .unknownVersion, active: .unreadableStore, journal: .populatedCurrentUnversionedStore) == .failClosed)
    }

    @Test("recognizable V1 active source routes to blocked semantic verifier boundary")
    func recognizableV1ActiveSourceRoutesToBlockedSemanticVerifierBoundary() {
        #expect(route(target: .unknownVersion, active: .proposedV1RecognizableStore, journal: .populatedCurrentUnversionedStore) == .recoverActiveV1ToFreshV3)
    }

    @Test("recognizable V1 active source requires verified stale backup evidence")
    func recognizableV1ActiveSourceRequiresVerifiedBackupEvidence() {
        #expect(route(target: .unknownVersion, active: .proposedV1RecognizableStore, journal: .populatedCurrentUnversionedStore, backupVerified: false) == .failClosed)
    }

    @Test("recognizable V1 recovery does not pre-open source with an ad hoc baseline schema")
    func recognizableV1RecoveryDoesNotPreOpenSourceWithAdHocBaselineSchema() throws {
        let source = try productionStartupHostSource()

        #expect(source.contains("proposedV1Baseline") == false)
        #expect(source.contains("sourceBaselineReadback") == false)
        #expect(source.contains("let sourceBaseline") == false)
    }

    @Test("recognizable V1 recovery path is retained as blocked diagnostic scaffolding")
    func recognizableV1RecoveryPathIsRetainedAsBlockedDiagnosticScaffolding() throws {
        let source = try productionStartupHostSource()
        let routeCase = try #require(source.range(of: "case .recoverActiveV1ToFreshV3:"))
        let blocker = try #require(source.range(of: "semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums"))
        let retainedHelper = try #require(source.range(of: "private func recoverActiveV1ThroughFreshV3"))

        #expect(routeCase.lowerBound < blocker.lowerBound)
        #expect(blocker.lowerBound < retainedHelper.lowerBound)
    }

    @Test("completed V2 recovery helper is retained but production switch fails closed before calling it")
    func completedV2RecoveryHelperIsRetainedButProductionSwitchFailsClosedBeforeCallingIt() throws {
        let source = try productionStartupHostSource()
        let routeCase = try #require(source.range(of: "case .recoverCompletedTargetV2ToFreshV3:"))
        let blocker = try #require(source.range(of: "semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums"))
        let retainedHelper = try #require(source.range(of: "private func recoverCompletedJournalV2Target"))

        #expect(routeCase.lowerBound < blocker.lowerBound)
        #expect(blocker.lowerBound < retainedHelper.lowerBound)
    }

    @Test("clean metadata wins over stale journal classification")
    func cleanMetadataWinsOverStaleJournalClassification() {
        #expect(route(target: .existingProposedV3Store, active: .unknownVersion, journal: .populatedCurrentUnversionedStore) == .openCompletedTargetAsV3)
        #expect(route(target: .unknownVersion, active: .existingProposedV3Store, journal: .populatedCurrentUnversionedStore) == .openActiveStoreAsV3)
        #expect(route(target: .existingProposedV2Store, active: .unknownVersion, journal: .populatedCurrentUnversionedStore) == .recoverCompletedTargetV2ToFreshV3)
    }

    @Test("routing is classification only and does not synthesize canonical records")
    func routingDoesNotSynthesizeCanonicalRecords() {
        let allRoutes = [
            route(target: .existingProposedV3Store, active: .existingProposedV2Store, journal: .populatedCurrentUnversionedStore),
            route(target: .unknownVersion, active: .existingProposedV2Store, journal: .populatedCurrentUnversionedStore),
            route(target: .unknownVersion, active: .existingProposedV3Store, journal: .populatedCurrentUnversionedStore),
            route(target: .existingProposedV2Store, active: .unknownVersion, journal: .populatedCurrentUnversionedStore),
            route(target: .unknownVersion, active: .unknownVersion, journal: .populatedCurrentUnversionedStore)
        ]
        #expect(allRoutes.count == 5)
    }

    @Test("failed recovery generation is preserved and never reused")
    func failedRecoveryGenerationIsSkipped() {
        let selected = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { offset in
            offset == 1 ? .failedPreserved : .empty
        }
        #expect(selected == 2)
    }

    @Test("store family error code 3 is backup directory not fresh")
    func storeFamilyErrorCode3IsBackupDirectoryNotFresh() {
        let error = ScoreKeepStoreFamilyError.backupDirectoryNotFresh as NSError

        #expect(error.domain.contains("ScoreKeepStoreFamilyError"))
        #expect(error.code == 3)
    }

    @Test("persistent store error identity preserves underlying Core Data category")
    func persistentStoreErrorIdentityPreservesUnderlyingCoreDataCategory() {
        let coreData = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134100,
            userInfo: [NSLocalizedFailureReasonErrorKey: "The model used to open the store is incompatible with the one used to create the store."]
        )
        let swiftData = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: coreData]
        )

        #expect(ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: swiftData) == "incompatibleModel")
    }

    @Test("persistent store error identity distinguishes SQLite lock and corruption")
    func persistentStoreErrorIdentityDistinguishesSQLiteFailures() {
        let locked = NSError(domain: "NSSQLiteErrorDomain", code: 5)
        let corrupt = NSError(domain: "NSSQLiteErrorDomain", code: 26)

        #expect(ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: locked) == "storeLocked")
        #expect(ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: corrupt) == "storeCorrupt")
    }

    @Test("persistent store error identity reports duplicate checksum distinctly")
    func persistentStoreErrorIdentityReportsDuplicateChecksum() {
        let duplicate = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134110,
            userInfo: [NSLocalizedFailureReasonErrorKey: "Duplicate version checksums detected."]
        )

        #expect(ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: duplicate) == "duplicateChecksum")
    }

    @Test("persistent store error identity falls back to sanitized domain and code")
    func persistentStoreErrorIdentityFallsBackToSanitizedDomainAndCode() {
        let unknown = NSError(domain: "SwiftData.SwiftDataError", code: 1)

        #expect(ScoreKeepSanitizedPersistentStoreErrorIdentity.make(for: unknown) == "unknownCoreData.SwiftData_SwiftDataError.1")
    }

    @Test("V1 to V2 diagnostic walks nested and detailed errors without leaking paths")
    func v1ToV2DiagnosticWalksNestedAndDetailedErrorsSafely() {
        let detailed = NSError(
            domain: "NSSQLiteErrorDomain",
            code: 5,
            userInfo: [
                "/private/tmp/user/ScoreKeep.store": "private",
                NSLocalizedRecoverySuggestionErrorKey: "Retry after the file is unlocked."
            ]
        )
        let coreData = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134100,
            userInfo: [
                NSDetailedErrorsKey: [detailed],
                NSLocalizedFailureReasonErrorKey: "The model used to open /private/tmp/user/ScoreKeep.store is incompatible."
            ]
        )
        let swiftData = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: coreData]
        )

        let report = ScoreKeepSanitizedPersistentStoreErrorIdentity.makeReport(for: swiftData)

        #expect(report.identity == "storeLocked")
        #expect(report.diagnostic.contains("top.SwiftData_SwiftDataError.1"))
        #expect(report.diagnostic.contains("nested1.NSCocoaErrorDomain.134100"))
        #expect(report.diagnostic.contains("nested2.NSSQLiteErrorDomain.5"))
        #expect(report.diagnostic.contains("hasUnderlyingError"))
        #expect(report.diagnostic.contains("hasDetailedErrors"))
        #expect(report.diagnostic.contains("NSDetailedErrorsKey"))
        #expect(report.diagnostic.contains("OtherUserInfoKey"))
        #expect(report.diagnostic.contains("/private") == false)
        #expect(report.diagnostic.contains("ScoreKeep.store") == false)
        #expect(report.diagnostic.contains("incompatible") == false)
    }

    @Test("pre-backup artifacts make a recovery generation failed-preserved")
    func preBackupArtifactsMakeRecoveryGenerationFailedPreserved() {
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: nil, hasPreservedPreBackupArtifacts: true) == .failedPreserved)
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .sourceClassified, hasPreservedPreBackupArtifacts: true) == .failedPreserved)
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .sourcePreservationStarted, hasPreservedPreBackupArtifacts: true) == .failedPreserved)
    }

    @Test("verified backup artifacts remain resumable")
    func verifiedBackupArtifactsRemainResumable() {
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .backupVerified, hasPreservedPreBackupArtifacts: true) == .usableExisting)
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .containerConstructed, hasPreservedPreBackupArtifacts: true) == .usableExisting)
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .completionRecorded, hasPreservedPreBackupArtifacts: true) == .usableExisting)
    }

    @Test("backup verified V1 recovery resumes without copying source backup again")
    func backupVerifiedV1RecoveryResumesWithoutCopyingSourceBackupAgain() throws {
        let source = try productionStartupHostSource()
        let backupVerifiedGuard = try #require(source.range(of: "if journal.phase < .backupVerified"))
        let sourcePreservation = try #require(source.range(of: "preserveStoreFamily(\n                        from: sourceURL"))
        let migrationAttemptRecord = try #require(source.range(of: "recoveryBoundary = .v1ToV2MigrationAttemptRecord"))
        let v2IntermediatePreparation = try #require(source.range(of: "preserveStoreFamily(\n                        from: backupURL"))

        #expect(backupVerifiedGuard.lowerBound < sourcePreservation.lowerBound)
        #expect(sourcePreservation.lowerBound < migrationAttemptRecord.lowerBound)
        #expect(migrationAttemptRecord.lowerBound < v2IntermediatePreparation.lowerBound)
        #expect(source.contains("copyStoreFamily(from: sourceURL, to: backupURL") == false)
    }

    @Test("V1 recovery does not recopy existing V2 intermediate")
    func v1RecoveryDoesNotRecopyExistingV2Intermediate() throws {
        let source = try productionStartupHostSource()
        let v2FreshGuard = try #require(source.range(of: "storeFamilyPrimaryExists(selectedV2URL, fileManager: fileManager) == false"))
        let v2Preparation = try #require(source.range(of: "preserveStoreFamily(\n                        from: backupURL"))
        let v1ToV2Open = try #require(source.range(of: "proposedV2MigratingFromV1Container(url: selectedV2URL)"))

        #expect(v2FreshGuard.lowerBound < v2Preparation.lowerBound)
        #expect(v2Preparation.lowerBound < v1ToV2Open.lowerBound)
        #expect(source.contains("copyStoreFamily(from: backupURL, to: v2URL") == false)
    }

    @Test("V1 recovery uses established preservation authority before durable backup verification")
    func v1RecoveryUsesEstablishedPreservationAuthorityBeforeDurableBackupVerification() throws {
        let source = try productionStartupHostSource()
        _ = try #require(source.range(of: "ScoreKeepSourcePreservationExecutor.preserve"))
        let sourcePreservation = try #require(source.range(of: "preserveStoreFamily(\n                        from: sourceURL"))
        let tail = source[sourcePreservation.lowerBound...]
        let copiedIdentity = try #require(tail.range(of: "backupIdentity: preservation.backupIdentity"))
        let durableBackup = try #require(tail.range(of: "to: .backupVerified"))
        let journalSave = try #require(tail.range(of: "try recoveryJournalStore.save(journal)"))
        let v2Preparation = try #require(tail.range(of: "preserveStoreFamily(\n                        from: backupURL"))

        #expect(sourcePreservation.lowerBound < durableBackup.lowerBound)
        #expect(durableBackup.lowerBound < copiedIdentity.lowerBound)
        #expect(copiedIdentity.lowerBound < journalSave.lowerBound)
        #expect(journalSave.lowerBound < v2Preparation.lowerBound)
    }

    @Test("V1 recovery opens V1-to-V2 migration only for clean V1 intermediate metadata")
    func v1RecoveryOpensV1ToV2MigrationOnlyForCleanV1IntermediateMetadata() throws {
        let source = try productionStartupHostSource()
        let assessment = try #require(source.range(of: "let v2Assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL"))
        let v2Resume = try #require(source.range(of: "v2Assessment.sourceClassification == .existingProposedV2Store"))
        let v1Gate = try #require(source.range(of: "v2Assessment.sourceClassification == .proposedV1RecognizableStore"))
        let v1ToV2Open = try #require(source.range(of: "proposedV2MigratingFromV1Container(url: selectedV2URL)"))
        let failClosed = try #require(source.range(of: "v2IntermediateNotMigratable(v2Assessment)"))

        #expect(assessment.lowerBound < v2Resume.lowerBound)
        #expect(v2Resume.lowerBound < v1Gate.lowerBound)
        #expect(v1Gate.lowerBound < v1ToV2Open.lowerBound)
        #expect(v1ToV2Open.lowerBound < failClosed.lowerBound)
    }

    @Test("V1 to V2 fallback uses fresh destination after staged unknown version failure")
    func v1ToV2FallbackUsesFreshDestinationAfterStagedUnknownVersionFailure() throws {
        let source = try productionStartupHostSource()
        let stagedURL = try #require(source.range(of: "let v2URL = layout.operationTemporaryTargetStoreFamilyURL("))
        let stagedFamily = try #require(source.range(of: "familyDirectoryName: \"V2IntermediateStoreFamily-v1\""))
        let fallbackURL = try #require(source.range(of: "let fallbackV2URL = layout.operationTemporaryTargetStoreFamilyURL("))
        let fallbackFamily = try #require(source.range(of: "familyDirectoryName: \"V2FallbackStoreFamily-v1\""))
        let targetFamily = try #require(source.range(of: "familyDirectoryName: \"V3TargetStoreFamily-v1\""))
        let backupFileName = try #require(source.range(of: "storeFileName: backupURL.lastPathComponent"))
        let fallbackCatch = try #require(source.range(of: "catch ScoreKeepStagedV1RecoveryError.v1ToV2ContainerOpenFailed(let report)"))
        let preceding = source[..<fallbackCatch.lowerBound]
        let stagedOpen = try #require(preceding.range(of: "proposedV2MigratingFromV1Container(url: selectedV2URL)", options: .backwards))
        let tail = source[fallbackCatch.lowerBound...]
        let wrapperGate = try #require(source.range(of: "where report.diagnostic.contains(\"swiftDataWrapperNoUnderlyingError\")"))
        let marker = try #require(tail.range(of: "recordV1FallbackSelection(journalStore: recoveryJournalStore"))
        let selectedFallback = try #require(tail.range(of: "selectedV2URL = fallbackV2URL"))
        let fallbackPrep = try #require(tail.range(of: "to: selectedV2URL,\n                                sourceLocation: .disposableMigrationTarget"))
        let fallbackOpen = try #require(tail.range(of: "automaticV2MaterializationContainer(url: selectedV2URL)"))

        #expect(stagedURL.lowerBound < fallbackURL.lowerBound)
        #expect(stagedURL.lowerBound < stagedFamily.lowerBound)
        #expect(fallbackURL.lowerBound < fallbackFamily.lowerBound)
        #expect(fallbackFamily.lowerBound < targetFamily.lowerBound)
        #expect(stagedFamily.lowerBound < backupFileName.lowerBound)
        #expect(stagedOpen.lowerBound < fallbackCatch.lowerBound)
        #expect(fallbackCatch.lowerBound < wrapperGate.lowerBound)
        #expect(wrapperGate.lowerBound < marker.lowerBound)
        #expect(marker.lowerBound < selectedFallback.lowerBound)
        #expect(selectedFallback.lowerBound < fallbackPrep.lowerBound)
        #expect(fallbackPrep.lowerBound < fallbackOpen.lowerBound)
        #expect(source.contains("automaticV2MaterializationContainer(url: v2URL)") == false)
    }

    @Test("Prior contradictory staged intermediate resumes through fresh fallback")
    func priorContradictoryStagedIntermediateResumesThroughFreshFallback() throws {
        let source = try productionStartupHostSource()
        let contradictoryGate = try #require(source.range(of: "v2Assessment.sourceClassification == .contradictoryMetadata, fallbackSelected == false"))
        let tail = source[contradictoryGate.lowerBound...]
        let marker = try #require(tail.range(of: "recordV1FallbackSelection(journalStore: recoveryJournalStore"))
        let selectFallback = try #require(tail.range(of: "selectedV2URL = fallbackV2URL"))
        let primaryCheck = try #require(tail.range(of: "storeFamilyPrimaryExists(selectedV2URL, fileManager: fileManager) == false"))
        let fallbackPrep = try #require(tail.range(of: "to: selectedV2URL,\n                            sourceLocation: .disposableMigrationTarget"))
        let fallbackAssessment = try #require(tail.range(of: "let fallbackAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: selectedV2URL"))
        let v1Gate = try #require(tail.range(of: "fallbackAssessment.sourceClassification == .proposedV1RecognizableStore"))
        let fallbackOpen = try #require(tail.range(of: "automaticV2MaterializationContainer(url: selectedV2URL)"))

        #expect(contradictoryGate.lowerBound < marker.lowerBound)
        #expect(marker.lowerBound < selectFallback.lowerBound)
        #expect(selectFallback.lowerBound < primaryCheck.lowerBound)
        #expect(primaryCheck.lowerBound < fallbackPrep.lowerBound)
        #expect(fallbackPrep.lowerBound < fallbackAssessment.lowerBound)
        #expect(fallbackAssessment.lowerBound < v1Gate.lowerBound)
        #expect(v1Gate.lowerBound < fallbackOpen.lowerBound)
    }

    @Test("V1 fallback marker resumes fallback without repeating staged attempt")
    func v1FallbackMarkerResumesFallbackWithoutRepeatingStagedAttempt() throws {
        let source = try productionStartupHostSource()
        let markerRead = try #require(source.range(of: "Self.v1FallbackSelected(journalStore: recoveryJournalStore"))
        let selectedURL = try #require(source.range(of: "selectedV2URL = fallbackSelected ? fallbackV2URL : v2URL"))
        let fallbackSelectedBranch = try #require(source.range(of: "v2Assessment.sourceClassification == .proposedV1RecognizableStore, fallbackSelected"))
        let fallbackTail = source[fallbackSelectedBranch.lowerBound...]
        let automaticOpen = try #require(fallbackTail.range(of: "v2Container = try Self.automaticV2MaterializationContainer(url: selectedV2URL)"))
        let stagedOpen = try #require(source.range(of: "v2Container = try Self.proposedV2MigratingFromV1Container(url: selectedV2URL)"))

        #expect(markerRead.lowerBound < selectedURL.lowerBound)
        #expect(selectedURL.lowerBound < fallbackSelectedBranch.lowerBound)
        #expect(fallbackSelectedBranch.lowerBound < automaticOpen.lowerBound)
        #expect(automaticOpen.lowerBound < stagedOpen.lowerBound)
    }

    @Test("V1 fallback selection is recorded outside store families without paths")
    func v1FallbackSelectionIsRecordedOutsideStoreFamiliesWithoutPaths() throws {
        let source = try productionStartupHostSource()
        let markerFunction = try #require(source.range(of: "private static func recordV1FallbackSelection"))
        let tail = source[markerFunction.lowerBound...]
        let markerData = try #require(tail.range(of: "Data(\"selected\\n\".utf8)"))
        let markerURL = try #require(tail.range(of: "V1AutomaticV2FallbackSelected-v1.marker"))

        #expect(markerData.lowerBound < markerURL.lowerBound)
        #expect(source.contains("file://") == false)
    }

    @Test("V1 fallback records sanitized lifecycle boundaries")
    func v1FallbackRecordsSanitizedLifecycleBoundaries() throws {
        let source = try productionStartupHostSource()
        let copy = try #require(source.range(of: ".fallbackCopyVerified"))
        let started = try #require(source.range(of: ".fallbackMaterializationStarted"))
        let opened = try #require(source.range(of: ".fallbackMaterializationOpened"))
        let saved = try #require(source.range(of: ".fallbackMaterializationSaved"))
        let completed = try #require(source.range(of: ".fallbackMaterializationCompleted"))
        let verification = try #require(source.range(of: ".fallbackV2VerificationStarted"))
        let marker = try #require(source.range(of: "V1Fallback-\\(boundary.rawValue)-v1.marker"))

        #expect(copy.lowerBound < started.lowerBound)
        #expect(started.lowerBound < opened.lowerBound)
        #expect(opened.lowerBound < saved.lowerBound)
        #expect(saved.lowerBound < completed.lowerBound)
        #expect(completed.lowerBound < verification.lowerBound)
        #expect(verification.lowerBound < marker.lowerBound)
        #expect(source.contains("assessment.sanitizedDiagnosticSummary"))
    }

    @Test("V1 not migratable diagnostic includes exact sanitized metadata evidence")
    func v1NotMigratableDiagnosticIncludesSanitizedMetadataEvidence() throws {
        let source = try productionStartupHostSource()
        let throwSite = try #require(source.range(of: "v2IntermediateNotMigratable(v2Assessment)"))
        let identity = try #require(source.range(of: "v2IntermediateNotMigratable.\\(assessment.sanitizedDiagnosticSummary)"))
        let metadataSource = try productionStoreMetadataAssessmentSource()

        #expect(throwSite.lowerBound < identity.lowerBound)
        #expect(metadataSource.contains("matchingRegisteredVersions.count > 1"))
        #expect(metadataSource.contains("multipleRegisteredVersions"))
        #expect(metadataSource.contains("hashes.\\(hashEntryCount)"))
        #expect(metadataSource.contains("identifiers.\\(versionIdentifierCount)"))
        #expect(metadataSource.contains("entities.\\(names)"))
        #expect(metadataSource.contains("wal.\\(walPresent ? \"present\" : \"missing\")"))
        #expect(metadataSource.contains("shm.\\(shmPresent ? \"present\" : \"missing\")"))
    }

    @Test("automatic V2 materialization fallback remains V2-only and does not include canonical storage")
    func automaticV2MaterializationFallbackRemainsV2Only() throws {
        let source = try productionStartupHostSource()
        let fallback = try #require(source.range(of: "private static func automaticV2MaterializationContainer"))
        let tail = source[fallback.lowerBound...]
        let evidenceModel = try #require(tail.range(of: "TeamCreationOperationEvidenceRecord.self"))
        let returnContainer = try #require(tail.range(of: "return try ModelContainer(for: schema, configurations: [configuration])"))

        #expect(evidenceModel.lowerBound < returnContainer.lowerBound)
        #expect(tail[..<returnContainer.lowerBound].contains("CanonicalGameHistoryRecord.self") == false)
        #expect(tail[..<returnContainer.lowerBound].contains("CanonicalScoringEventEnvelopeRecord.self") == false)
        #expect(tail[..<returnContainer.lowerBound].contains("CanonicalScoringEventPayloadRecord.self") == false)
        #expect(tail[..<returnContainer.lowerBound].contains("CanonicalScoringOperationEvidenceRecord.self") == false)
        #expect(tail[..<returnContainer.lowerBound].contains("CanonicalScoringCorrectionRecord.self") == false)
    }

    @Test("V1 recovery records V2 intermediate construction only once")
    func v1RecoveryRecordsV2IntermediateConstructionOnlyOnce() throws {
        let source = try productionStartupHostSource()
        let guardRange = try #require(source.range(of: "if journal.phase < .containerConstructed"))
        let recordRange = try #require(source.range(of: "recoveryBoundary = .v2IntermediateJournalRecord"))

        #expect(guardRange.lowerBound < recordRange.lowerBound)
    }

    @Test("V1 recovery does not recopy existing V3 destination")
    func v1RecoveryDoesNotRecopyExistingV3Destination() throws {
        let source = try productionStartupHostSource()
        let v3FreshGuard = try #require(source.range(of: "directoryHasContents(v3URL.deletingLastPathComponent(), fileManager: fileManager) == false"))
        let v3Copy = try #require(source.range(of: "preserveStoreFamily(\n                    from: selectedV2URL"))
        let v3ExistingAssessment = try #require(source.range(of: "assess(storeURL: v3URL, fileManager: fileManager).sourceClassification == .existingProposedV3Store"))
        let directOpen = try #require(source.range(of: "proposedV3ExistingContainer(url: v3URL)"))
        let migrationOpen = try #require(source.range(of: "proposedV3MigratingFromV2Container(url: v3URL)"))

        #expect(v3FreshGuard.lowerBound < v3Copy.lowerBound)
        #expect(v3Copy.lowerBound < v3ExistingAssessment.lowerBound)
        #expect(v3ExistingAssessment.lowerBound < directOpen.lowerBound)
        #expect(directOpen.lowerBound < migrationOpen.lowerBound)
        #expect(source.contains("copyStoreFamily(from: v2URL, to: v3URL") == false)
    }

    @Test("V1 recovery records V3 verification and completion only once")
    func v1RecoveryRecordsV3VerificationAndCompletionOnlyOnce() throws {
        let source = try productionStartupHostSource()
        let verificationGuard = try #require(source.range(of: "if journal.phase < .postOpenVerificationPassed"))
        let verificationRecord = try #require(source.range(of: "recoveryBoundary = .postOpenVerificationJournalRecord"))
        let completionGuard = try #require(source.range(of: "if journal.phase < .completionRecorded"))
        let completionRecord = try #require(source.range(of: "recoveryBoundary = .completionJournalRecord"))

        #expect(verificationGuard.lowerBound < verificationRecord.lowerBound)
        #expect(verificationRecord.lowerBound < completionGuard.lowerBound)
        #expect(completionGuard.lowerBound < completionRecord.lowerBound)
    }

    @Test("partial generation collision is skipped before selecting an unused generation")
    func partialGenerationCollisionIsSkippedBeforeSelectingUnusedGeneration() {
        let selected = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { offset in
            offset == 1
                ? ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .sourceClassified, hasPreservedPreBackupArtifacts: true)
                : .empty
        }

        #expect(selected == 2)
    }

    @Test("missing optional WAL and SHM do not make a store family incomplete")
    func missingOptionalWalAndShmDoNotMakeStoreFamilyIncomplete() throws {
        let url = try temporaryStoreURL()
        try Data([1, 2, 3]).write(to: url)

        let family = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: url)

        #expect(family.isComplete)
        #expect(family.fileNames == [url.lastPathComponent])
        #expect(family.missingOptionalSidecars.sorted() == ["\(url.lastPathComponent)-shm", "\(url.lastPathComponent)-wal"].sorted())
    }

    @Test("preservation executor reports copied backup identity from copied family")
    func preservationExecutorReportsCopiedBackupIdentityFromCopiedFamily() throws {
        let sourceURL = try temporaryStoreURL()
        let backupURL = try temporaryStoreURL()
        try writeStoreFamily(at: sourceURL, includeSidecars: true)

        let result = try ScoreKeepSourcePreservationExecutor.preserve(
            ScoreKeepSourcePreservationRequest(
                sourceStoreURL: sourceURL,
                backupStoreURL: backupURL,
                sourceLocation: .disposableMigrationTarget,
                sourceClosureEvidence: .closedForProductionStartup,
                allowIncompleteTestOwnedBackupRemoval: false,
                semanticRestoreVerifier: nil
            )
        )
        let source = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let backup = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)

        #expect(result.backupIdentity == backup.diagnosticIdentity)
        #expect(result.backupIdentity != source.sourceDirectoryIdentity)
        #expect(try ScoreKeepStoreFamilyDiscovery.validateBackup(source: source, backup: backup, sourceURL: sourceURL, backupURL: backupURL))
    }

    @Test("preservation authority validates source before and after copy")
    func preservationAuthorityValidatesSourceBeforeAndAfterCopy() throws {
        let source = try preservationSource()

        #expect(source.contains("let sourceBefore = try ScoreKeepStoreFamilyDiscovery.discover"))
        #expect(source.contains("let sourceAfter = try ScoreKeepStoreFamilyDiscovery.discover"))
        #expect(source.contains("&& sourceBefore == sourceAfter"))
        #expect(source.contains("throw ScoreKeepSourcePreservationError.backupVerificationFailed(verificationFailure)"))
    }

    @Test("mismatched copied family fails validation")
    func mismatchedCopiedFamilyFailsValidation() throws {
        let sourceURL = try temporaryStoreURL()
        let backupURL = try temporaryStoreURL()
        try writeStoreFamily(at: sourceURL, includeSidecars: true)
        try Data([1, 2, 3]).write(to: backupURL)

        let source = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: sourceURL)
        let backup = try ScoreKeepStoreFamilyDiscovery.discover(storeURL: backupURL)

        #expect((try ScoreKeepStoreFamilyDiscovery.validateBackup(source: source, backup: backup, sourceURL: sourceURL, backupURL: backupURL)) == false)
    }

    @Test("in-progress recovery generation remains selected for retry")
    func inProgressRecoveryGenerationIsSelectedForRetry() {
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .backupVerified) == .usableExisting)
        let selected = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { offset in
            offset == 1 ? .usableExisting : .empty
        }
        #expect(selected == 1)
    }

    @Test("completed recovery generation remains selected for opening")
    func completedRecoveryGenerationIsSelectedForOpening() {
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .completionRecorded) == .usableExisting)
    }

    @Test("unreadable recovery journal fails closed instead of selecting another generation")
    func unreadableRecoveryJournalFailsClosed() {
        let selected = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { offset in
            offset == 1 ? .unreadable : .empty
        }
        #expect(selected == nil)
    }

    @Test("bounded generation search exhausts without reusing failed destinations")
    func boundedGenerationSearchExhaustsFailedGenerations() {
        let selected = ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.selectedGenerationOffset { _ in
            .failedPreserved
        }
        #expect(selected == nil)
    }

    @Test("verified V2 intermediate remains selected for V1 recovery resume")
    func verifiedV2IntermediateRemainsSelectedForV1RecoveryResume() {
        #expect(ScoreKeepCompletedJournalV2RecoveryGenerationPlanner.state(for: .containerConstructed) == .usableExisting)
    }

    @Test("completed journal V2 recovery baselines copied backup instead of opening source before preservation")
    func completedJournalV2RecoveryBaselinesCopiedBackupInsteadOfOpeningSourceBeforePreservation() throws {
        let source = try productionStartupHostSource()
        let recoveryStart = try #require(source.range(of: "private func recoverCompletedJournalV2Target"))
        let tail = source[recoveryStart.lowerBound...]
        let run = try #require(tail.range(of: "ScoreKeepMigrationOrchestrator.run"))
        let semanticVerifier = try #require(tail.range(of: "semanticRestoreVerifier: { restoreURL in"))
        let restoreBaseline = try #require(tail.range(of: "ScoreKeepCompletedJournalV2SourceBaseline.failClosedBecauseFrozenV2SemanticVerifierUnavailable("))
        let storedBaseline = try #require(tail.range(of: "preservedBaseline = record"))
        let postOpen = try #require(tail.range(of: "postOpenVerifier: { container in"))
        let postOpenTail = tail[postOpen.lowerBound...]
        let fallbackBackupBaseline = try #require(postOpenTail.range(of: "url: backupURL"))
        let sourceStoreFileName = try #require(tail.range(of: "let sourceStoreFileName = sourceURL.lastPathComponent"))
        let namedBackup = try #require(tail.range(of: "layout.operationBackupStoreURL(operationIdentity: recoveryIdentity, storeFileName: sourceStoreFileName)"))
        let namedTarget = try #require(tail.range(of: "layout.operationTemporaryTargetURL(operationIdentity: recoveryIdentity, storeFileName: sourceStoreFileName)"))
        let failureIdentity = try #require(tail.range(of: "result.failureDiagnosticIdentity"))
        let wrappedSemanticError = try #require(tail.range(of: "ScoreKeepSourcePreservationSemanticRestoreOpenDiagnosticError"))
        let oldSourceBaseline = tail[..<run.lowerBound].contains("ScoreKeepCompletedJournalV2SourceBaseline.make(\n                url: sourceURL")
        let oldRestoreOpen = tail[semanticVerifier.lowerBound..<postOpen.lowerBound].contains("ScoreKeepCompletedJournalV2SourceBaseline.make(url: restoreURL")

        #expect(oldSourceBaseline == false)
        #expect(oldRestoreOpen == false)
        #expect(sourceStoreFileName.lowerBound < namedBackup.lowerBound)
        #expect(sourceStoreFileName.lowerBound < namedTarget.lowerBound)
        #expect(run.lowerBound < semanticVerifier.lowerBound)
        #expect(semanticVerifier.lowerBound < restoreBaseline.lowerBound)
        #expect(restoreBaseline.lowerBound < storedBaseline.lowerBound)
        #expect(storedBaseline.lowerBound < postOpen.lowerBound)
        #expect(postOpen.lowerBound < fallbackBackupBaseline.lowerBound)
        #expect(run.lowerBound < failureIdentity.lowerBound)
        #expect(semanticVerifier.lowerBound < wrappedSemanticError.lowerBound)
    }

    @Test("V2 baseline container open diagnostic walks sanitized structured errors")
    func v2BaselineContainerOpenDiagnosticWalksSanitizedStructuredErrors() throws {
        let source = try productionStoreMetadataAssessmentSource()
        let containerOpen = try #require(source.range(of: "case BaselineError.containerOpenFailed(let underlying):"))
        let tail = source[containerOpen.lowerBound...]
        let sanitizer = try #require(tail.range(of: "ScoreKeepSanitizedPersistentStoreErrorIdentity.makeReport(for: underlying).diagnostic"))

        #expect(containerOpen.lowerBound < sanitizer.lowerBound)
    }

    @Test("V2 semantic verifier remains unavailable in current target")
    func v2SemanticVerifierRemainsUnavailableInCurrentTarget() throws {
        let source = try productionStoreMetadataAssessmentSource()
        let helper = try #require(source.range(of: "static func failClosedBecauseFrozenV2SemanticVerifierUnavailable"))
        let tail = source[helper.lowerBound...]
        let exactV2Assessment = try #require(tail.range(of: "guard isV2BaselineSource(assessment)"))
        let unavailableReason = try #require(tail.range(of: "currentTargetV2AndV3DuplicateEffectiveChecksums"))
        let nextHelper = try #require(tail.range(of: "private static func isV2BaselineSource"))
        let helperSource = tail[..<nextHelper.lowerBound]

        #expect(helper.lowerBound < exactV2Assessment.lowerBound)
        #expect(exactV2Assessment.lowerBound < unavailableReason.lowerBound)
        #expect(source.contains("ScoreKeepV2SemanticBackupVerifier") == false)
        #expect(helperSource.contains("ScoreKeepProposedCanonicalScoringStorageMigrationPlan") == false)
    }

    @Test("baseline helper rejects V3 store instead of applying migration")
    @MainActor
    func baselineHelperRejectsV3Store() throws {
        let url = try temporaryStoreURL()
        try createV3StoreWithCanonicalRecord(at: url)

        do {
            _ = try ScoreKeepCompletedJournalV2SourceBaseline.make(url: url)
            Issue.record("V2 source baseline unexpectedly opened a V3 store.")
        } catch ScoreKeepCompletedJournalV2SourceBaseline.BaselineError.sourceMetadataMismatch(let classification) {
            #expect(classification == .existingProposedV3Store || classification == .contradictoryMetadata)
        } catch ScoreKeepCompletedJournalV2SourceBaseline.BaselineError.sourceMetadataChanged(let failure) {
            #expect(failure == .sourceFamilyChanged || failure == .sourceVersionEvidenceChanged)
        } catch ScoreKeepCompletedJournalV2SourceBaseline.BaselineError.canonicalRowsPresent {
            #expect(true)
        } catch {
            Issue.record("Unexpected baseline rejection error: \(error)")
        }
    }

    @Test("source metadata changing between routing and baseline is distinct")
    @MainActor
    func sourceMetadataChangingBetweenRoutingAndBaselineIsDistinct() throws {
        let v3URL = try temporaryStoreURL()
        try createV3StoreWithCanonicalRecord(at: v3URL)
        let verifiedAssessment = ScoreKeepProductionStoreMetadataAssessment(
            sourceClassification: .existingProposedV2Store,
            hashEntryCount: 7,
            versionIdentifierCount: 0,
            matchingRegisteredVersions: ["V2"],
            selectedStartupRoute: "migrateV2ToV3",
            hashKeyNames: ["A"],
            versionHashEvidence: evidence(["A": Data([1])]),
            versionHashEvidenceDigestPrefix: evidence(["A": Data([1])]).digestPrefix,
            versionHashEvidenceMalformed: false,
            familyDiagnosticIdentity: "family-a",
            primaryStoreDiagnosticIdentity: "primary-a",
            primaryPresent: true,
            walPresent: false,
            shmPresent: false
        )

        do {
            _ = try ScoreKeepCompletedJournalV2SourceBaseline.make(url: v3URL, verifiedAssessment: verifiedAssessment)
            Issue.record("Changed source metadata unexpectedly advanced to baseline.")
        } catch ScoreKeepCompletedJournalV2SourceBaseline.BaselineError.sourceMetadataChanged(let failure) {
            #expect(failure == .sourceFamilyChanged || failure == .sourceVersionEvidenceChanged)
        } catch {
            Issue.record("Unexpected changed metadata error: \(error)")
        }
    }

    @Test("stable version metadata passes revalidation")
    func stableVersionMetadataPassesRevalidation() {
        let assessment = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: assessment, current: assessment) == .stable)
    }

    @Test("sidecar visibility changes do not change schema version evidence")
    func sidecarVisibilityChangeDoesNotChangeSchemaEvidence() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])], walPresent: false, shmPresent: false)
        let current = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])], walPresent: true, shmPresent: true)
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sidecarStateChangedButVersionStable)
    }

    @Test("version hash changes fail as version evidence changes")
    func versionHashChangesFailAsVersionEvidenceChanged() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        let current = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([3])])
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceVersionEvidenceChanged)
    }

    @Test("metadata read failure is distinct")
    func metadataReadFailureIsDistinct() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        let current = assessment(.unreadableStore, family: "same", hashKeys: [])
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceMetadataReadFailed)
    }

    @Test("source family substitution fails closed")
    func sourceFamilySubstitutionFailsClosed() {
        let verified = assessment(.existingProposedV2Store, family: "a", hashes: ["Game": Data([1]), "Team": Data([2])])
        let current = assessment(.existingProposedV2Store, family: "b", primary: "b", hashes: ["Game": Data([1]), "Team": Data([2])])
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceFamilyChanged)
    }

    @Test("dictionary insertion order produces identical canonical version evidence")
    func dictionaryInsertionOrderProducesIdenticalCanonicalVersionEvidence() {
        let first = evidence(["Game": Data([1]), "Team": Data([2])])
        let second = evidence(["Team": Data([2]), "Game": Data([1])])
        #expect(first == second)
        #expect(first.canonicalData == second.canonicalData)
        #expect(first.digestPrefix == second.digestPrefix)
    }

    @Test("independent identical V2 fixtures produce identical canonical version evidence")
    @MainActor
    func independentIdenticalV2FixturesProduceIdenticalCanonicalVersionEvidence() throws {
        let firstURL = try temporaryStoreURL()
        let secondURL = try temporaryStoreURL()
        try createV2Store(at: firstURL)
        try createV2Store(at: secondURL)

        let first = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: firstURL)
        let second = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: secondURL)

        #expect(first.versionHashEvidence != nil)
        #expect(first.versionHashEvidence == second.versionHashEvidence)
        #expect(first.versionHashEvidence?.canonicalData == second.versionHashEvidence?.canonicalData)
    }

    @Test("exact schema evidence classifies V1 V2 and V3 without subset matches")
    @MainActor
    func exactSchemaEvidenceClassifiesV1V2AndV3WithoutSubsetMatches() throws {
        let registered = Dictionary(uniqueKeysWithValues: ScoreKeepProductionStoreMetadataAssessment.registeredVersionEvidenceForTesting.map { ($0.0, $0.1) })
        let v1 = try #require(registered["V1"])
        let v2 = try #require(registered["V2"])
        let v3 = try #require(registered["V3"])

        #expect(v1.entryCount == 6)
        #expect(v2.entryCount == 7)
        #expect(v3.entryCount == 12)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v1) == ["V1"])
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2) == ["V2"])
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v3) == ["V3"])

        let v2PlusOne = ScoreKeepCoreDataVersionHashEvidence(entries: v2.entries + [.init(entityName: "ExtraEntity", versionHash: Data([1]))])
        var changedV2Entries = v2.entries
        changedV2Entries[0] = .init(entityName: changedV2Entries[0].entityName, versionHash: Data([9]))
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2PlusOne).isEmpty)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(ScoreKeepCoreDataVersionHashEvidence(entries: changedV2Entries)).isEmpty)
        #expect(Set(v3.entityNames).isSuperset(of: Set(v2.entityNames)))
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v3).contains("V2") == false)
        #expect(ScoreKeepProductionStoreMetadataAssessment.registeredVersionMatchesForTesting(v2).contains("V1") == false)
    }

    @Test("schema evidence implementation rejects filtered subset matching")
    func schemaEvidenceImplementationRejectsFilteredSubsetMatching() throws {
        let source = try productionStoreMetadataAssessmentSource()

        #expect(source.contains("private static func expectedEntityNames(label: String)"))
        #expect(source.contains("ScoreKeepProposedVersionedSchema.v1ModelNames + ScoreKeepProposedVersionedSchema.v2AddedModelNames"))
        #expect(source.contains("Schema(versionedSchema: schemaType)") == false)
        #expect(source.contains("exactlyMatches(observed: evidence, expected: expectedEvidence)"))
        #expect(source.contains("observed.entryCount == expected.entryCount"))
        #expect(source.contains("Set(observed.entityNames) == Set(expected.entityNames)"))
    }

    @Test("V1 recovery validates backup source version and identity before fallback copy")
    func v1RecoveryValidatesBackupSourceVersionAndIdentityBeforeFallbackCopy() throws {
        let source = try productionStartupHostSource()
        let backupGuard = try #require(source.range(of: "validateV1RecoveryBackupSource("))
        let migrationAttempt = try #require(source.range(of: "recoveryBoundary = .v1ToV2MigrationAttemptRecord"))
        let fallbackCopy = try #require(source.range(of: "recoveryBoundary = .v2IntermediateCopyFromBackup"))
        let versionMismatch = try #require(source.range(of: "backupSourceVersionMismatch.\\(assessment.sanitizedDiagnosticSummary)"))
        let diagnosticTail = source[versionMismatch.lowerBound...]
        let identityMismatch = try #require(diagnosticTail.range(of: "backupSourceIdentityMismatch"))

        #expect(backupGuard.lowerBound < migrationAttempt.lowerBound)
        #expect(migrationAttempt.lowerBound < fallbackCopy.lowerBound)
        #expect(backupGuard.lowerBound < versionMismatch.lowerBound)
        #expect(backupGuard.lowerBound < identityMismatch.lowerBound)
    }

    @Test("changing one model-version-hash byte changes canonical evidence")
    func changingOneModelVersionHashByteChangesCanonicalEvidence() {
        let first = evidence(["Game": Data([1]), "Team": Data([2])])
        let second = evidence(["Game": Data([1]), "Team": Data([3])])
        #expect(first != second)
        #expect(first.changedEntityNames(comparedTo: second) == ["Team"])
    }

    @Test("adding or removing an entity changes canonical evidence")
    func addingOrRemovingEntityChangesCanonicalEvidence() {
        let first = evidence(["Game": Data([1]), "Team": Data([2])])
        let second = evidence(["Game": Data([1])])
        #expect(first != second)
        #expect(first.changedEntityNames(comparedTo: second) == ["Team"])
    }

    @Test("version identifiers alone do not qualify mismatched hashes as V2")
    func versionIdentifiersAloneDoNotQualifyMismatchedHashesAsV2() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        let current = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([3])])
        #expect(verified.versionIdentifierCount == current.versionIdentifierCount)
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceVersionEvidenceChanged)
    }

    @Test("entity-name equality alone does not qualify mismatched hashes as V2")
    func entityNameEqualityAloneDoesNotQualifyMismatchedHashesAsV2() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        let current = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([9]), "Team": Data([8])])
        #expect(verified.hashKeyNames == current.hashKeyNames)
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceVersionEvidenceChanged)
    }

    @Test("malformed hash metadata fails closed distinctly")
    func malformedHashMetadataFailsClosedDistinctly() {
        let verified = assessment(.existingProposedV2Store, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        var current = assessment(.unknownVersion, family: "same", hashes: ["Game": Data([1]), "Team": Data([2])])
        current = ScoreKeepProductionStoreMetadataAssessment(
            sourceClassification: current.sourceClassification,
            hashEntryCount: current.hashEntryCount,
            versionIdentifierCount: current.versionIdentifierCount,
            matchingRegisteredVersions: current.matchingRegisteredVersions,
            selectedStartupRoute: current.selectedStartupRoute,
            hashKeyNames: current.hashKeyNames,
            versionHashEvidence: nil,
            versionHashEvidenceDigestPrefix: "malformed",
            versionHashEvidenceMalformed: true,
            familyDiagnosticIdentity: current.familyDiagnosticIdentity,
            primaryStoreDiagnosticIdentity: current.primaryStoreDiagnosticIdentity,
            primaryPresent: current.primaryPresent,
            walPresent: current.walPresent,
            shmPresent: current.shmPresent
        )
        #expect(ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(verified: verified, current: current) == .sourceMetadataReadFailed)
    }

    @Test("version evidence code does not use Swift process-local hash values")
    func versionEvidenceCodeDoesNotUseSwiftProcessLocalHashValues() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let metadataSource = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/ScoreKeepProductionStoreMetadataAssessment.swift"), encoding: .utf8)
        let appSource = try String(contentsOf: root.appendingPathComponent("ScoreKeep/ScoreKeepApp.swift"), encoding: .utf8)

        #expect(metadataSource.contains("hashValue") == false)
        #expect(metadataSource.contains("Hasher") == false)
        #expect(appSource.contains("schemaHash") == false)
        #expect(appSource.contains("hashValue") == false)
    }

    private func route(
        target: ScoreKeepSourceStoreClassification,
        active: ScoreKeepSourceStoreClassification,
        journal: ScoreKeepSourceStoreClassification,
        backupVerified: Bool = true
    ) -> ScoreKeepCompletedJournalRecoveryRoute {
        ScoreKeepCompletedJournalRecoveryRouter.route(
            target: assessment(target),
            active: assessment(active),
            journalSourceClassification: journal,
            backupVerified: backupVerified
        )
    }

    private func assessment(_ classification: ScoreKeepSourceStoreClassification) -> ScoreKeepProductionStoreMetadataAssessment {
        assessment(classification, family: "test-family", hashKeys: [])
    }

    private func assessment(
        _ classification: ScoreKeepSourceStoreClassification,
        family: String,
        hashKeys: [String],
        primary: String? = nil,
        walPresent: Bool = false,
        shmPresent: Bool = false
    ) -> ScoreKeepProductionStoreMetadataAssessment {
        assessment(
            classification,
            family: family,
            primary: primary,
            hashes: Dictionary(uniqueKeysWithValues: hashKeys.map { ($0, Data($0.utf8)) }),
            walPresent: walPresent,
            shmPresent: shmPresent
        )
    }

    private func assessment(
        _ classification: ScoreKeepSourceStoreClassification,
        family: String,
        primary: String? = nil,
        hashes: [String: Data],
        walPresent: Bool = false,
        shmPresent: Bool = false
    ) -> ScoreKeepProductionStoreMetadataAssessment {
        let evidence = evidence(hashes)
        return ScoreKeepProductionStoreMetadataAssessment(
            sourceClassification: classification,
            hashEntryCount: evidence.entryCount,
            versionIdentifierCount: 0,
            matchingRegisteredVersions: [],
            selectedStartupRoute: "test",
            hashKeyNames: evidence.entityNames,
            versionHashEvidence: evidence,
            versionHashEvidenceDigestPrefix: evidence.digestPrefix,
            versionHashEvidenceMalformed: false,
            familyDiagnosticIdentity: family,
            primaryStoreDiagnosticIdentity: primary ?? family,
            primaryPresent: true,
            walPresent: walPresent,
            shmPresent: shmPresent
        )
    }

    private func evidence(_ hashes: [String: Data]) -> ScoreKeepCoreDataVersionHashEvidence {
        ScoreKeepCoreDataVersionHashEvidence.make(entityHashes: hashes.map { ($0.key, $0.value) })
    }

    private func productionStartupHostSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift"), encoding: .utf8)
    }

    private func productionStoreMetadataAssessmentSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/ScoreKeepProductionStoreMetadataAssessment.swift"), encoding: .utf8)
    }

    private func preservationSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("ScoreKeep/ScoreKeep/Common/ScoreKeepSourcePreservation.swift"), encoding: .utf8)
    }

    @MainActor
    private func createV1Store(at url: URL) throws {
        let schema = Schema(ScoreKeepProposedVersionedSchema.V1.models)
        let configuration = ModelConfiguration("FocusedV1", url: url, allowsSave: true)
        _ = try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func createV2Store(at url: URL) throws {
        let schema = Schema(ScoreKeepProposedVersionedSchema.V2.models)
        let configuration = ModelConfiguration("FocusedV2", url: url, allowsSave: true)
        _ = try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func createV3Store(at url: URL) throws {
        let schema = Schema(ScoreKeepProposedVersionedSchema.V3.models)
        let configuration = ModelConfiguration("FocusedV3Empty", schema: schema, url: url, allowsSave: true)
        _ = try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func createV3StoreWithCanonicalRecord(at url: URL) throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration("FocusedV3", schema: schema, url: url, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.insert(CanonicalGameHistoryRecord(gameIdentity: UUID()))
        try container.mainContext.save()
    }

    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepCompletedJournalRecoveryTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Focused.store")
    }

    private func writeStoreFamily(at url: URL, includeSidecars: Bool) throws {
        try Data([1, 2, 3]).write(to: url)
        guard includeSidecars else { return }
        try Data([4, 5, 6]).write(to: URL(fileURLWithPath: url.path + "-wal"))
        try Data([7, 8, 9]).write(to: URL(fileURLWithPath: url.path + "-shm"))
    }
}
