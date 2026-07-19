import Foundation
import SwiftData

enum ScoreKeepDestinationVerificationFailure: String, CaseIterable, Codable, Hashable, Sendable {
    case candidateUnreadable
    case metadataMismatch
    case countMismatch
    case identifierMismatch
    case relationshipMismatch
    case unexpectedCanonicalRecords
    case missingCanonicalModel
    case sourceOrBackupImmutabilityMismatch
    case journalInconsistency
    case unsupportedVerificationEvidence
    case interrupted
}

struct ScoreKeepDestinationVerificationEvidence: Codable, Hashable, Sendable {
    let evidenceFormatVersion: Int
    let operationIdentity: ScoreKeepMigrationOperationIdentity
    let candidateStoreFamilyIdentity: String
    let sourceStoreFamilyIdentity: String
    let backupStoreFamilyIdentity: String
    let verifiedV3MetadataDigest: String
    let observedRecordCounts: [String: Int]
    let expectedRecordCounts: [String: Int]
    let stableIdentityReconciled: Bool
    let relationshipReconciled: Bool
    let orderingReconciled: Bool
    let scoreReconciled: Bool
    let substitutionReconciled: Bool
    let mediaReconciled: Bool
    let teamCreationEvidenceReconciled: Bool
    let canonicalZeroResults: [String: String]
    let failure: ScoreKeepDestinationVerificationFailure?

    var journalSummary: String {
        let canonical = canonicalZeroResults
            .keys
            .sorted()
            .map { "\($0)=\(canonicalZeroResults[$0] ?? "missing")" }
            .joined(separator: "+")
        let failureValue = failure?.rawValue ?? "none"
        return [
            "task3.22D",
            "format.\(evidenceFormatVersion)",
            "candidate.\(candidateStoreFamilyIdentity)",
            "source.\(sourceStoreFamilyIdentity)",
            "backup.\(backupStoreFamilyIdentity)",
            "v3Digest.\(verifiedV3MetadataDigest)",
            "legacyCounts.\(observedRecordCounts.sortedDescription)",
            "canonical.\(canonical)",
            "identity.\(stableIdentityReconciled)",
            "relationships.\(relationshipReconciled)",
            "ordering.\(orderingReconciled)",
            "score.\(scoreReconciled)",
            "substitution.\(substitutionReconciled)",
            "media.\(mediaReconciled)",
            "teamOps.\(teamCreationEvidenceReconciled)",
            "failure.\(failureValue)"
        ].joined(separator: ".")
    }
}

struct ScoreKeepDestinationVerificationResult: Hashable, Sendable {
    let evidence: ScoreKeepDestinationVerificationEvidence

    var passed: Bool {
        evidence.failure == nil
    }

    var diagnosticCode: ScoreKeepMigrationJournalDiagnosticCode? {
        guard let failure = evidence.failure else { return nil }
        switch failure {
        case .candidateUnreadable:
            return .destinationCandidateUnreadable
        case .metadataMismatch:
            return .destinationMetadataMismatch
        case .countMismatch:
            return .destinationCountMismatch
        case .identifierMismatch:
            return .destinationIdentifierMismatch
        case .relationshipMismatch:
            return .destinationRelationshipMismatch
        case .unexpectedCanonicalRecords:
            return .destinationUnexpectedCanonicalRecords
        case .missingCanonicalModel:
            return .destinationMissingCanonicalModel
        case .sourceOrBackupImmutabilityMismatch:
            return .destinationSourceOrBackupChanged
        case .journalInconsistency:
            return .destinationJournalInconsistent
        case .unsupportedVerificationEvidence:
            return .destinationUnsupportedVerificationEvidence
        case .interrupted:
            return .destinationVerificationInterrupted
        }
    }
}

struct ScoreKeepDestinationVerificationInput: Hashable, Sendable {
    let operationIdentity: ScoreKeepMigrationOperationIdentity
    let candidateStoreURL: URL
    let sourceStoreURL: URL
    let backupStoreURL: URL
    let expectedSourceBaseline: ScoreKeepMigrationBaselineRecord?
    let expectedSourceFamilyIdentity: String?
    let expectedBackupFamilyIdentity: String?
    let candidateAssessmentOverride: ScoreKeepProductionStoreMetadataAssessment?
}

@MainActor
enum ScoreKeepDestinationVerifier {
    static func verify(
        container: ModelContainer,
        input: ScoreKeepDestinationVerificationInput,
        fileManager: FileManager = .default
    ) -> ScoreKeepDestinationVerificationResult {
        let sourceIdentity = familyIdentity(storeURL: input.sourceStoreURL, fileManager: fileManager)
        let backupIdentity = familyIdentity(storeURL: input.backupStoreURL, fileManager: fileManager)
        let candidateIdentity = familyIdentity(storeURL: input.candidateStoreURL, fileManager: fileManager)

        guard let expected = input.expectedSourceBaseline else {
            return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: nil, failure: .unsupportedVerificationEvidence)
        }
        guard input.expectedSourceFamilyIdentity.map({ $0 == sourceIdentity }) ?? true,
              input.expectedBackupFamilyIdentity.map({ $0 == backupIdentity }) ?? true else {
            return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: nil, expected: expected, failure: .sourceOrBackupImmutabilityMismatch)
        }

        let assessment = input.candidateAssessmentOverride ?? ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: input.candidateStoreURL, fileManager: fileManager)
        let expectedMetadata = expectedDestinationMetadata(for: input.operationIdentity.targetSchema)
        guard assessment.sourceClassification == expectedMetadata.classification,
              assessment.matchingRegisteredVersions == [expectedMetadata.label],
              assessment.hashEntryCount == expectedMetadata.modelCount,
              assessment.hashKeyNames == expectedMetadata.modelNames else {
            return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: nil, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .metadataMismatch)
        }

        do {
            let observed = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: container.mainContext)
            guard counts(observed) == counts(expected) else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .countMismatch)
            }
            guard hasUniqueStableIdentifiers(container.mainContext, targetSchema: input.operationIdentity.targetSchema) else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .identifierMismatch)
            }
            guard observed.stableIdentityFingerprint == expected.stableIdentityFingerprint else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .identifierMismatch)
            }
            guard observed.relationshipFingerprint == expected.relationshipFingerprint,
                  observed.orderingFingerprint == expected.orderingFingerprint,
                  try relationshipIntegrityPasses(container.mainContext) else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .relationshipMismatch)
            }
            guard observed.canonicalHistoryCount == 0,
                  observed.canonicalEventCount == 0,
                  observed.canonicalPayloadCount == 0,
                  observed.canonicalOperationCount == 0,
                  observed.canonicalCorrectionCount == 0 else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .unexpectedCanonicalRecords)
            }
            guard observed.legacyScoringOperationEvidenceCount == expected.legacyScoringOperationEvidenceCount else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .countMismatch)
            }
            guard observed.scoreEvidence == expected.scoreEvidence,
                  observed.substitutionEvidence == expected.substitutionEvidence,
                  observed.mediaOwnershipFingerprint == expected.mediaOwnershipFingerprint,
                  observed.teamCreationOperationEvidenceCount == expected.teamCreationOperationEvidenceCount else {
                return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .relationshipMismatch)
            }
            return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: observed, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: nil)
        } catch {
            return result(input: input, candidateIdentity: candidateIdentity, sourceIdentity: sourceIdentity, backupIdentity: backupIdentity, observed: nil, expected: expected, metadataDigest: assessment.versionHashEvidenceDigestPrefix, failure: .candidateUnreadable)
        }
    }

    private static func result(
        input: ScoreKeepDestinationVerificationInput,
        candidateIdentity: String,
        sourceIdentity: String,
        backupIdentity: String,
        observed: ScoreKeepMigrationBaselineRecord?,
        expected: ScoreKeepMigrationBaselineRecord? = nil,
        metadataDigest: String = "unverified",
        failure: ScoreKeepDestinationVerificationFailure?
    ) -> ScoreKeepDestinationVerificationResult {
        let expectedRecord = expected ?? input.expectedSourceBaseline
        return ScoreKeepDestinationVerificationResult(evidence: ScoreKeepDestinationVerificationEvidence(
            evidenceFormatVersion: 1,
            operationIdentity: input.operationIdentity,
            candidateStoreFamilyIdentity: candidateIdentity,
            sourceStoreFamilyIdentity: sourceIdentity,
            backupStoreFamilyIdentity: backupIdentity,
            verifiedV3MetadataDigest: metadataDigest,
            observedRecordCounts: observed.map(counts) ?? [:],
            expectedRecordCounts: expectedRecord.map(counts) ?? [:],
            stableIdentityReconciled: observed?.stableIdentityFingerprint == expectedRecord?.stableIdentityFingerprint,
            relationshipReconciled: observed?.relationshipFingerprint == expectedRecord?.relationshipFingerprint,
            orderingReconciled: observed?.orderingFingerprint == expectedRecord?.orderingFingerprint,
            scoreReconciled: observed?.scoreEvidence == expectedRecord?.scoreEvidence,
            substitutionReconciled: observed?.substitutionEvidence == expectedRecord?.substitutionEvidence,
            mediaReconciled: observed?.mediaOwnershipFingerprint == expectedRecord?.mediaOwnershipFingerprint,
            teamCreationEvidenceReconciled: observed?.teamCreationOperationEvidenceCount == expectedRecord?.teamCreationOperationEvidenceCount,
            canonicalZeroResults: canonicalZeroResults(observed),
            failure: failure
        ))
    }

    private static func counts(_ record: ScoreKeepMigrationBaselineRecord) -> [String: Int] {
        [
            "Game": record.gameCount,
            "Team": record.teamCount,
            "Player": record.playerCount,
            "Lineup": record.lineupCount,
            "Atbat": record.atbatCount,
            "Pitcher": record.pitcherCount,
            "TeamCreationOperationEvidenceRecord": record.teamCreationOperationEvidenceCount,
            "CanonicalGameHistoryRecord": record.canonicalHistoryCount,
            "CanonicalScoringEventEnvelopeRecord": record.canonicalEventCount,
            "CanonicalScoringEventPayloadRecord": record.canonicalPayloadCount,
            "CanonicalScoringOperationEvidenceRecord": record.canonicalOperationCount,
            "CanonicalScoringCorrectionRecord": record.canonicalCorrectionCount,
            "LegacyScoringOperationEvidenceRecord": record.legacyScoringOperationEvidenceCount
        ]
    }

    private static func canonicalZeroResults(_ record: ScoreKeepMigrationBaselineRecord?) -> [String: String] {
        guard let record else {
            return Dictionary(uniqueKeysWithValues: ScoreKeepDestinationV3Identity.canonicalModelNames.map { ($0, "unreadable") })
        }
        return [
            "CanonicalGameHistoryRecord": record.canonicalHistoryCount,
            "CanonicalScoringEventEnvelopeRecord": record.canonicalEventCount,
            "CanonicalScoringEventPayloadRecord": record.canonicalPayloadCount,
            "CanonicalScoringOperationEvidenceRecord": record.canonicalOperationCount,
            "CanonicalScoringCorrectionRecord": record.canonicalCorrectionCount
        ].mapValues { $0 == 0 ? "presentZero" : "unexpectedRecords.\($0)" }
    }

    private static func hasUniqueStableIdentifiers(_ context: ModelContext, targetSchema: ScoreKeepProposedSchemaSelection) -> Bool {
        do {
            var identifierGroups = try [
                context.fetch(FetchDescriptor<Game>()).map { $0.ident.uuidString },
                context.fetch(FetchDescriptor<Team>()).map { $0.ident.uuidString },
                context.fetch(FetchDescriptor<Player>()).map { $0.identifier.uuidString },
                context.fetch(FetchDescriptor<Lineup>()).map { $0.ident.uuidString },
                context.fetch(FetchDescriptor<Atbat>()).map { $0.ident.uuidString },
                context.fetch(FetchDescriptor<Pitcher>()).map { $0.ident.uuidString },
                context.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>()).map { $0.operationIdentity }
            ]
            if targetSchema == .proposedV4 {
                identifierGroups.append(try context.fetch(FetchDescriptor<LegacyScoringOperationEvidenceRecord>()).map { $0.operationIdentity.uuidString })
            }
            return identifierGroups.allSatisfy { Set($0).count == $0.count }
        } catch {
            return false
        }
    }

    private static func expectedDestinationMetadata(
        for schema: ScoreKeepProposedSchemaSelection
    ) -> (
        classification: ScoreKeepSourceStoreClassification,
        label: String,
        modelCount: Int,
        modelNames: [String]
    ) {
        switch schema {
        case .proposedV4:
            return (
                .existingProposedV4Store,
                "V4",
                ScoreKeepProposedVersionedSchema.V4.models.count,
                (ScoreKeepDestinationV3Identity.expectedModelNames + ScoreKeepProposedVersionedSchema.v4AddedModelNames).sorted()
            )
        case .proposedV3, .proposedV2:
            return (
                .existingProposedV3Store,
                "V3",
                ScoreKeepProposedVersionedSchema.V3.models.count,
                ScoreKeepDestinationV3Identity.expectedModelNames
            )
        }
    }

    private static func relationshipIntegrityPasses(_ context: ModelContext) throws -> Bool {
        let games = try context.fetch(FetchDescriptor<Game>())
        let teams = try context.fetch(FetchDescriptor<Team>())
        let players = try context.fetch(FetchDescriptor<Player>())
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let atbats = try context.fetch(FetchDescriptor<Atbat>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>())
        let gameIDs = Set(games.map(\.ident))
        let teamIDs = Set(teams.map(\.ident))
        let playerIDs = Set(players.map(\.identifier))

        guard games.allSatisfy({ game in
            (game.hteam.map { teamIDs.contains($0.ident) } ?? true)
                && (game.vteam.map { teamIDs.contains($0.ident) } ?? true)
                && game.players.allSatisfy { playerIDs.contains($0.identifier) }
                && game.replaced.allSatisfy { playerIDs.contains($0.identifier) }
                && game.incomings.allSatisfy { playerIDs.contains($0.identifier) }
        }) else { return false }
        guard players.allSatisfy({ $0.team.map { teamIDs.contains($0.ident) } ?? true }) else { return false }
        guard lineups.allSatisfy({ gameIDs.contains($0.game.ident) && teamIDs.contains($0.team.ident) && $0.players.allSatisfy { playerIDs.contains($0.identifier) } }) else { return false }
        guard atbats.allSatisfy({ gameIDs.contains($0.game.ident) && teamIDs.contains($0.team.ident) && playerIDs.contains($0.player.identifier) }) else { return false }
        guard pitchers.allSatisfy({ gameIDs.contains($0.game.ident) && teamIDs.contains($0.team.ident) && playerIDs.contains($0.player.identifier) }) else { return false }
        return true
    }

    private static func familyIdentity(storeURL: URL, fileManager: FileManager) -> String {
        (try? ScoreKeepStoreFamilyDiscovery.discover(storeURL: storeURL, fileManager: fileManager).diagnosticIdentity) ?? "family.unavailable"
    }
}

enum ScoreKeepDestinationV3Identity {
    static let legacyModelNames = ScoreKeepProposedVersionedSchema.v1ModelNames + ScoreKeepProposedVersionedSchema.v2AddedModelNames
    static let canonicalModelNames = ScoreKeepProposedVersionedSchema.v3AddedModelNames
    static let expectedModelNames = (legacyModelNames + canonicalModelNames).sorted()
    static let expectedVersionIdentifier = "3.0.0"
}

private extension Dictionary where Key == String, Value == Int {
    var sortedDescription: String {
        keys.sorted().map { "\($0)=\(self[$0] ?? 0)" }.joined(separator: "+")
    }
}
