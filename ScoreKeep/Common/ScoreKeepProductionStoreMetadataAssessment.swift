import CoreData
import CryptoKit
import Foundation
import SwiftData

struct ScoreKeepCoreDataVersionHashEvidence: Hashable, Sendable {
    struct Entry: Hashable, Sendable {
        let entityName: String
        let versionHash: Data
    }

    let entries: [Entry]

    var entryCount: Int {
        entries.count
    }

    var entityNames: [String] {
        entries.map(\.entityName)
    }

    var digestPrefix: String {
        let digest = SHA256.hash(data: canonicalData)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    var canonicalData: Data {
        var data = Data()
        for entry in entries {
            Self.append(entry.entityName, to: &data)
            Self.append(entry.versionHash, to: &data)
        }
        return data
    }

    func changedEntityNames(comparedTo other: ScoreKeepCoreDataVersionHashEvidence) -> [String] {
        let lhs = Dictionary(uniqueKeysWithValues: entries.map { ($0.entityName, $0.versionHash) })
        let rhs = Dictionary(uniqueKeysWithValues: other.entries.map { ($0.entityName, $0.versionHash) })
        return Array(Set(lhs.keys).union(rhs.keys))
            .filter { lhs[$0] != rhs[$0] }
            .sorted()
    }

    static func make(from hashes: [String: Any]) -> ScoreKeepCoreDataVersionHashEvidence? {
        var entries: [Entry] = []
        for key in hashes.keys.sorted() {
            guard let data = hashes[key] as? Data else {
                return nil
            }
            entries.append(Entry(entityName: key, versionHash: data))
        }
        return ScoreKeepCoreDataVersionHashEvidence(entries: entries)
    }

    static func make(entityHashes: [(String, Data)]) -> ScoreKeepCoreDataVersionHashEvidence {
        ScoreKeepCoreDataVersionHashEvidence(
            entries: entityHashes
                .map { Entry(entityName: $0.0, versionHash: $0.1) }
                .sorted { $0.entityName < $1.entityName }
        )
    }

    private static func append(_ value: String, to data: inout Data) {
        append(Data(value.utf8), to: &data)
    }

    private static func append(_ value: Data, to data: inout Data) {
        var count = UInt32(value.count).bigEndian
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        data.append(value)
    }
}

struct ScoreKeepProductionStoreMetadataAssessment: Hashable, Sendable {
    let sourceClassification: ScoreKeepSourceStoreClassification
    let hashEntryCount: Int
    let versionIdentifierCount: Int
    let matchingRegisteredVersions: [String]
    let selectedStartupRoute: String
    let hashKeyNames: [String]
    let versionHashEvidence: ScoreKeepCoreDataVersionHashEvidence?
    let versionHashEvidenceDigestPrefix: String
    let versionHashEvidenceMalformed: Bool
    let familyDiagnosticIdentity: String
    let primaryStoreDiagnosticIdentity: String
    let primaryPresent: Bool
    let walPresent: Bool
    let shmPresent: Bool

    var sanitizedDiagnosticSummary: String {
        let matches = matchingRegisteredVersions.isEmpty ? "none" : matchingRegisteredVersions.joined(separator: "+")
        let names = hashKeyNames.isEmpty ? "none" : hashKeyNames.joined(separator: "+")
        let conflict = metadataConflictSummary
        return [
            "classification.\(sourceClassification.rawValue)",
            "hashes.\(hashEntryCount)",
            "identifiers.\(versionIdentifierCount)",
            "matches.\(matches)",
            "digest.\(versionHashEvidenceDigestPrefix)",
            "entities.\(names)",
            "conflict.\(conflict)",
            "primary.\(primaryPresent ? "present" : "missing")",
            "wal.\(walPresent ? "present" : "missing")",
            "shm.\(shmPresent ? "present" : "missing")"
        ].joined(separator: ".")
    }

    private var metadataConflictSummary: String {
        if versionHashEvidenceMalformed {
            return "malformedVersionHashEvidence"
        }
        if matchingRegisteredVersions.count > 1 {
            return "multipleRegisteredVersions.\(matchingRegisteredVersions.joined(separator: "+"))"
        }
        guard let evidence = versionHashEvidence else {
            return "missingVersionHashEvidence"
        }
        let changed = Self.registeredVersionEvidence.map { label, expected in
            "\(label):\(evidence.changedEntityNames(comparedTo: expected).joined(separator: "+"))"
        }.joined(separator: "|")
        return changed.isEmpty ? "noRegisteredComparison" : "changed.\(changed)"
    }

    static func assess(storeURL: URL, fileManager: FileManager = .default) -> ScoreKeepProductionStoreMetadataAssessment {
        let family = try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: storeURL, fileManager: fileManager)
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return ScoreKeepProductionStoreMetadataAssessment(
                sourceClassification: .noStoreExists,
                hashEntryCount: 0,
                versionIdentifierCount: 0,
                matchingRegisteredVersions: [],
                selectedStartupRoute: "createCleanV3",
                hashKeyNames: [],
                versionHashEvidence: nil,
                versionHashEvidenceDigestPrefix: "none",
                versionHashEvidenceMalformed: false,
                familyDiagnosticIdentity: family?.diagnosticIdentity ?? "family.unavailable",
                primaryStoreDiagnosticIdentity: primaryStoreDiagnosticIdentity(for: family),
                primaryPresent: false,
                walPresent: family?.members.contains { $0.role == .wal } ?? false,
                shmPresent: family?.members.contains { $0.role == .shm } ?? false
            )
        }

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Any] ?? [:]
            let identifiers = (metadata[NSStoreModelVersionIdentifiersKey] as? [Any] ?? [])
                .map { String(describing: $0) }
                .sorted()
            let evidence = ScoreKeepCoreDataVersionHashEvidence.make(from: hashes)
            let evidenceMalformed = evidence == nil && hashes.isEmpty == false
            let hashKeyNames = evidence?.entityNames ?? hashes.keys.sorted()
            let matches = evidence.map { registeredVersionMatches(for: $0, versionIdentifiers: identifiers) } ?? []
            let classification = classification(for: matches, evidence: evidence, malformed: evidenceMalformed)
            return ScoreKeepProductionStoreMetadataAssessment(
                sourceClassification: classification,
                hashEntryCount: evidence?.entryCount ?? hashKeyNames.count,
                versionIdentifierCount: identifiers.count,
                matchingRegisteredVersions: matches,
                selectedStartupRoute: route(for: classification),
                hashKeyNames: hashKeyNames,
                versionHashEvidence: evidence,
                versionHashEvidenceDigestPrefix: evidence?.digestPrefix ?? (evidenceMalformed ? "malformed" : "none"),
                versionHashEvidenceMalformed: evidenceMalformed,
                familyDiagnosticIdentity: family?.diagnosticIdentity ?? "family.unavailable",
                primaryStoreDiagnosticIdentity: primaryStoreDiagnosticIdentity(for: family),
                primaryPresent: family?.missingPrimary == false,
                walPresent: family?.members.contains { $0.role == .wal } ?? false,
                shmPresent: family?.members.contains { $0.role == .shm } ?? false
            )
        } catch {
            return ScoreKeepProductionStoreMetadataAssessment(
                sourceClassification: .unreadableStore,
                hashEntryCount: 0,
                versionIdentifierCount: 0,
                matchingRegisteredVersions: [],
                selectedStartupRoute: "failClosedUnreadableMetadata",
                hashKeyNames: [],
                versionHashEvidence: nil,
                versionHashEvidenceDigestPrefix: "unreadable",
                versionHashEvidenceMalformed: true,
                familyDiagnosticIdentity: family?.diagnosticIdentity ?? "family.unavailable",
                primaryStoreDiagnosticIdentity: primaryStoreDiagnosticIdentity(for: family),
                primaryPresent: family?.missingPrimary == false,
                walPresent: family?.members.contains { $0.role == .wal } ?? false,
                shmPresent: family?.members.contains { $0.role == .shm } ?? false
            )
        }
    }

    private static func primaryStoreDiagnosticIdentity(for family: ScoreKeepStoreFamilyDescriptor?) -> String {
        guard let family,
              let primary = family.members.first(where: { $0.role == .primary }) else {
            return "primary.unavailable"
        }
        return [family.storeFileName, "\(primary.byteCount)", primary.fingerprint].joined(separator: "|")
    }

    private static func registeredVersionMatches(
        for evidence: ScoreKeepCoreDataVersionHashEvidence,
        versionIdentifiers: [String]? = nil
    ) -> [String] {
        registeredVersionEvidence.compactMap { label, expectedEvidence in
            guard exactlyMatches(observed: evidence, expected: expectedEvidence) else { return nil }
            if label == "V2", let versionIdentifiers {
                return versionIdentifiers == frozenV2VersionIdentifiers ? label : nil
            }
            return label
        }
    }

    private static func exactlyMatches(
        observed: ScoreKeepCoreDataVersionHashEvidence,
        expected: ScoreKeepCoreDataVersionHashEvidence
    ) -> Bool {
        observed.entryCount == expected.entryCount
            && Set(observed.entityNames) == Set(expected.entityNames)
            && observed == expected
    }

    static func registeredVersionMatchesForTesting(_ evidence: ScoreKeepCoreDataVersionHashEvidence) -> [String] {
        registeredVersionMatches(for: evidence)
    }

    static func registeredVersionMatchesForTesting(
        _ evidence: ScoreKeepCoreDataVersionHashEvidence,
        versionIdentifiers: [String]
    ) -> [String] {
        registeredVersionMatches(for: evidence, versionIdentifiers: versionIdentifiers)
    }

    static var registeredVersionEvidenceForTesting: [(String, ScoreKeepCoreDataVersionHashEvidence)] {
        registeredVersionEvidence
    }

    private static func classification(
        for matches: [String],
        evidence: ScoreKeepCoreDataVersionHashEvidence?,
        malformed: Bool
    ) -> ScoreKeepSourceStoreClassification {
        guard malformed == false else { return .unknownVersion }
        guard evidence != nil else { return .unknownVersion }
        guard matches.count <= 1 else { return .contradictoryMetadata }
        switch matches.first {
        case "V1":
            return .proposedV1RecognizableStore
        case "V2":
            return .existingProposedV2Store
        case "V3":
            return .existingProposedV3Store
        default:
            return .unknownVersion
        }
    }

    private static let registeredVersionEvidence: [(String, ScoreKeepCoreDataVersionHashEvidence)] = {
        let schemas: [(String, any VersionedSchema.Type)] = [
            ("V1", ScoreKeepProposedVersionedSchema.V1.self),
            ("V3", ScoreKeepProposedVersionedSchema.V3.self)
        ]
        var evidence: [(String, ScoreKeepCoreDataVersionHashEvidence)] = schemas.compactMap { label, schema in
            guard let evidence = expectedEvidence(for: schema, label: label) else { return nil }
            return (label, evidence)
        }
        evidence.append(("V2", frozenV2Evidence))
        return evidence.sorted { $0.0 < $1.0 }
    }()

    private static let frozenV2VersionIdentifiers = ["2.0.0"]

    private static let frozenV2Evidence = ScoreKeepCoreDataVersionHashEvidence.make(entityHashes: [
        ("Atbat", data(hex: "afc9dce8f1cf0398d9fbd611fe1c096179ca1057d7e31bc58a75eab71c2822c5")),
        ("Game", data(hex: "f5352b9e7cd9b12f45c972c481f1f82d3a78da932c6d626d52e66b0a21cf376c")),
        ("Lineup", data(hex: "c46059d17934e7733c89816dcf7406161f4192b95dfc1e2ba27683b7739bed34")),
        ("Pitcher", data(hex: "9fd67dc2eac273f0272fbc7a5fe1d1f2105cec4b1b5d147c69f704229a296247")),
        ("Player", data(hex: "99e2a334aa67b4cfdbf23952b49d166513c410dd000dac9c717601ab16c962d4")),
        ("Team", data(hex: "df7326e2246a984f4740b9dd7e39381d57ec3a7ae6894092ca76553778415cae")),
        ("TeamCreationOperationEvidenceRecord", data(hex: "b120193e905d792a95dabe0fbd2f772b58f1735779b354af0e44e3c78d4b9ec5"))
    ])

    private static func data(hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        return data
    }

    private static func expectedEvidence(
        for schemaType: any VersionedSchema.Type,
        label: String,
        fileManager: FileManager = .default
    ) -> ScoreKeepCoreDataVersionHashEvidence? {
        let expectedEntityNames = expectedEntityNames(label: label)
        guard let currentEvidence = currentSchemaEvidence(label: label, fileManager: fileManager) else {
            return nil
        }
        let entries = currentEvidence.entries.filter { expectedEntityNames.contains($0.entityName) }
        guard Set(entries.map(\.entityName)) == expectedEntityNames,
              entries.count == expectedEntityNames.count else {
            return nil
        }
        return ScoreKeepCoreDataVersionHashEvidence(entries: entries)
    }

    private static func expectedEntityNames(label: String) -> Set<String> {
        switch label {
        case "V1":
            return Set(ScoreKeepProposedVersionedSchema.v1ModelNames)
        case "V2":
            return Set(ScoreKeepProposedVersionedSchema.v1ModelNames + ScoreKeepProposedVersionedSchema.v2AddedModelNames)
        case "V3":
            return Set(
                ScoreKeepProposedVersionedSchema.v1ModelNames
                    + ScoreKeepProposedVersionedSchema.v2AddedModelNames
                    + ScoreKeepProposedVersionedSchema.v3AddedModelNames
            )
        default:
            return []
        }
    }

    private static func currentSchemaEvidence(
        label: String,
        fileManager: FileManager = .default
    ) -> ScoreKeepCoreDataVersionHashEvidence? {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ScoreKeepVersionEvidence-Current-\(label)-\(UUID().uuidString)", isDirectory: true)
        let url = root.appendingPathComponent("Evidence.sqlite")
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
            let configuration = ModelConfiguration("ScoreKeepVersionEvidence\(label)", url: url, allowsSave: true)
            _ = try ModelContainer(for: schema, configurations: [configuration])
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: nil
            )
            let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Any] ?? [:]
            let evidence = ScoreKeepCoreDataVersionHashEvidence.make(from: hashes)
            try? fileManager.removeItem(at: root)
            return evidence
        } catch {
            try? fileManager.removeItem(at: root)
            return nil
        }
    }

    private static func route(for classification: ScoreKeepSourceStoreClassification) -> String {
        switch classification {
        case .noStoreExists:
            return "createCleanV3"
        case .existingProposedV2Store, .convertedProposedV2Store:
            return "migrateV2ToV3"
        case .existingProposedV3Store, .convertedProposedV3Store:
            return "openExistingV3Direct"
        case .proposedV1RecognizableStore, .emptyCurrentUnversionedStore, .populatedCurrentUnversionedStore:
            return "failClosedEarlierGeneration"
        case .unknownVersion:
            return "failClosedUnknownMetadata"
        case .unreadableStore:
            return "failClosedUnreadableMetadata"
        case .contradictoryMetadata:
            return "failClosedContradictoryMetadata"
        case .automaticallyEvolvedComparisonStore, .unsupportedFutureVersion,
             .migrationEvidenceExists, .migrationEvidenceMissing, .migrationEvidenceUncertain,
             .readOnlyDiagnosisRequired:
            return "failClosedUnsupportedMetadata"
        }
    }
}

@MainActor
enum ScoreKeepCompletedJournalV2SourceBaseline {
    enum BaselineError: Error {
        case sourceMetadataMismatch(ScoreKeepSourceStoreClassification)
        case sourceMetadataChanged(ScoreKeepCompletedJournalV2SourceRevalidationFailure)
        case canonicalRowsPresent
        case containerOpenFailed(Error)
        case baselineQueryFailed(Error)
        case semanticVerifierUnavailable(String)
    }

    static func make(url: URL, fileManager: FileManager = .default) throws -> ScoreKeepMigrationBaselineRecord {
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: url, fileManager: fileManager)
        return try make(url: url, verifiedAssessment: assessment, fileManager: fileManager)
    }

    static func make(
        url: URL,
        verifiedAssessment: ScoreKeepProductionStoreMetadataAssessment,
        fileManager: FileManager = .default
    ) throws -> ScoreKeepMigrationBaselineRecord {
        let currentAssessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: url, fileManager: fileManager)
        let revalidation = ScoreKeepCompletedJournalV2SourceRevalidator.revalidate(
            verified: verifiedAssessment,
            current: currentAssessment
        )
        guard revalidation == .stable || revalidation == .sidecarStateChangedButVersionStable else {
            throw BaselineError.sourceMetadataChanged(revalidation)
        }
        return try make(url: url, assessment: verifiedAssessment)
    }

    private static func make(
        url _: URL,
        assessment: ScoreKeepProductionStoreMetadataAssessment
    ) throws -> ScoreKeepMigrationBaselineRecord {
        guard isV2BaselineSource(assessment) else {
            throw BaselineError.sourceMetadataMismatch(assessment.sourceClassification)
        }
        throw BaselineError.semanticVerifierUnavailable("currentTargetV2AndV3DuplicateEffectiveChecksums")
    }

    static func proposedV2Container(url _: URL) throws -> ModelContainer {
        throw BaselineError.semanticVerifierUnavailable("currentTargetV2AndV3DuplicateEffectiveChecksums")
    }

    static func failClosedBecauseFrozenV2SemanticVerifierUnavailable(url: URL, fileManager: FileManager = .default) throws -> ScoreKeepMigrationBaselineRecord {
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: url, fileManager: fileManager)
        guard isV2BaselineSource(assessment) else {
            throw BaselineError.sourceMetadataMismatch(assessment.sourceClassification)
        }
        throw BaselineError.semanticVerifierUnavailable("currentTargetV2AndV3DuplicateEffectiveChecksums")
    }

    private static func isV2BaselineSource(_ assessment: ScoreKeepProductionStoreMetadataAssessment) -> Bool {
        switch assessment.sourceClassification {
        case .existingProposedV2Store, .convertedProposedV2Store:
            return true
        default:
            return false
        }
    }

    static func sanitizedErrorIdentity(_ error: Error) -> String {
        switch error {
        case BaselineError.sourceMetadataMismatch(let classification):
            return "sourceMetadataMismatch.\(classification.rawValue)"
        case BaselineError.sourceMetadataChanged(let failure):
            return failure.rawValue
        case BaselineError.canonicalRowsPresent:
            return "canonicalRowsPresent"
        case BaselineError.containerOpenFailed(let underlying):
            return "containerOpenFailed.\(ScoreKeepSanitizedPersistentStoreErrorIdentity.makeReport(for: underlying).diagnostic)"
        case BaselineError.baselineQueryFailed(let underlying):
            return "baselineQueryFailed.\(sanitizedUnderlyingErrorIdentity(underlying))"
        case BaselineError.semanticVerifierUnavailable(let reason):
            return "semanticVerifierUnavailable.\(sanitizedDiagnosticToken(reason))"
        default:
            return "unknown.\(sanitizedUnderlyingErrorIdentity(error))"
        }
    }

    private static func sanitizedUnderlyingErrorIdentity(_ error: Error) -> String {
        let nsError = error as NSError
        let domain = nsError.domain
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "\(domain).\(nsError.code)"
    }

    private static func sanitizedDiagnosticToken(_ token: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._+-"))
        return String(token.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}

enum ScoreKeepCompletedJournalV2SourceRevalidationFailure: String, Hashable, Sendable {
    case stable
    case sourceFamilyChanged
    case sourceMetadataReadFailed
    case sourceVersionEvidenceChanged
    case sidecarStateChangedButVersionStable
}

enum ScoreKeepCompletedJournalV2SourceRevalidator {
    static func revalidate(
        verified: ScoreKeepProductionStoreMetadataAssessment,
        current: ScoreKeepProductionStoreMetadataAssessment
    ) -> ScoreKeepCompletedJournalV2SourceRevalidationFailure {
        guard verified.primaryStoreDiagnosticIdentity == current.primaryStoreDiagnosticIdentity else {
            return .sourceFamilyChanged
        }
        guard current.sourceClassification != .unreadableStore else {
            return .sourceMetadataReadFailed
        }
        guard verified.versionHashEvidenceMalformed == false,
              current.versionHashEvidenceMalformed == false,
              let verifiedEvidence = verified.versionHashEvidence,
              let currentEvidence = current.versionHashEvidence else {
            return .sourceMetadataReadFailed
        }
        guard verifiedEvidence == currentEvidence,
              verified.hashEntryCount == current.hashEntryCount,
              verified.hashKeyNames == current.hashKeyNames,
              verified.matchingRegisteredVersions == current.matchingRegisteredVersions,
              verified.versionIdentifierCount == current.versionIdentifierCount else {
            return .sourceVersionEvidenceChanged
        }
        if verified.primaryPresent != current.primaryPresent ||
            verified.walPresent != current.walPresent ||
            verified.shmPresent != current.shmPresent {
            return .sidecarStateChangedButVersionStable
        }
        return .stable
    }
}

enum ScoreKeepCompletedJournalRecoveryRoute: Hashable, Sendable {
    case openCompletedTargetAsV3
    case recoverCompletedTargetV2ToFreshV3
    case recoverActiveV1ToFreshV3
    case openActiveStoreAsV3
    case activeV2RequiresFreshPreparation
    case failClosed
}

enum ScoreKeepCompletedJournalRecoveryRouter {
    static func route(
        target: ScoreKeepProductionStoreMetadataAssessment,
        active: ScoreKeepProductionStoreMetadataAssessment,
        journalSourceClassification: ScoreKeepSourceStoreClassification,
        backupVerified: Bool
    ) -> ScoreKeepCompletedJournalRecoveryRoute {
        if target.sourceClassification == .existingProposedV3Store || target.sourceClassification == .convertedProposedV3Store {
            return .openCompletedTargetAsV3
        }
        if active.sourceClassification == .existingProposedV3Store || active.sourceClassification == .convertedProposedV3Store {
            return .openActiveStoreAsV3
        }
        if backupVerified,
           (target.sourceClassification == .existingProposedV2Store || target.sourceClassification == .convertedProposedV2Store),
           active.sourceClassification.requiresFailClosedActiveStoreFallback {
            return .recoverCompletedTargetV2ToFreshV3
        }
        if backupVerified,
           active.sourceClassification == .proposedV1RecognizableStore {
            return .recoverActiveV1ToFreshV3
        }
        if active.sourceClassification == .existingProposedV2Store || active.sourceClassification == .convertedProposedV2Store {
            return .activeV2RequiresFreshPreparation
        }
        return .failClosed
    }
}

enum ScoreKeepCompletedJournalV2RecoveryGenerationState: Hashable, Sendable {
    case empty
    case usableExisting
    case failedPreserved
    case unreadable
}

enum ScoreKeepCompletedJournalV2RecoveryGenerationPlanner {
    static let generationOffsetRange = 1...20

    static func selectedGenerationOffset(
        stateForGenerationOffset: (Int) -> ScoreKeepCompletedJournalV2RecoveryGenerationState
    ) -> Int? {
        for generationOffset in generationOffsetRange {
            switch stateForGenerationOffset(generationOffset) {
            case .empty, .usableExisting:
                return generationOffset
            case .failedPreserved:
                continue
            case .unreadable:
                return nil
            }
        }
        return nil
    }

    static func state(for phase: ScoreKeepMigrationJournalPhase?) -> ScoreKeepCompletedJournalV2RecoveryGenerationState {
        guard let phase else { return .empty }
        switch phase {
        case .recoveryRequired, .failedSafely, .completionUncertain, .disabled:
            return .failedPreserved
        case .completionRecorded:
            return .usableExisting
        case .noEvidence, .preflightStarted, .sourceClassified, .sourcePreservationStarted,
             .backupVerified, .workspaceCreationStarted, .workspaceVerified,
             .migrationAttemptStarted, .containerConstructed, .destinationVerificationPending,
             .postOpenVerificationStarted, .postOpenVerificationPassed:
            return .usableExisting
        }
    }

    static func state(
        for phase: ScoreKeepMigrationJournalPhase?,
        hasPreservedPreBackupArtifacts: Bool
    ) -> ScoreKeepCompletedJournalV2RecoveryGenerationState {
        if hasPreservedPreBackupArtifacts {
            switch phase {
            case nil, .noEvidence, .preflightStarted, .sourceClassified, .sourcePreservationStarted:
                return .failedPreserved
            case .backupVerified, .workspaceCreationStarted, .workspaceVerified,
                 .migrationAttemptStarted, .containerConstructed, .destinationVerificationPending,
                 .postOpenVerificationStarted, .postOpenVerificationPassed, .completionRecorded,
                 .recoveryRequired, .failedSafely, .completionUncertain, .disabled:
                break
            }
        }
        return state(for: phase)
    }
}

private extension ScoreKeepSourceStoreClassification {
    var requiresFailClosedActiveStoreFallback: Bool {
        switch self {
        case .unknownVersion, .unsupportedFutureVersion, .unreadableStore, .contradictoryMetadata,
             .migrationEvidenceExists, .migrationEvidenceMissing, .migrationEvidenceUncertain,
             .readOnlyDiagnosisRequired, .automaticallyEvolvedComparisonStore,
             .proposedV1RecognizableStore, .emptyCurrentUnversionedStore, .populatedCurrentUnversionedStore:
            return true
        case .noStoreExists, .existingProposedV2Store, .existingProposedV3Store,
             .convertedProposedV2Store, .convertedProposedV3Store:
            return false
        }
    }
}
