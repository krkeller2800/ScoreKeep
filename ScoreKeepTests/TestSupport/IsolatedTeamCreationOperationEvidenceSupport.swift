import Foundation
import Testing
@testable import ScoreKeep

actor IsolatedTeamCreationOperationEvidenceStore: CanonicalTeamCreationOperationEvidenceStore {
    private let fileURL: URL
    private var records: [CanonicalTeamCreationOperationIdentity: CanonicalTeamCreationOperationEvidence]

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([CanonicalTeamCreationOperationIdentity: CanonicalTeamCreationOperationEvidence].self, from: data)
        } else {
            records = [:]
            try Self.persist(records, to: fileURL)
        }
    }

    func evidence(for operationIdentity: CanonicalTeamCreationOperationIdentity) async -> CanonicalTeamCreationOperationEvidence? {
        records[operationIdentity]
    }

    func evidenceForTeam(_ teamIdentity: UUID) async -> [CanonicalTeamCreationOperationEvidence] {
        records.values.filter { $0.teamIdentity == teamIdentity }.sorted { $0.operationIdentity.rawValue < $1.operationIdentity.rawValue }
    }

    func begin(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict {
        if let existing = records[evidence.operationIdentity] {
            if existing.requestFingerprint != evidence.requestFingerprint { return .sameOperationDifferentRequest }
            switch existing.phase {
            case .inProgress, .saveAttempted:
                return .inProgress
            case .saveOutcomeUncertain, .failedWithUncertainCompletion, .reviewRequired:
                return .uncertainPriorCompletion
            default:
                return .none
            }
        }

        if records.values.contains(where: { $0.teamIdentity == evidence.teamIdentity && $0.requestFingerprint != evidence.requestFingerprint && $0.phase != .failedSafely }) {
            return .sameTeamDifferentMeaning
        }

        records[evidence.operationIdentity] = evidence
        try? persist()
        return .none
    }

    func advance(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        records[evidence.operationIdentity] = merge(existing: records[evidence.operationIdentity], replacement: evidence)
        try? persist()
    }

    func markCompletionProven(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        let completed = evidence.advanced(
            to: .completed,
            proof: .completionMarkerRecorded,
            retry: .retryUnnecessaryCompletionProven,
            reviewRequired: false,
            adding: .executorCompletionProven
        )
        records[evidence.operationIdentity] = completed
        try? persist()
    }

    func markCompletionUncertain(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        let uncertain = evidence.advanced(
            to: .failedWithUncertainCompletion,
            proof: .completionUncertain,
            retry: .retryProhibitedCompletionUncertain,
            reviewRequired: true,
            adding: .executorCompletionUncertain
        )
        records[evidence.operationIdentity] = uncertain
        try? persist()
    }

    func markSafeFailure(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        let failed = evidence.advanced(
            to: .failedSafely,
            proof: .noProof,
            retry: .retryPermittedSameOperationIdentity,
            reviewRequired: false,
            adding: .safeFailureRetryPermitted
        )
        records[evidence.operationIdentity] = failed
        try? persist()
    }

    func detectConflictingReuse(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict {
        if let existing = records[evidence.operationIdentity], existing.requestFingerprint != evidence.requestFingerprint {
            return .sameOperationDifferentRequest
        }
        if records.values.contains(where: { $0.teamIdentity == evidence.teamIdentity && $0.requestFingerprint != evidence.requestFingerprint }) {
            return .sameTeamDifferentMeaning
        }
        if records.values.contains(where: { $0.teamIdentity == evidence.teamIdentity && $0.phase == .failedWithUncertainCompletion }) {
            return .uncertainPriorCompletion
        }
        return .none
    }

    private func merge(
        existing: CanonicalTeamCreationOperationEvidence?,
        replacement: CanonicalTeamCreationOperationEvidence
    ) -> CanonicalTeamCreationOperationEvidence {
        guard let existing else { return replacement }
        var merged = replacement
        let codes = Set(existing.diagnosticCodes).union(replacement.diagnosticCodes)
        merged.diagnosticCodes = codes.sorted { $0.rawValue < $1.rawValue }
        return merged
    }

    private func persist() throws {
        try Self.persist(records, to: fileURL)
    }

    private static func persist(
        _ records: [CanonicalTeamCreationOperationIdentity: CanonicalTeamCreationOperationEvidence],
        to fileURL: URL
    ) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder.sorted.encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }
}

enum IsolatedTeamCreationOperationEvidenceSupport {
    static func storeDirectory(_ name: String = UUID().uuidString) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepTeamCreationEvidence", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func store(at directory: URL) throws -> IsolatedTeamCreationOperationEvidenceStore {
        try IsolatedTeamCreationOperationEvidenceStore(fileURL: directory.appendingPathComponent("operation-evidence.json"))
    }

    static func request(
        operationIdentity: String = "team-create-op-001",
        teamIdentity: UUID = TeamCreationTransactionVerificationIDs.createdTeam,
        teamName: String = "Isolated Falcons",
        coach: String = "Coach One",
        details: String = "Simple isolated team",
        source: CanonicalTeamCreationSourceClassification = .isolatedCandidateAdapter,
        options: [String: String] = [:]
    ) -> CanonicalTeamCreationOperationalRequest {
        CanonicalTeamCreationOperationalRequest(
            operationIdentity: CanonicalTeamCreationOperationIdentity(operationIdentity),
            teamIdentity: teamIdentity,
            teamName: teamName,
            coach: coach,
            details: details,
            source: source,
            options: options
        )
    }

    static func evidence(for request: CanonicalTeamCreationOperationalRequest) -> CanonicalTeamCreationOperationEvidence {
        CanonicalTeamCreationOperationEvidence(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            requestFingerprint: request.semanticFingerprint
        )
    }

    static func transactionResult(
        for request: CanonicalTeamCreationOperationalRequest,
        disposition: CanonicalPersistenceTransactionDisposition = .success,
        retrySafety: CanonicalPersistenceRetrySafety = .notNeeded,
        saveProven: Bool = true,
        uncertain: Bool = false,
        idempotency: CanonicalTeamCreationIdempotencyResult = .firstInvocation
    ) -> CanonicalTeamCreationTransactionResult {
        CanonicalTeamCreationTransactionResult(
            operationIdentity: request.operationIdentity.rawValue,
            teamIdentity: request.teamIdentity,
            transaction: CanonicalPersistenceTransactionResult(
                disposition: disposition,
                priorAcceptedStateRemainsUsable: !uncertain,
                retrySafety: retrySafety,
                explicitReloadRequired: uncertain,
                repairOrReviewRequired: uncertain || retrySafety == .unsafe,
                workflowMayContinue: disposition == .success || disposition == .duplicateAlreadyApplied,
                saveCompletionProven: saveProven,
                resultUncertainBecauseSaveCompletionCannotBeProven: uncertain
            ),
            validationFindings: [],
            saveResult: disposition == .partialOrUncertainOutcome ? .completionUncertain : (disposition == .saveFailed ? .failed : .succeeded),
            rollbackResult: disposition == .saveFailed && retrySafety == .safe ? .completed : .notRequired,
            reloadResult: disposition == .success || disposition == .duplicateAlreadyApplied ? .succeeded : .notRequired,
            semanticVerificationResult: disposition == .success || disposition == .duplicateAlreadyApplied ? .succeeded : .notAttempted,
            idempotencyResult: idempotency,
            affectedRecordIdentities: [request.teamIdentity.uuidString],
            priorAcceptedStateRemainsUsable: !uncertain,
            targetStateProven: disposition == .success || disposition == .duplicateAlreadyApplied,
            retryIsSafe: retrySafety == .safe,
            reviewRequired: uncertain || retrySafety == .unsafe,
            routingRemainsDisabled: true,
            purchaseAllowanceSeparationFindings: []
        )
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
