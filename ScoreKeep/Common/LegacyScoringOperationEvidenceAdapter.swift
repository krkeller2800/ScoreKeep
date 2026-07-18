import Foundation
import SwiftData

enum LegacyScoringOperationEvidenceLookupClassification: String, Hashable, Sendable {
    case acceptedExactRetry
    case conflictingReuse
    case noEvidence
    case lookupFailed
}

enum LegacyScoringOperationEvidenceSaveResult: String, Hashable, Sendable {
    case notAttempted
    case succeeded
    case failed
    case completionUncertain
}

enum LegacyScoringOperationEvidenceIdempotencyResult: String, Hashable, Sendable {
    case firstInvocation
    case exactRetryAlreadyAccepted
    case conflictingOperationIdentity
    case noEvidence
    case lookupFailed
}

enum LegacyScoringOperationEvidenceInjectedFailure: Hashable, Sendable {
    case save
    case completionUncertain
    case freshLookup
}

struct LegacyScoringOperationEvidenceLookupResult: Hashable, Sendable {
    let classification: LegacyScoringOperationEvidenceLookupClassification
    let operationIdentity: UUID
    let requestFingerprint: String
    let targetGameIdentity: UUID
    let targetAtbatIdentity: UUID
    let acceptedOutcomeReference: String?
    let persistedDisposition: String?
    let lookupPerformedWrites: Bool
}

struct LegacyScoringOperationEvidenceTransactionResult: Hashable, Sendable {
    let transaction: CanonicalPersistenceTransactionResult
    let operationIdentity: UUID
    let requestFingerprint: String
    let saveResult: LegacyScoringOperationEvidenceSaveResult
    let idempotencyResult: LegacyScoringOperationEvidenceIdempotencyResult
    let lookupResult: LegacyScoringOperationEvidenceLookupResult
    let routingRemainsDisabled: Bool
    let ordinaryScoringWritesEvidence: Bool
    let canonicalWritesPerformed: Bool
}

struct LegacyScoringOperationEvidenceDependencies {
    var injectedFailures: Set<LegacyScoringOperationEvidenceInjectedFailure>
    var save: @MainActor (ModelContext) throws -> Void
    var rollback: @MainActor (ModelContext) -> Void
    var makeFreshContext: @MainActor (ModelContainer) -> ModelContext

    init(
        injectedFailures: Set<LegacyScoringOperationEvidenceInjectedFailure> = [],
        save: @escaping @MainActor (ModelContext) throws -> Void = { context in try context.save() },
        rollback: @escaping @MainActor (ModelContext) -> Void = { context in context.rollback() },
        makeFreshContext: @escaping @MainActor (ModelContainer) -> ModelContext = { container in ModelContext(container) }
    ) {
        self.injectedFailures = injectedFailures
        self.save = save
        self.rollback = rollback
        self.makeFreshContext = makeFreshContext
    }
}

@MainActor
struct LegacyScoringOperationEvidenceFreshLookup {
    private let container: ModelContainer
    private let makeFreshContext: @MainActor (ModelContainer) -> ModelContext

    init(
        container: ModelContainer,
        makeFreshContext: @escaping @MainActor (ModelContainer) -> ModelContext = { container in ModelContext(container) }
    ) {
        self.container = container
        self.makeFreshContext = makeFreshContext
    }

    func lookup(_ request: LegacyScoringOperationRequestFacts) -> LegacyScoringOperationEvidenceLookupResult {
        let fingerprint = LegacyScoringOperationRequestFingerprint(request)
        let context = makeFreshContext(container)
        context.autosaveEnabled = false
        do {
            guard let record = try Self.fetch(operationIdentity: request.operationIdentity, in: context) else {
                return result(.noEvidence, request: request, fingerprint: fingerprint, record: nil)
            }
            guard record.requestFingerprint == fingerprint.rawValue,
                  record.targetGameIdentity == request.targetGameIdentity,
                  record.targetAtbatIdentity == request.targetAtbatIdentity else {
                return result(.conflictingReuse, request: request, fingerprint: fingerprint, record: record)
            }
            guard record.disposition == LegacyScoringOperationEvidenceConstants.acceptedDisposition,
                  record.completionState == LegacyScoringOperationEvidenceConstants.completedState else {
                return result(.conflictingReuse, request: request, fingerprint: fingerprint, record: record)
            }
            return result(.acceptedExactRetry, request: request, fingerprint: fingerprint, record: record)
        } catch {
            return result(.lookupFailed, request: request, fingerprint: fingerprint, record: nil)
        }
    }

    static func fetch(operationIdentity: UUID, in context: ModelContext) throws -> LegacyScoringOperationEvidenceRecord? {
        var descriptor = FetchDescriptor<LegacyScoringOperationEvidenceRecord>(
            predicate: #Predicate { $0.operationIdentity == operationIdentity }
        )
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor).first
    }

    private func result(
        _ classification: LegacyScoringOperationEvidenceLookupClassification,
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        record: LegacyScoringOperationEvidenceRecord?
    ) -> LegacyScoringOperationEvidenceLookupResult {
        LegacyScoringOperationEvidenceLookupResult(
            classification: classification,
            operationIdentity: request.operationIdentity,
            requestFingerprint: fingerprint.rawValue,
            targetGameIdentity: record?.targetGameIdentity ?? request.targetGameIdentity,
            targetAtbatIdentity: record?.targetAtbatIdentity ?? request.targetAtbatIdentity,
            acceptedOutcomeReference: record?.acceptedOutcomeReference,
            persistedDisposition: record?.disposition,
            lookupPerformedWrites: false
        )
    }
}

@MainActor
struct LegacyScoringOperationEvidenceAdapter {
    private let container: ModelContainer
    private let dependencies: LegacyScoringOperationEvidenceDependencies

    init(container: ModelContainer, dependencies: LegacyScoringOperationEvidenceDependencies = LegacyScoringOperationEvidenceDependencies()) {
        self.container = container
        self.dependencies = dependencies
    }

    func applyUsingDedicatedContext(
        _ request: LegacyScoringOperationRequestFacts,
        mutateLegacyFacts: (ModelContext) throws -> Void
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return apply(request, in: context, mutateLegacyFacts: mutateLegacyFacts)
    }

    func apply(
        _ request: LegacyScoringOperationRequestFacts,
        in context: ModelContext,
        mutateLegacyFacts: (ModelContext) throws -> Void
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        let fingerprint = LegacyScoringOperationRequestFingerprint(request)
        if let existing = try? LegacyScoringOperationEvidenceFreshLookup.fetch(operationIdentity: request.operationIdentity, in: context) {
            let lookup = classify(existing, request: request, fingerprint: fingerprint)
            return existingResult(request: request, fingerprint: fingerprint, lookup: lookup)
        }

        do {
            try mutateLegacyFacts(context)
            let record = LegacyScoringOperationEvidenceRecord(
                operationIdentity: request.operationIdentity,
                requestFingerprint: fingerprint.rawValue,
                targetGameIdentity: request.targetGameIdentity,
                targetAtbatIdentity: request.targetAtbatIdentity,
                submissionFamily: request.submissionFamily,
                acceptedResultClassification: request.acceptedResultClassification,
                acceptedOutcomeReference: request.acceptedOutcomeReference
            )
            context.insert(record)
            if dependencies.injectedFailures.contains(.completionUncertain) {
                dependencies.rollback(context)
                let lookup = freshLookup(request)
                return uncertainResult(request: request, fingerprint: fingerprint, lookup: lookup)
            }
            if dependencies.injectedFailures.contains(.save) {
                throw LegacyScoringOperationEvidenceInjectedSaveError.deterministicFailure
            }
            try dependencies.save(context)
        } catch {
            dependencies.rollback(context)
            let lookup = freshLookup(request)
            if lookup.classification == .acceptedExactRetry {
                return duplicateResult(request: request, fingerprint: fingerprint, lookup: lookup, saveResult: .completionUncertain)
            }
            return failedResult(request: request, fingerprint: fingerprint, lookup: lookup)
        }

        let lookup = freshLookup(request)
        if lookup.classification == .acceptedExactRetry {
            return successResult(request: request, fingerprint: fingerprint, lookup: lookup)
        }
        return uncertainResult(request: request, fingerprint: fingerprint, lookup: lookup)
    }

    private func freshLookup(_ request: LegacyScoringOperationRequestFacts) -> LegacyScoringOperationEvidenceLookupResult {
        if dependencies.injectedFailures.contains(.freshLookup) {
            let fingerprint = LegacyScoringOperationRequestFingerprint(request)
            return LegacyScoringOperationEvidenceLookupResult(
                classification: .lookupFailed,
                operationIdentity: request.operationIdentity,
                requestFingerprint: fingerprint.rawValue,
                targetGameIdentity: request.targetGameIdentity,
                targetAtbatIdentity: request.targetAtbatIdentity,
                acceptedOutcomeReference: nil,
                persistedDisposition: nil,
                lookupPerformedWrites: false
            )
        }
        return LegacyScoringOperationEvidenceFreshLookup(
            container: container,
            makeFreshContext: dependencies.makeFreshContext
        ).lookup(request)
    }

    private func classify(
        _ record: LegacyScoringOperationEvidenceRecord,
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint
    ) -> LegacyScoringOperationEvidenceLookupResult {
        let classification: LegacyScoringOperationEvidenceLookupClassification
        if record.requestFingerprint == fingerprint.rawValue,
           record.targetGameIdentity == request.targetGameIdentity,
           record.targetAtbatIdentity == request.targetAtbatIdentity,
           record.disposition == LegacyScoringOperationEvidenceConstants.acceptedDisposition,
           record.completionState == LegacyScoringOperationEvidenceConstants.completedState {
            classification = .acceptedExactRetry
        } else {
            classification = .conflictingReuse
        }
        return LegacyScoringOperationEvidenceLookupResult(
            classification: classification,
            operationIdentity: request.operationIdentity,
            requestFingerprint: fingerprint.rawValue,
            targetGameIdentity: record.targetGameIdentity,
            targetAtbatIdentity: record.targetAtbatIdentity,
            acceptedOutcomeReference: record.acceptedOutcomeReference,
            persistedDisposition: record.disposition,
            lookupPerformedWrites: false
        )
    }

    private func existingResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        switch lookup.classification {
        case .acceptedExactRetry:
            return duplicateResult(request: request, fingerprint: fingerprint, lookup: lookup, saveResult: .notAttempted)
        case .conflictingReuse, .lookupFailed, .noEvidence:
            return conflictResult(request: request, fingerprint: fingerprint, lookup: lookup)
        }
    }

    private func successResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        makeResult(
            disposition: .success,
            request: request,
            fingerprint: fingerprint,
            lookup: lookup,
            saveResult: .succeeded,
            idempotency: .firstInvocation,
            retrySafety: .notNeeded,
            saveProven: true
        )
    }

    private func duplicateResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult,
        saveResult: LegacyScoringOperationEvidenceSaveResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        makeResult(
            disposition: .duplicateAlreadyApplied,
            request: request,
            fingerprint: fingerprint,
            lookup: lookup,
            saveResult: saveResult,
            idempotency: .exactRetryAlreadyAccepted,
            retrySafety: .notNeeded,
            saveProven: true
        )
    }

    private func conflictResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        makeResult(
            disposition: .contradictory,
            request: request,
            fingerprint: fingerprint,
            lookup: lookup,
            saveResult: .notAttempted,
            idempotency: .conflictingOperationIdentity,
            retrySafety: .unsafe,
            saveProven: true,
            review: true
        )
    }

    private func failedResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        makeResult(
            disposition: .saveFailed,
            request: request,
            fingerprint: fingerprint,
            lookup: lookup,
            saveResult: .failed,
            idempotency: lookup.classification == .noEvidence ? .noEvidence : .lookupFailed,
            retrySafety: lookup.classification == .noEvidence ? .safe : .unknown,
            saveProven: false,
            review: lookup.classification != .noEvidence,
            uncertain: true
        )
    }

    private func uncertainResult(
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        makeResult(
            disposition: .partialOrUncertainOutcome,
            request: request,
            fingerprint: fingerprint,
            lookup: lookup,
            saveResult: .completionUncertain,
            idempotency: .lookupFailed,
            retrySafety: .unknown,
            saveProven: false,
            review: true,
            uncertain: true
        )
    }

    private func makeResult(
        disposition: CanonicalPersistenceTransactionDisposition,
        request: LegacyScoringOperationRequestFacts,
        fingerprint: LegacyScoringOperationRequestFingerprint,
        lookup: LegacyScoringOperationEvidenceLookupResult,
        saveResult: LegacyScoringOperationEvidenceSaveResult,
        idempotency: LegacyScoringOperationEvidenceIdempotencyResult,
        retrySafety: CanonicalPersistenceRetrySafety,
        saveProven: Bool,
        review: Bool = false,
        uncertain: Bool = false
    ) -> LegacyScoringOperationEvidenceTransactionResult {
        LegacyScoringOperationEvidenceTransactionResult(
            transaction: CanonicalPersistenceTransactionResult(
                disposition: disposition,
                operationIdentity: request.operationIdentity.uuidString,
                affectedRecordIdentities: [request.targetGameIdentity.uuidString, request.targetAtbatIdentity.uuidString],
                priorAcceptedStateRemainsUsable: true,
                retrySafety: retrySafety,
                explicitReloadRequired: lookup.classification == .lookupFailed,
                repairOrReviewRequired: review,
                workflowMayContinue: disposition == .success || disposition == .duplicateAlreadyApplied,
                saveCompletionProven: saveProven,
                resultUncertainBecauseSaveCompletionCannotBeProven: uncertain
            ),
            operationIdentity: request.operationIdentity,
            requestFingerprint: fingerprint.rawValue,
            saveResult: saveResult,
            idempotencyResult: idempotency,
            lookupResult: lookup,
            routingRemainsDisabled: true,
            ordinaryScoringWritesEvidence: false,
            canonicalWritesPerformed: false
        )
    }
}

private enum LegacyScoringOperationEvidenceInjectedSaveError: Error {
    case deterministicFailure
}
