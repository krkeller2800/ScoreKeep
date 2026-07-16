import Foundation
import SwiftData

@MainActor
final class TeamCreationSwiftDataEvidenceStore: CanonicalTeamCreationOperationEvidenceStore, @unchecked Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func evidence(for operationIdentity: CanonicalTeamCreationOperationIdentity) async -> CanonicalTeamCreationOperationEvidence? {
        do {
            let context = makeContext()
            return try fetchRecord(operationIdentity: operationIdentity.rawValue, in: context).map(Self.canonicalEvidence(from:))
        } catch {
            return nil
        }
    }

    func evidenceForTeam(_ teamIdentity: UUID) async -> [CanonicalTeamCreationOperationEvidence] {
        do {
            let context = makeContext()
            let descriptor = FetchDescriptor<TeamCreationOperationEvidenceRecord>(
                predicate: #Predicate { $0.targetTeamIdentity == teamIdentity }
            )
            return try context.fetch(descriptor).map(Self.canonicalEvidence(from:))
        } catch {
            return []
        }
    }

    func begin(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict {
        do {
            let context = makeContext()
            if let existingRecord = try fetchRecord(operationIdentity: evidence.operationIdentity.rawValue, in: context) {
                let existing = Self.canonicalEvidence(from: existingRecord)
                if existing.requestFingerprint != evidence.requestFingerprint { return .sameOperationDifferentRequest }
                if existing.phase == .failedWithUncertainCompletion || existing.phase == .saveOutcomeUncertain { return .uncertainPriorCompletion }
                if existing.phase == .inProgress || existing.phase == .saveAttempted { return .inProgress }
                if existing.phase == .failedSafely {
                    apply(evidence.advanced(to: .prepared), to: existingRecord)
                    try context.save()
                }
                return .none
            }

            let teamDescriptor = FetchDescriptor<TeamCreationOperationEvidenceRecord>(
                predicate: #Predicate { $0.targetTeamIdentity == evidence.teamIdentity }
            )
            let teamEvidence = try context.fetch(teamDescriptor).map(Self.canonicalEvidence(from:))
            if teamEvidence.contains(where: { $0.requestFingerprint != evidence.requestFingerprint && $0.phase != .failedSafely }) {
                return .sameTeamDifferentMeaning
            }

            context.insert(Self.record(from: evidence))
            try context.save()
            return .none
        } catch {
            return .inProgress
        }
    }

    func advance(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        await persist(evidence)
    }

    func markCompletionProven(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        await persist(evidence.advanced(
            to: .completed,
            proof: .completionMarkerRecorded,
            disposition: evidence.finalDisposition == .none ? .createdAndVerified : evidence.finalDisposition,
            retry: .retryUnnecessaryCompletionProven,
            reviewRequired: false,
            adding: .executorCompletionProven
        ))
    }

    func markCompletionUncertain(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        await persist(evidence.advanced(
            to: .failedWithUncertainCompletion,
            proof: .completionUncertain,
            disposition: .completionUncertain,
            retry: .retryProhibitedCompletionUncertain,
            reviewRequired: true,
            adding: .executorCompletionUncertain
        ))
    }

    func markSafeFailure(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        await persist(evidence.advanced(
            to: .failedSafely,
            proof: .noProof,
            disposition: .saveFailedSafely,
            retry: .retryPermittedSameOperationIdentity,
            reviewRequired: false,
            adding: .safeFailureRetryPermitted
        ))
    }

    func detectConflictingReuse(_ evidence: CanonicalTeamCreationOperationEvidence) async -> CanonicalTeamCreationEvidenceConflict {
        do {
            let context = makeContext()
            if let existing = try fetchRecord(operationIdentity: evidence.operationIdentity.rawValue, in: context).map(Self.canonicalEvidence(from:)) {
                if existing.requestFingerprint != evidence.requestFingerprint { return .sameOperationDifferentRequest }
                if existing.phase == .failedWithUncertainCompletion || existing.phase == .saveOutcomeUncertain { return .uncertainPriorCompletion }
                if existing.phase == .inProgress || existing.phase == .saveAttempted { return .inProgress }
            }

            let teamDescriptor = FetchDescriptor<TeamCreationOperationEvidenceRecord>(
                predicate: #Predicate { $0.targetTeamIdentity == evidence.teamIdentity }
            )
            let teamEvidence = try context.fetch(teamDescriptor).map(Self.canonicalEvidence(from:))
            if teamEvidence.contains(where: { $0.operationIdentity != evidence.operationIdentity && $0.requestFingerprint != evidence.requestFingerprint && $0.phase != .failedSafely }) {
                return .sameTeamDifferentMeaning
            }
            return .none
        } catch {
            return .inProgress
        }
    }

    private func persist(_ evidence: CanonicalTeamCreationOperationEvidence) async {
        do {
            let context = makeContext()
            if let record = try fetchRecord(operationIdentity: evidence.operationIdentity.rawValue, in: context) {
                let current = Self.canonicalEvidence(from: record)
                guard current.requestFingerprint == evidence.requestFingerprint else { return }
                guard TeamCreationOperationTransitionPolicy.canAdvance(from: current.phase, to: evidence.phase) else { return }
                apply(evidence, to: record)
            } else {
                context.insert(Self.record(from: evidence))
            }
            try context.save()
        } catch {
            return
        }
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func fetchRecord(operationIdentity: String, in context: ModelContext) throws -> TeamCreationOperationEvidenceRecord? {
        let descriptor = FetchDescriptor<TeamCreationOperationEvidenceRecord>(
            predicate: #Predicate { $0.operationIdentity == operationIdentity }
        )
        return try context.fetch(descriptor).first
    }

    private func apply(_ evidence: CanonicalTeamCreationOperationEvidence, to record: TeamCreationOperationEvidenceRecord) {
        record.targetTeamIdentity = evidence.teamIdentity
        record.requestFingerprint = evidence.requestFingerprint.rawValue
        record.phase = evidence.phase.rawValue
        record.completionProof = evidence.completionProof.rawValue
        record.finalDisposition = evidence.finalDisposition.rawValue
        record.retryClassification = evidence.retryClassification.rawValue
        record.reviewRequired = evidence.reviewRequired
        record.diagnosticCodesStorage = Self.encodeDiagnosticCodes(evidence.diagnosticCodes)
    }

    private static func record(from evidence: CanonicalTeamCreationOperationEvidence) -> TeamCreationOperationEvidenceRecord {
        TeamCreationOperationEvidenceRecord(
            operationIdentity: evidence.operationIdentity.rawValue,
            targetTeamIdentity: evidence.teamIdentity,
            requestFingerprint: evidence.requestFingerprint.rawValue,
            phase: evidence.phase.rawValue,
            completionProof: evidence.completionProof.rawValue,
            finalDisposition: evidence.finalDisposition.rawValue,
            retryClassification: evidence.retryClassification.rawValue,
            reviewRequired: evidence.reviewRequired,
            diagnosticCodesStorage: encodeDiagnosticCodes(evidence.diagnosticCodes),
            source: "isolated-swiftdata-evidence"
        )
    }

    private static func canonicalEvidence(from record: TeamCreationOperationEvidenceRecord) -> CanonicalTeamCreationOperationEvidence {
        CanonicalTeamCreationOperationEvidence(
            operationIdentity: CanonicalTeamCreationOperationIdentity(record.operationIdentity),
            teamIdentity: record.targetTeamIdentity,
            requestFingerprint: CanonicalTeamCreationSemanticRequestFingerprint(rawValue: record.requestFingerprint),
            phase: CanonicalTeamCreationOperationPhase(rawValue: record.phase) ?? .reviewRequired,
            completionProof: CanonicalTeamCreationCompletionProof(rawValue: record.completionProof) ?? .noProof,
            finalDisposition: CanonicalTeamCreationFinalDisposition(rawValue: record.finalDisposition) ?? .reviewRequired,
            retryClassification: CanonicalTeamCreationRetryClassification(rawValue: record.retryClassification) ?? .reviewRequiredBeforeRetry,
            reviewRequired: record.reviewRequired,
            diagnosticCodes: decodeDiagnosticCodes(record.diagnosticCodesStorage)
        )
    }

    private static func encodeDiagnosticCodes(_ codes: [CanonicalTeamCreationDiagnosticCode]) -> String {
        codes.map(\.rawValue).sorted().joined(separator: "|")
    }

    private static func decodeDiagnosticCodes(_ storage: String) -> [CanonicalTeamCreationDiagnosticCode] {
        storage.split(separator: "|").compactMap { CanonicalTeamCreationDiagnosticCode(rawValue: String($0)) }.sorted { $0.rawValue < $1.rawValue }
    }
}

extension CanonicalTeamCreationSemanticRequestFingerprint {
    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
