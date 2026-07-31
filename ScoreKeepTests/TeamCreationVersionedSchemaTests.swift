import CoreData
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation proposed versioned schema")
struct TeamCreationVersionedSchemaTests {
    @Test("proposed schemas describe current model set and add only operation evidence")
    func proposedSchemasDescribeCurrentModelSetAndAddOnlyOperationEvidence() {
        #expect(ScoreKeepProposedVersionedSchema.V1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.V2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.v1ModelNames == ["Game", "Team", "Player", "Atbat", "Lineup", "Pitcher"])
        #expect(ScoreKeepProposedVersionedSchema.v2AddedModelNames == ["TeamCreationOperationEvidenceRecord"])
        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV1RepresentsCurrentKnownModelSet)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV2AddsOnlyOperationEvidence)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV3AddsOnlyCanonicalScoringStorage)
        #expect(ScoreKeepProposedSchemaAssessment.current.productionContainerTargetsProposedV4)
    }

    @Test("direct V1 schema hash identity matches direct six model schema")
    func directV1SchemaHashIdentityMatchesDirectSixModelSchema() throws {
        let expectedModels: [any PersistentModel.Type] = [
            Game.self,
            Team.self,
            Player.self,
            Atbat.self,
            Lineup.self,
            Pitcher.self
        ]
        let v1Models = ScoreKeepProposedVersionedSchema.V1.models

        #expect(v1Models.map { String(reflecting: $0) } == expectedModels.map { String(reflecting: $0) })
        #expect(v1Models.map { ObjectIdentifier($0) } == expectedModels.map { ObjectIdentifier($0) })

        let directSixModelSchema = Schema(expectedModels)
        let directV1Schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V1.self)
        let directSixEvidence = try metadataEvidence(
            schema: directSixModelSchema,
            configurationName: "DirectSixModelSchemaHashIdentity",
            fileName: "DirectSix.sqlite"
        )
        let directV1Evidence = try metadataEvidence(
            schema: directV1Schema,
            configurationName: "DirectV1SchemaHashIdentity",
            fileName: "DirectV1.sqlite"
        )
        let registered = Dictionary(uniqueKeysWithValues: ScoreKeepProductionStoreMetadataAssessment.registeredVersionEvidenceForTesting.map { ($0.0, $0.1) })
        let registeredV1Evidence = try #require(registered["V1"])
        let directChangedNames = directSixEvidence.changedEntityNames(comparedTo: directV1Evidence)
        let registeredChangedNames = directV1Evidence.changedEntityNames(comparedTo: registeredV1Evidence)

        print("V1_MODEL_TYPES \(v1Models.map { String(reflecting: $0) }.joined(separator: ","))")
        print("DIRECT_SIX_HASHES \(hashSummary(directSixEvidence))")
        print("DIRECT_V1_HASHES \(hashSummary(directV1Evidence))")
        print("REGISTERED_V1_HASHES \(hashSummary(registeredV1Evidence))")
        print("DIRECT_CHANGED_NAMES \(directChangedNames.joined(separator: ","))")
        print("REGISTERED_CHANGED_NAMES \(registeredChangedNames.joined(separator: ","))")

        #expect(directChangedNames.isEmpty)
        #expect(directSixEvidence == directV1Evidence)
        #expect(registeredChangedNames.isEmpty)
        #expect(directV1Evidence == registeredV1Evidence)
    }

    @Test("writable V1 restore copy records first mutation stage")
    func writableV1RestoreCopyRecordsFirstMutationStage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepWritableV1RestoreStage-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = root.appendingPathComponent("source/ScoreKeep.sqlite")
        let restoreURL = root.appendingPathComponent("restore/ScoreKeep.sqlite")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: restoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try autoreleasepool {
            let sourceContainer = try v1Container(
                url: sourceURL,
                configurationName: "WritableV1RestoreStageSource",
                allowsSave: true
            )
            _ = try sourceContainer.mainContext.fetch(FetchDescriptor<Game>())
        }
        try copySQLiteFamily(from: sourceURL, to: restoreURL)

        var snapshots: [(String, SQLiteFamilySnapshot)] = []
        var container: ModelContainer?
        var context: ModelContext?
        var firstFailure: String?

        func capture(_ stage: String) throws {
            let snapshot = try sqliteFamilySnapshot(storeURL: restoreURL)
            snapshots.append((stage, snapshot))
            print("V1_STAGE_SNAPSHOT \(stage) \(snapshot.summary)")
            if snapshots.count > 1 {
                let prior = snapshots[snapshots.count - 2]
                print("V1_STAGE_CHANGE \(prior.0)_to_\(stage) \(snapshot.changeSummary(from: prior.1))")
            }
        }

        do {
            try capture("01_initialRestore")
            container = try v1Container(
                url: restoreURL,
                configurationName: "ScoreKeepProposedV1BackupSemanticVerification",
                allowsSave: false
            )
            try capture("02_afterContainer")
            context = container?.mainContext
            try capture("03_afterMainContext")
            _ = try context?.fetch(FetchDescriptor<Game>())
            try capture("04_afterFirstGameFetch")
            if let context {
                _ = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: context)
            }
            try capture("05_afterFullBaselineCapture")
        } catch {
            firstFailure = snapshots.last?.0 ?? "beforeInitialSnapshot"
            print("V1_STAGE_ERROR after=\(firstFailure ?? "unknown") error=\((error as NSError).domain).\((error as NSError).code)")
        }

        print("V1_FIRST_FAILURE \(firstFailure ?? "none")")
        print("V1_FIRST_MUTATION \(firstMutationStage(in: snapshots) ?? "none")")

        #expect(firstFailure == nil)
        #expect(snapshots.count == 5)
    }

    @Test("unversioned V1 hash compatible restore isolates allowsSave migration behavior")
    func unversionedV1HashCompatibleRestoreIsolatesAllowsSaveMigrationBehavior() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepUnversionedV1AllowsSaveProbe-\(UUID().uuidString)", isDirectory: true)
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal, name: root.lastPathComponent + "-source")
        let proposedV1Control = try IsolatedUnversionedProductionStoreSupport.createProposedV1SourceStore(.minimal, name: root.lastPathComponent + "-proposed-v1-control")
        let backupURL = root.appendingPathComponent("backup/ScoreKeep.store")
        let readOnlyConfigurationRestoreURL = root.appendingPathComponent("restore-allowsSave-false/ScoreKeep.store")
        let writableConfigurationRestoreURL = root.appendingPathComponent("restore-allowsSave-true/ScoreKeep.store")
        defer { try? FileManager.default.removeItem(at: root) }
        defer { try? FileManager.default.removeItem(at: source.url.deletingLastPathComponent()) }
        defer { try? FileManager.default.removeItem(at: proposedV1Control.url.deletingLastPathComponent()) }

        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: readOnlyConfigurationRestoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: writableConfigurationRestoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try copySQLiteFamily(from: source.url, to: backupURL)
        try copySQLiteFamily(from: backupURL, to: readOnlyConfigurationRestoreURL)
        try copySQLiteFamily(from: backupURL, to: writableConfigurationRestoreURL)

        let sourceBefore = try sqliteFamilySnapshot(storeURL: source.url)
        let backupBefore = try sqliteFamilySnapshot(storeURL: backupURL)
        let readOnlyRestoreBefore = try sqliteFamilySnapshot(storeURL: readOnlyConfigurationRestoreURL)
        let writableRestoreBefore = try sqliteFamilySnapshot(storeURL: writableConfigurationRestoreURL)
        let sourceMetadataBefore = try storeMetadataSummary(source.url)
        let readOnlyMetadataBefore = try storeMetadataSummary(readOnlyConfigurationRestoreURL)
        let writableMetadataBefore = try storeMetadataSummary(writableConfigurationRestoreURL)
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: source.url)
        let matchingVersions = assessment.matchingRegisteredVersions.joined(separator: "+")
        let proposedV1ControlMetadata = try storeMetadataSummary(proposedV1Control.url)

        print("V1_ALLOWS_SAVE_SOURCE_ASSESSMENT \(assessment.sourceClassification.rawValue) matches=\(matchingVersions)")
        print("V1_ALLOWS_SAVE_SOURCE_METADATA \(sourceMetadataBefore)")
        print("V1_ALLOWS_SAVE_SOURCE_METADATA_DEBUG \(try storeMetadataDebugSummary(source.url))")
        print("V1_ALLOWS_SAVE_PROPOSED_V1_CONTROL_METADATA \(proposedV1ControlMetadata)")
        print("V1_ALLOWS_SAVE_PROPOSED_V1_CONTROL_METADATA_DEBUG \(try storeMetadataDebugSummary(proposedV1Control.url))")
        print("V1_ALLOWS_SAVE_SOURCE_SQLITE_SCHEMA \(try sqliteSchemaSummary(source.url))")
        print("V1_ALLOWS_SAVE_PROPOSED_V1_CONTROL_SQLITE_SCHEMA \(try sqliteSchemaSummary(proposedV1Control.url))")
        print("V1_ALLOWS_SAVE_SQLITE_SCHEMA_DIFF \(try sqliteSchemaDiff(lhs: source.url, rhs: proposedV1Control.url))")
        print("V1_ALLOWS_SAVE_FALSE_BEFORE_METADATA \(readOnlyMetadataBefore)")
        print("V1_ALLOWS_SAVE_TRUE_BEFORE_METADATA \(writableMetadataBefore)")

        let readOnlyConfigurationOutcome: String
        let readOnlyFailureStage: String
        var readOnlyStage = "constructContainer"
        do {
            let container = try v1Container(
                url: readOnlyConfigurationRestoreURL,
                configurationName: "ScoreKeepProposedV1BackupSemanticVerificationAllowsSaveFalseProbe",
                allowsSave: false
            )
            readOnlyStage = "makeRecord"
            _ = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
            readOnlyConfigurationOutcome = "success"
            readOnlyFailureStage = "none"
        } catch {
            readOnlyConfigurationOutcome = sanitizedOutcome(error)
            readOnlyFailureStage = readOnlyStage
        }

        let writableConfigurationRecord: ScoreKeepMigrationBaselineRecord
        var writableStageSnapshots: [(String, SQLiteFamilySnapshot, String)] = []
        func captureWritableStage(_ stage: String) throws {
            writableStageSnapshots.append((
                stage,
                try sqliteFamilySnapshot(storeURL: writableConfigurationRestoreURL),
                try storeMetadataSummary(writableConfigurationRestoreURL)
            ))
        }
        do {
            try captureWritableStage("01_beforeContainer")
            let container = try v1Container(
                url: writableConfigurationRestoreURL,
                configurationName: "ScoreKeepProposedV1BackupSemanticVerificationAllowsSaveTrueProbe",
                allowsSave: true
            )
            try captureWritableStage("02_afterContainer")
            let context = container.mainContext
            try captureWritableStage("03_afterMainContext")
            _ = try context.fetch(FetchDescriptor<Game>())
            _ = try context.fetch(FetchDescriptor<Team>())
            _ = try context.fetch(FetchDescriptor<Player>())
            _ = try context.fetch(FetchDescriptor<Atbat>())
            _ = try context.fetch(FetchDescriptor<Lineup>())
            _ = try context.fetch(FetchDescriptor<Pitcher>())
            try captureWritableStage("04_afterSixEntityFetch")
            writableConfigurationRecord = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: context)
            try captureWritableStage("05_afterFullBaselineCapture")
        }

        let sourceAfter = try sqliteFamilySnapshot(storeURL: source.url)
        let backupAfter = try sqliteFamilySnapshot(storeURL: backupURL)
        let readOnlyRestoreAfter = try sqliteFamilySnapshot(storeURL: readOnlyConfigurationRestoreURL)
        let writableRestoreAfter = try sqliteFamilySnapshot(storeURL: writableConfigurationRestoreURL)
        let readOnlyMetadataAfter = try storeMetadataSummary(readOnlyConfigurationRestoreURL)
        let writableMetadataAfter = try storeMetadataSummary(writableConfigurationRestoreURL)

        print("V1_ALLOWS_SAVE_FALSE_OUTCOME \(readOnlyConfigurationOutcome)")
        print("V1_ALLOWS_SAVE_FALSE_FAILURE_STAGE \(readOnlyFailureStage)")
        print("V1_ALLOWS_SAVE_TRUE_OUTCOME success")
        print("V1_ALLOWS_SAVE_FALSE_CHANGE \(readOnlyRestoreAfter.changeSummary(from: readOnlyRestoreBefore))")
        print("V1_ALLOWS_SAVE_TRUE_CHANGE \(writableRestoreAfter.changeSummary(from: writableRestoreBefore))")
        for index in 1..<writableStageSnapshots.count {
            let prior = writableStageSnapshots[index - 1]
            let current = writableStageSnapshots[index]
            print("V1_ALLOWS_SAVE_TRUE_STAGE_CHANGE \(prior.0)_to_\(current.0) \(current.1.changeSummary(from: prior.1))")
            print("V1_ALLOWS_SAVE_TRUE_STAGE_METADATA \(current.0) \(current.2)")
        }
        print("V1_ALLOWS_SAVE_FALSE_AFTER_METADATA \(readOnlyMetadataAfter)")
        print("V1_ALLOWS_SAVE_TRUE_AFTER_METADATA \(writableMetadataAfter)")
        print("V1_ALLOWS_SAVE_SOURCE_CHANGE \(sourceAfter.changeSummary(from: sourceBefore))")
        print("V1_ALLOWS_SAVE_BACKUP_CHANGE \(backupAfter.changeSummary(from: backupBefore))")

        #expect(assessment.sourceClassification == .proposedV1RecognizableStore)
        #expect(assessment.matchingRegisteredVersions == ["V1"])
        #expect(sourceMetadataBefore == proposedV1ControlMetadata)
        #expect(readOnlyMetadataBefore == sourceMetadataBefore)
        #expect(writableMetadataBefore == sourceMetadataBefore)
        #expect(readOnlyConfigurationOutcome.contains("failure"))
        #expect(writableStageSnapshots.count == 5)
        #expect(writableConfigurationRecord.matchesRecordCounts(source.snapshot.counts))
        #expect(sourceAfter == sourceBefore)
        #expect(backupAfter == backupBefore)
    }

    @Test("operation evidence model stores only scalar operation metadata")
    func operationEvidenceModelStoresOnlyScalarOperationMetadata() {
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("operationIdentity"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("targetTeamIdentity"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("requestFingerprint"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("phase"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("completionProof"))
        #expect(TeamCreationOperationEvidenceModelBoundary.storedFields.contains("retryClassification"))
        #expect(TeamCreationOperationEvidenceModelBoundary.hasTeamRelationship == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.hasPurchaseOrAllowanceFields == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.hasMediaFields == false)
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("teamName"))
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("receipts"))
        #expect(TeamCreationOperationEvidenceModelBoundary.excludedFields.contains("logo"))
    }

    @Test("production startup is hosted and bounded activation is enabled")
    func productionStartupIsHostedAndBoundedActivationIsEnabled() throws {
        let source = try repositorySource("ScoreKeep/ScoreKeepApp.swift")
        let startup = try repositorySource("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift")

        #expect(source.contains("ScoreKeepProductionStartupHost"))
        #expect(source.contains("ScoreKeepProposedVersionedSchema") == false)
        #expect(source.contains("ScoreKeepProposedTeamCreationEvidenceMigrationPlan") == false)
        #expect(source.contains("TeamCreationOperationEvidenceRecord") == false)
        #expect(source.contains("TeamCreationSwiftDataEvidenceStore") == false)
        #expect(startup.contains("simpleTeamCreationProductionEnabled = true"))
        #expect(startup.contains("runProductionMigration"))
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        try StableIdentityAndOrderingTestSupport.repositorySource(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }

    private func metadataEvidence(
        schema: Schema,
        configurationName: String,
        fileName: String
    ) throws -> ScoreKeepCoreDataVersionHashEvidence {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepV1RuntimeHashIdentity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(fileName)
        defer { try? FileManager.default.removeItem(at: root) }

        let configuration = ModelConfiguration(configurationName, schema: schema, url: url, allowsSave: true)
        _ = try ModelContainer(for: schema, configurations: [configuration])
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url
        )
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Any])
        return try #require(ScoreKeepCoreDataVersionHashEvidence.make(from: hashes))
    }

    private func hashSummary(_ evidence: ScoreKeepCoreDataVersionHashEvidence) -> String {
        evidence.entries
            .map { "\($0.entityName)=\(hex($0.versionHash))" }
            .joined(separator: ",")
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func storeMetadataSummary(_ url: URL) throws -> String {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url
        )
        let identifiers = (metadata[NSStoreModelVersionIdentifiersKey] as? [Any] ?? [])
            .map { String(describing: $0) }
            .sorted()
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Any])
        let evidence = try #require(ScoreKeepCoreDataVersionHashEvidence.make(from: hashes))
        return [
            "identifiers=[\(identifiers.joined(separator: ","))]",
            "hashDigest=\(evidence.digestPrefix)",
            "entities=\(evidence.entityNames.joined(separator: ","))"
        ].joined(separator: ";")
    }

    private func storeMetadataDebugSummary(_ url: URL) throws -> String {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url
        )
        return metadata.keys.map { key in
            let name = String(describing: key)
            if name == NSStoreModelVersionHashesKey {
                return "\(name)=<hashes>"
            }
            return "\(name)=\(sanitize(String(describing: metadata[key] ?? "nil")))"
        }
        .sorted()
        .joined(separator: ";")
    }

    private func sqliteSchemaSummary(_ url: URL) throws -> String {
        let entries = try sqliteSchemaEntries(url)
        let digest = ScoreKeepStoreFamilyDiscovery.digest(Data(entries.joined(separator: "\n").utf8))
        let names = entries.map { entry in
            entry.components(separatedBy: "|").prefix(2).joined(separator: ":")
        }
        return "digest=\(digest);entries=\(entries.count);names=\(names.joined(separator: ","))"
    }

    private func sqliteSchemaDiff(lhs: URL, rhs: URL) throws -> String {
        let lhsEntries = Set(try sqliteSchemaEntries(lhs))
        let rhsEntries = Set(try sqliteSchemaEntries(rhs))
        let onlyLHS = lhsEntries.subtracting(rhsEntries).sorted()
        let onlyRHS = rhsEntries.subtracting(lhsEntries).sorted()
        return [
            "onlyUnversioned=\(onlyLHS.map(sqliteSchemaEntryName).joined(separator: ","))",
            "onlyProposedV1=\(onlyRHS.map(sqliteSchemaEntryName).joined(separator: ","))"
        ].joined(separator: ";")
    }

    private func sqliteSchemaEntries(_ url: URL) throws -> [String] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            throw NSError(domain: "ScoreKeepSQLiteSchemaProbe", code: 1)
        }
        defer { sqlite3_close(database) }

        let sql = "SELECT type, name, tbl_name, COALESCE(sql, '') FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw NSError(domain: "ScoreKeepSQLiteSchemaProbe", code: 2)
        }
        defer { sqlite3_finalize(statement) }

        var entries: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let values = (0..<4).map { index in
                sqlite3_column_text(statement, Int32(index)).map { String(cString: $0) } ?? ""
            }
            entries.append(values.joined(separator: "|"))
        }
        return entries
    }

    private func sqliteSchemaEntryName(_ entry: String) -> String {
        entry.components(separatedBy: "|").prefix(2).joined(separator: ":")
    }

    private func sanitizedOutcome(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [
            "failure",
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

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._+-,=:;[]() "))
        return String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }.prefix(240))
    }

    private func v1Container(url: URL, configurationName: String, allowsSave: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V1.self)
        let configuration = ModelConfiguration(
            configurationName,
            schema: schema,
            url: url,
            allowsSave: allowsSave
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func copySQLiteFamily(from sourceURL: URL, to destinationURL: URL) throws {
        let sourceDirectory = sourceURL.deletingLastPathComponent()
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        let sourceNames = try FileManager.default.contentsOfDirectory(atPath: sourceDirectory.path)
            .filter { $0 == sourceURL.lastPathComponent || $0.hasPrefix(sourceURL.lastPathComponent + "-") }
        for sourceName in sourceNames {
            try FileManager.default.copyItem(
                at: sourceDirectory.appendingPathComponent(sourceName),
                to: destinationDirectory.appendingPathComponent(sourceName)
            )
        }
    }

    private func sqliteFamilySnapshot(storeURL: URL) throws -> SQLiteFamilySnapshot {
        let names = [
            storeURL.lastPathComponent,
            "\(storeURL.lastPathComponent)-wal",
            "\(storeURL.lastPathComponent)-shm"
        ]
        let directory = storeURL.deletingLastPathComponent()
        let members = try names.map { name in
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return SQLiteFamilySnapshot.Member(name: name, exists: false, byteCount: 0, fingerprint: "absent")
            }
            let data = try Data(contentsOf: url)
            return SQLiteFamilySnapshot.Member(
                name: name,
                exists: true,
                byteCount: UInt64(data.count),
                fingerprint: ScoreKeepStoreFamilyDiscovery.digest(data)
            )
        }
        return SQLiteFamilySnapshot(members: members)
    }

    private func firstMutationStage(in snapshots: [(String, SQLiteFamilySnapshot)]) -> String? {
        guard snapshots.count > 1 else { return nil }
        for index in 1..<snapshots.count where snapshots[index].1 != snapshots[index - 1].1 {
            return "\(snapshots[index - 1].0)_to_\(snapshots[index].0)"
        }
        return nil
    }
}

enum TeamCreationVersionedSchemaTestError: Error {
    case repositoryRootNotFound
}

private struct SQLiteFamilySnapshot: Equatable {
    struct Member: Equatable {
        let name: String
        let exists: Bool
        let byteCount: UInt64
        let fingerprint: String
    }

    let members: [Member]

    var summary: String {
        members.map { member in
            "\(member.name):exists=\(member.exists);bytes=\(member.byteCount);fingerprint=\(member.fingerprint)"
        }.joined(separator: "|")
    }

    func changeSummary(from prior: SQLiteFamilySnapshot) -> String {
        let previous = Dictionary(uniqueKeysWithValues: prior.members.map { ($0.name, $0) })
        let current = Dictionary(uniqueKeysWithValues: members.map { ($0.name, $0) })
        let changes = Set(previous.keys).union(current.keys).sorted().compactMap { name -> String? in
            let before = previous[name]
            let after = current[name]
            guard before != after else { return nil }
            return "\(name):\(memberChange(before: before, after: after))"
        }
        return changes.isEmpty ? "none" : changes.joined(separator: ",")
    }

    private func memberChange(before: Member?, after: Member?) -> String {
        switch (before, after) {
        case (.none, .some):
            return "created"
        case (.some, .none):
            return "removed"
        case (.some(let before), .some(let after)) where before.exists == false && after.exists:
            return "created"
        case (.some(let before), .some(let after)) where before.exists && after.exists == false:
            return "removed"
        case (.some(let before), .some(let after)) where before.byteCount != after.byteCount:
            return "resized:\(before.byteCount)->\(after.byteCount)"
        case (.some(let before), .some(let after)) where before.fingerprint != after.fingerprint:
            return "modified"
        default:
            return "changed"
        }
    }
}
