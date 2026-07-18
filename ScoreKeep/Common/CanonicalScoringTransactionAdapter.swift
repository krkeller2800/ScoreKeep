import CryptoKit
import Foundation
import SwiftData

enum CanonicalScoringTransactionOperationMode: String, Hashable, Sendable {
    case scoringEvent
    case correctionReplacement
}

enum CanonicalScoringTransactionSaveResult: String, Hashable, Sendable {
    case notAttempted
    case succeeded
    case failed
    case completionUncertain
}

enum CanonicalScoringTransactionRollbackResult: String, Hashable, Sendable {
    case notRequired
    case completed
    case uncertain
    case notAttemptedUnsafeIncomingContext
}

enum CanonicalScoringTransactionReloadResult: String, Hashable, Sendable {
    case notRequired
    case succeeded
    case failed
    case foundConflictingEvidence
}

enum CanonicalScoringTransactionIdempotencyResult: String, Hashable, Sendable {
    case firstInvocation
    case exactRepeatAlreadyApplied
    case conflictingOperationIdentity
    case durableEvidenceIncomplete
    case duplicateLookupFailed
}

enum CanonicalScoringTransactionInjectedFailure: Hashable, Sendable {
    case duplicateLookup
    case insertPreparation
    case save
    case completionUncertain
    case rollbackUncertain
    case reload
}

struct CanonicalScoringTransactionRequest: Hashable, Sendable {
    let operationIdentity: UUID
    let operationMode: CanonicalScoringTransactionOperationMode
    let command: CanonicalScoringCommand
    let inputState: CanonicalScoringCommandInputState
    let correctionIdentity: UUID?
    let targetEventIdentity: UUID?
    let expectedTargetPayloadFingerprint: String?

    init(
        operationIdentity: UUID,
        operationMode: CanonicalScoringTransactionOperationMode = .scoringEvent,
        command: CanonicalScoringCommand,
        inputState: CanonicalScoringCommandInputState,
        correctionIdentity: UUID? = nil,
        targetEventIdentity: UUID? = nil,
        expectedTargetPayloadFingerprint: String? = nil
    ) {
        self.operationIdentity = operationIdentity
        self.operationMode = operationMode
        self.command = command
        self.inputState = inputState
        self.correctionIdentity = correctionIdentity
        self.targetEventIdentity = targetEventIdentity
        self.expectedTargetPayloadFingerprint = expectedTargetPayloadFingerprint
    }
}

struct CanonicalScoringTransactionRequestFingerprint: Hashable, Sendable {
    let rawValue: String

    init(request: CanonicalScoringTransactionRequest, payloadFingerprint: String) {
        let fields = [
            "operation=\(request.operationIdentity.uuidString.lowercased())",
            "mode=\(request.operationMode.rawValue)",
            "game=\(request.command.gameIdentity.validIdentifier?.uuidString.lowercased() ?? "missing")",
            "event=\(request.command.proposedEventIdentity.validIdentifier?.uuidString.lowercased() ?? "missing")",
            "payload=\(payloadFingerprint)",
            "correction=\(request.correctionIdentity?.uuidString.lowercased() ?? "none")",
            "target=\(request.targetEventIdentity?.uuidString.lowercased() ?? "none")",
            "expectedTarget=\(request.expectedTargetPayloadFingerprint ?? "none")"
        ].joined(separator: "|")
        rawValue = SHA256.hash(data: Data(fields.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct CanonicalScoringTransactionResult: Hashable, Sendable {
    let transaction: CanonicalPersistenceTransactionResult
    let operationIdentity: UUID
    let gameIdentity: UUID?
    let acceptedEventIdentity: UUID?
    let correctionIdentity: UUID?
    let targetEventIdentity: UUID?
    let commitSequence: Int?
    let payloadFingerprint: String?
    let requestFingerprint: String?
    let validationFindings: [CanonicalValidationFinding]
    let saveResult: CanonicalScoringTransactionSaveResult
    let rollbackResult: CanonicalScoringTransactionRollbackResult
    let reloadResult: CanonicalScoringTransactionReloadResult
    let idempotencyResult: CanonicalScoringTransactionIdempotencyResult
    let routingRemainsDisabled: Bool
    let managedObjectsEscaped: Bool
}

struct CanonicalScoringTransactionDependencies {
    var injectedFailures: Set<CanonicalScoringTransactionInjectedFailure>
    var save: @MainActor (ModelContext) throws -> Void
    var rollback: @MainActor (ModelContext) -> Void
    var makeReloadContext: @MainActor (ModelContainer) -> ModelContext

    init(
        injectedFailures: Set<CanonicalScoringTransactionInjectedFailure> = [],
        save: @escaping @MainActor (ModelContext) throws -> Void = { context in try context.save() },
        rollback: @escaping @MainActor (ModelContext) -> Void = { context in context.rollback() },
        makeReloadContext: @escaping @MainActor (ModelContainer) -> ModelContext = { container in ModelContext(container) }
    ) {
        self.injectedFailures = injectedFailures
        self.save = save
        self.rollback = rollback
        self.makeReloadContext = makeReloadContext
    }
}

@MainActor
struct CanonicalScoringTransactionAdapter {
    private let container: ModelContainer
    private let dependencies: CanonicalScoringTransactionDependencies

    init(container: ModelContainer, dependencies: CanonicalScoringTransactionDependencies = CanonicalScoringTransactionDependencies()) {
        self.container = container
        self.dependencies = dependencies
    }

    func applyUsingDedicatedOperationContext(_ request: CanonicalScoringTransactionRequest) -> CanonicalScoringTransactionResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return apply(request, in: context)
    }

    func apply(_ request: CanonicalScoringTransactionRequest, in context: ModelContext) -> CanonicalScoringTransactionResult {
        guard context.hasChanges == false else {
            return rejected(
                request: request,
                findings: [finding("scoringTransaction.context.dirty", concept: .compatibilityTransport, severity: .rejection, disposition: .rejected, summary: "The scoring transaction context has unrelated pending changes.")],
                rollbackResult: .notAttemptedUnsafeIncomingContext,
                idempotency: .firstInvocation
            )
        }

        let prepared: PreparedScoringTransaction
        do {
            prepared = try prepare(request)
        } catch let error as CanonicalScoringTransactionPreparationError {
            return rejected(request: request, findings: [error.finding], idempotency: .firstInvocation)
        } catch {
            return rejected(
                request: request,
                findings: [finding("scoringTransaction.payload.encodingFailed", severity: .rejection, disposition: .rejected, summary: "Scoring payload could not be encoded before persistence.")],
                idempotency: .firstInvocation
            )
        }

        let requestFingerprint = CanonicalScoringTransactionRequestFingerprint(request: request, payloadFingerprint: prepared.payloadFingerprint)
        var findings = prepared.validation.result.findings
        findings.append(contentsOf: validate(request, prepared: prepared))

        if !findings.isEmpty {
            return rejected(request: request, prepared: prepared, requestFingerprint: requestFingerprint, findings: findings, idempotency: .firstInvocation)
        }

        if dependencies.injectedFailures.contains(.duplicateLookup) {
            return result(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                disposition: .unresolved,
                findings: [finding("scoringTransaction.duplicateLookup.failed", severity: .unresolved, disposition: .unresolved, summary: "Durable operation lookup failed before insertion.")],
                saveResult: .notAttempted,
                rollbackResult: .notRequired,
                reloadResult: .notRequired,
                idempotency: .duplicateLookupFailed,
                retrySafety: .unsafe,
                targetProven: false,
                saveProven: true,
                review: true
            )
        }

        do {
            if let existing = try fetchOperation(request.operationIdentity, in: context) {
                return classifyExistingOperation(existing, request: request, prepared: prepared, requestFingerprint: requestFingerprint)
            }
            if try fetchEvent(prepared.eventIdentity, in: context) != nil {
                return result(
                    request: request,
                    prepared: prepared,
                    requestFingerprint: requestFingerprint,
                    disposition: .contradictory,
                    findings: [finding("scoringTransaction.eventIdentity.conflict", severity: .contradiction, disposition: .contradictory, summary: "The proposed scoring event identity already exists for a different operation.")],
                    saveResult: .notAttempted,
                    rollbackResult: .notRequired,
                    reloadResult: .notRequired,
                    idempotency: .conflictingOperationIdentity,
                    retrySafety: .unsafe,
                    targetProven: false,
                    saveProven: true,
                    review: true
                )
            }
        } catch {
            return result(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                disposition: .unresolved,
                findings: [finding("scoringTransaction.lookup.failed", severity: .unresolved, disposition: .unresolved, summary: "Durable scoring transaction lookup failed before insertion.")],
                saveResult: .notAttempted,
                rollbackResult: .notRequired,
                reloadResult: .notRequired,
                idempotency: .duplicateLookupFailed,
                retrySafety: .unsafe,
                targetProven: false,
                saveProven: true,
                review: true
            )
        }

        if dependencies.injectedFailures.contains(.insertPreparation) {
            return rejected(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                findings: [finding("scoringTransaction.insertPreparation.failed", severity: .rejection, disposition: .rejected, summary: "Scoring transaction insert preparation failed before persistence.")],
                idempotency: .firstInvocation
            )
        }

        do {
            let graph = try makeGraph(request: request, prepared: prepared, requestFingerprint: requestFingerprint, context: context)
            context.insert(graph.history)
            context.insert(graph.operation)
            context.insert(graph.event)
            context.insert(graph.payload)
            if let correction = graph.correction {
                context.insert(correction)
            }
        } catch let error as CanonicalScoringTransactionPreparationError {
            return rejected(request: request, prepared: prepared, requestFingerprint: requestFingerprint, findings: [error.finding], idempotency: .firstInvocation)
        } catch {
            return rejected(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                findings: [finding("scoringTransaction.graphPreparation.failed", severity: .rejection, disposition: .rejected, summary: "Canonical scoring transaction graph could not be prepared.")],
                idempotency: .firstInvocation
            )
        }

        if dependencies.injectedFailures.contains(.completionUncertain) {
            return rollbackAfterUncertainSave(request: request, prepared: prepared, requestFingerprint: requestFingerprint, context: context)
        }

        do {
            if dependencies.injectedFailures.contains(.save) {
                throw CanonicalScoringTransactionInjectedSaveError.deterministicFailure
            }
            try dependencies.save(context)
        } catch {
            return reconcileAfterFailedSave(request: request, prepared: prepared, requestFingerprint: requestFingerprint, context: context)
        }

        return verifyAfterSave(request: request, prepared: prepared, requestFingerprint: requestFingerprint)
    }

    private func prepare(_ request: CanonicalScoringTransactionRequest) throws -> PreparedScoringTransaction {
        let application = CanonicalScoringEventApplicator.apply(request.command, to: request.inputState, sourceLocation: "CanonicalScoringTransactionAdapter")
        guard let event = application.event else {
            throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.operation.unsupported", severity: .rejection, disposition: .rejected, summary: "The scoring command did not produce an accepted event."))
        }
        let payload = payloadValue(for: event)
        let payloadData = try CanonicalScoringPayloadCoding.encode(payload)
        return PreparedScoringTransaction(
            event: event,
            eventIdentity: payload.eventIdentity,
            gameIdentity: payload.gameIdentity,
            payloadValue: payload,
            payloadData: payloadData,
            payloadFingerprint: CanonicalScoringPayloadCoding.fingerprint(payloadData),
            validation: application.validation
        )
    }

    private func validate(_ request: CanonicalScoringTransactionRequest, prepared: PreparedScoringTransaction) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        if request.inputState.game.identity.validIdentifier != prepared.gameIdentity {
            findings.append(finding("scoringTransaction.gameIdentity.mismatch", concept: .game, severity: .contradiction, disposition: .contradictory, summary: "Input game identity and scoring payload game identity do not match."))
        }
        if request.command.proposedEventIdentity.validIdentifier == nil {
            findings.append(finding("scoringTransaction.eventIdentity.missing", concept: .stableIdentity, severity: .rejection, disposition: .rejected, summary: "Canonical scoring persistence requires a stable proposed event identity."))
        }
        switch request.operationMode {
        case .scoringEvent:
            if request.correctionIdentity != nil || request.targetEventIdentity != nil {
                findings.append(finding("scoringTransaction.correctionEvidence.unexpected", severity: .rejection, disposition: .rejected, summary: "Ordinary scoring operations must not carry correction target evidence."))
            }
        case .correctionReplacement:
            if request.correctionIdentity == nil {
                findings.append(finding("scoringTransaction.correctionIdentity.missing", concept: .stableIdentity, severity: .rejection, disposition: .rejected, summary: "Correction persistence requires a stable correction identity."))
            }
            if request.targetEventIdentity == nil {
                findings.append(finding("scoringTransaction.correctionTarget.missing", severity: .rejection, disposition: .rejected, summary: "Correction persistence requires a target event identity."))
            }
            if request.targetEventIdentity == prepared.eventIdentity {
                findings.append(finding("scoringTransaction.supersession.selfReference", severity: .contradiction, disposition: .contradictory, summary: "A correction replacement event cannot supersede itself."))
            }
        }
        return findings
    }

    private func makeGraph(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint,
        context: ModelContext
    ) throws -> PreparedScoringRecordGraph {
        let game = try fetchGame(prepared.gameIdentity, in: context)
        guard let game else {
            throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.game.missing", concept: .game, severity: .rejection, disposition: .rejected, summary: "The target game is missing."))
        }

        let history = try fetchOrCreateHistory(gameIdentity: prepared.gameIdentity, game: game, in: context)
        let sequence = history.lastCommittedSequence + 1

        let targetEvent: CanonicalScoringEventEnvelopeRecord?
        let targetPayload: CanonicalScoringEventPayloadRecord?
        if request.operationMode == .correctionReplacement {
            guard let targetIdentity = request.targetEventIdentity else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionTarget.missing", severity: .rejection, disposition: .rejected, summary: "Correction persistence requires a target event identity."))
            }
            targetEvent = try fetchEvent(targetIdentity, in: context)
            guard let targetEvent else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionTarget.notFound", severity: .rejection, disposition: .rejected, summary: "The correction target event is missing."))
            }
            guard targetEvent.historyIdentity == history.historyIdentity, targetEvent.gameIdentity == prepared.gameIdentity else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionTarget.wrongGame", concept: .game, severity: .contradiction, disposition: .contradictory, summary: "The correction target event belongs to a different game history."))
            }
            guard try fetchCorrectionTargeting(targetIdentity, in: context).isEmpty else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionTarget.alreadySuperseded", severity: .rejection, disposition: .rejected, summary: "The correction target already has accepted supersession evidence."))
            }
            targetPayload = try fetchPayload(eventIdentity: targetIdentity, in: context)
            if let expected = request.expectedTargetPayloadFingerprint, targetPayload?.payloadFingerprint != expected {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionTarget.fingerprintMismatch", severity: .contradiction, disposition: .contradictory, summary: "The correction target payload fingerprint does not match the expected original evidence."))
            }
            guard targetEvent.commitSequence < sequence else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.ordering.correctionBeforeTarget", concept: .ordering, severity: .contradiction, disposition: .contradictory, summary: "Correction ordering must follow the target event."))
            }
        } else {
            targetEvent = nil
            targetPayload = nil
        }

        let operationKind = request.operationMode == .scoringEvent
            ? CanonicalScoringPersistenceConstants.operationScoringKind
            : CanonicalScoringPersistenceConstants.operationCorrectionKind
        let operation = CanonicalScoringOperationEvidenceRecord(
            operationIdentity: request.operationIdentity,
            gameIdentity: prepared.gameIdentity,
            operationKind: operationKind,
            requestFingerprint: requestFingerprint.rawValue,
            disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
            verificationStatus: "transactionVerified",
            proposedEventIdentity: prepared.eventIdentity,
            acceptedEventIdentity: prepared.eventIdentity,
            correctionIdentity: request.correctionIdentity,
            targetEventIdentity: request.targetEventIdentity,
            replacementEventIdentity: request.operationMode == .correctionReplacement ? prepared.eventIdentity : nil,
            commitSequence: sequence,
            history: history
        )
        let event = CanonicalScoringEventEnvelopeRecord(
            eventIdentity: prepared.eventIdentity,
            historyIdentity: history.historyIdentity,
            gameIdentity: prepared.gameIdentity,
            commitSequence: sequence,
            eventFamily: prepared.payloadValue.eventFamily,
            eventStatus: CanonicalScoringPersistenceConstants.eventActiveStatus,
            sourceClassification: request.command.source.rawValue,
            evidenceSchemaVersion: prepared.payloadValue.formatVersion,
            originatingOperationIdentity: request.operationIdentity,
            replaySlotOriginalEventIdentity: request.targetEventIdentity,
            history: history,
            operation: operation
        )
        let payload = CanonicalScoringEventPayloadRecord(
            eventIdentity: prepared.eventIdentity,
            eventFamily: prepared.payloadValue.eventFamily,
            payloadVersion: prepared.payloadValue.formatVersion,
            scoringSemanticsVersion: CanonicalScoringPayloadCoding.supportedPayloadVersion,
            encodedPayload: prepared.payloadData,
            payloadFingerprint: prepared.payloadFingerprint,
            unsupportedClassification: prepared.payloadValue.unsupportedRawEvidence.isEmpty ? nil : prepared.payloadValue.unsupportedRawEvidence.joined(separator: "|"),
            ambiguityClassification: prepared.payloadValue.ambiguityCodes.isEmpty ? nil : prepared.payloadValue.ambiguityCodes.joined(separator: "|"),
            event: event
        )
        event.payload = payload
        operation.acceptedEvent = event

        let correction: CanonicalScoringCorrectionRecord?
        if request.operationMode == .correctionReplacement {
            guard let correctionIdentity = request.correctionIdentity, let targetEventIdentity = request.targetEventIdentity else {
                throw CanonicalScoringTransactionPreparationError(finding: finding("scoringTransaction.correctionEvidence.missing", severity: .rejection, disposition: .rejected, summary: "Correction identity and target identity are required."))
            }
            let record = CanonicalScoringCorrectionRecord(
                correctionIdentity: correctionIdentity,
                gameIdentity: prepared.gameIdentity,
                correctionOperationIdentity: request.operationIdentity,
                originalEventIdentity: targetEventIdentity,
                correctionOperationShape: CanonicalScoringPersistenceConstants.correctionReplaceShape,
                disposition: CanonicalScoringPersistenceConstants.correctionAcceptedDisposition,
                earliestReplaySequence: targetEvent?.commitSequence ?? sequence,
                replacementEventIdentity: prepared.eventIdentity,
                expectedOriginalEventFingerprint: targetPayload?.payloadFingerprint,
                history: history,
                originalEvent: targetEvent,
                replacementEvent: event,
                operation: operation
            )
            operation.correction = record
            correction = record
        } else {
            correction = nil
        }

        history.lastCommittedSequence = sequence
        history.events.append(event)
        history.operations.append(operation)
        if let correction {
            history.corrections.append(correction)
        }
        return PreparedScoringRecordGraph(history: history, operation: operation, event: event, payload: payload, correction: correction)
    }

    private func verifyAfterSave(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint
    ) -> CanonicalScoringTransactionResult {
        if dependencies.injectedFailures.contains(.reload) {
            return result(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                disposition: .staleProjection,
                findings: [finding("scoringTransaction.reload.failed", severity: .repair, disposition: .repairRequired, summary: "Fresh scoring transaction verification failed after save.")],
                saveResult: .succeeded,
                rollbackResult: .notRequired,
                reloadResult: .failed,
                idempotency: .firstInvocation,
                retrySafety: .unsafe,
                targetProven: false,
                saveProven: true,
                review: true
            )
        }

        let reloadContext = dependencies.makeReloadContext(container)
        reloadContext.autosaveEnabled = false
        do {
            guard let operation = try fetchOperation(request.operationIdentity, in: reloadContext) else {
                return incompleteDurableEvidenceResult(request: request, prepared: prepared, requestFingerprint: requestFingerprint, saveResult: .succeeded, reloadResult: .failed)
            }
            return classifyExistingOperation(operation, request: request, prepared: prepared, requestFingerprint: requestFingerprint, saveResult: .succeeded, idempotency: .firstInvocation)
        } catch {
            return result(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                disposition: .staleProjection,
                findings: [finding("scoringTransaction.reload.fetchFailed", severity: .repair, disposition: .repairRequired, summary: "Fresh scoring transaction lookup failed after save.")],
                saveResult: .succeeded,
                rollbackResult: .notRequired,
                reloadResult: .failed,
                idempotency: .durableEvidenceIncomplete,
                retrySafety: .unsafe,
                targetProven: false,
                saveProven: true,
                review: true
            )
        }
    }

    private func reconcileAfterFailedSave(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint,
        context: ModelContext
    ) -> CanonicalScoringTransactionResult {
        let rollbackResult = rollback(context)
        let reloadContext = dependencies.makeReloadContext(container)
        reloadContext.autosaveEnabled = false
        if let existing = try? fetchOperation(request.operationIdentity, in: reloadContext) {
            return classifyExistingOperation(existing, request: request, prepared: prepared, requestFingerprint: requestFingerprint, saveResult: .completionUncertain, idempotency: .exactRepeatAlreadyApplied)
        }
        return result(
            request: request,
            prepared: prepared,
            requestFingerprint: requestFingerprint,
            disposition: .saveFailed,
            findings: [finding("scoringTransaction.save.failed", severity: .rejection, disposition: .rejected, summary: "Canonical scoring transaction save failed before completion was proven.")],
            saveResult: .failed,
            rollbackResult: rollbackResult,
            reloadResult: .notRequired,
            idempotency: .firstInvocation,
            retrySafety: rollbackResult == .completed ? .safe : .unknown,
            targetProven: false,
            saveProven: false,
            review: rollbackResult != .completed,
            uncertain: true
        )
    }

    private func rollbackAfterUncertainSave(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint,
        context: ModelContext
    ) -> CanonicalScoringTransactionResult {
        let rollbackResult = rollback(context)
        return result(
            request: request,
            prepared: prepared,
            requestFingerprint: requestFingerprint,
            disposition: .partialOrUncertainOutcome,
            findings: [finding("scoringTransaction.save.completionUncertain", severity: .unresolved, disposition: .unresolved, summary: "Canonical scoring transaction save completion cannot be proven.")],
            saveResult: .completionUncertain,
            rollbackResult: rollbackResult,
            reloadResult: .notRequired,
            idempotency: .firstInvocation,
            retrySafety: .unknown,
            targetProven: false,
            saveProven: false,
            review: true,
            uncertain: true
        )
    }

    private func rollback(_ context: ModelContext) -> CanonicalScoringTransactionRollbackResult {
        if dependencies.injectedFailures.contains(.rollbackUncertain) {
            return .uncertain
        }
        dependencies.rollback(context)
        return .completed
    }

    private func classifyExistingOperation(
        _ operation: CanonicalScoringOperationEvidenceRecord,
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint,
        saveResult: CanonicalScoringTransactionSaveResult = .notAttempted,
        idempotency: CanonicalScoringTransactionIdempotencyResult = .exactRepeatAlreadyApplied
    ) -> CanonicalScoringTransactionResult {
        guard operation.requestFingerprint == requestFingerprint.rawValue else {
            return result(
                request: request,
                prepared: prepared,
                requestFingerprint: requestFingerprint,
                disposition: .contradictory,
                findings: [finding("scoringTransaction.operationIdentity.conflict", severity: .contradiction, disposition: .contradictory, summary: "The operation identity has already been used for conflicting scoring evidence.")],
                saveResult: .notAttempted,
                rollbackResult: .notRequired,
                reloadResult: .notRequired,
                idempotency: .conflictingOperationIdentity,
                retrySafety: .unsafe,
                targetProven: false,
                saveProven: true,
                review: true
            )
        }
        guard operation.acceptedEventIdentity == prepared.eventIdentity,
              operation.commitSequence != nil,
              operation.disposition == CanonicalScoringPersistenceConstants.operationAcceptedDisposition else {
            return incompleteDurableEvidenceResult(request: request, prepared: prepared, requestFingerprint: requestFingerprint, saveResult: saveResult, reloadResult: .foundConflictingEvidence)
        }
        if request.operationMode == .correctionReplacement,
           operation.correctionIdentity != request.correctionIdentity || operation.targetEventIdentity != request.targetEventIdentity || operation.replacementEventIdentity != prepared.eventIdentity {
            return incompleteDurableEvidenceResult(request: request, prepared: prepared, requestFingerprint: requestFingerprint, saveResult: saveResult, reloadResult: .foundConflictingEvidence)
        }
        return result(
            request: request,
            prepared: prepared,
            requestFingerprint: requestFingerprint,
            disposition: saveResult == .succeeded && idempotency == .firstInvocation ? .success : .duplicateAlreadyApplied,
            findings: [],
            saveResult: saveResult,
            rollbackResult: .notRequired,
            reloadResult: saveResult == .succeeded ? .succeeded : .notRequired,
            idempotency: idempotency,
            retrySafety: .notNeeded,
            targetProven: true,
            saveProven: true,
            review: false,
            existingCommitSequence: operation.commitSequence
        )
    }

    private func incompleteDurableEvidenceResult(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint,
        saveResult: CanonicalScoringTransactionSaveResult,
        reloadResult: CanonicalScoringTransactionReloadResult
    ) -> CanonicalScoringTransactionResult {
        result(
            request: request,
            prepared: prepared,
            requestFingerprint: requestFingerprint,
            disposition: .partialOrUncertainOutcome,
            findings: [finding("scoringTransaction.durableEvidence.incomplete", severity: .unresolved, disposition: .unresolved, summary: "Durable scoring operation evidence is incomplete or inconsistent.")],
            saveResult: saveResult,
            rollbackResult: .notRequired,
            reloadResult: reloadResult,
            idempotency: .durableEvidenceIncomplete,
            retrySafety: .unknown,
            targetProven: false,
            saveProven: saveResult == .succeeded,
            review: true,
            uncertain: true
        )
    }

    private func rejected(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction? = nil,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint? = nil,
        findings: [CanonicalValidationFinding],
        rollbackResult: CanonicalScoringTransactionRollbackResult = .notRequired,
        idempotency: CanonicalScoringTransactionIdempotencyResult
    ) -> CanonicalScoringTransactionResult {
        result(
            request: request,
            prepared: prepared,
            requestFingerprint: requestFingerprint,
            disposition: .validationRejected,
            findings: findings,
            saveResult: .notAttempted,
            rollbackResult: rollbackResult,
            reloadResult: .notRequired,
            idempotency: idempotency,
            retrySafety: .unsafe,
            targetProven: false,
            saveProven: true,
            review: true
        )
    }

    private func result(
        request: CanonicalScoringTransactionRequest,
        prepared: PreparedScoringTransaction? = nil,
        requestFingerprint: CanonicalScoringTransactionRequestFingerprint? = nil,
        disposition: CanonicalPersistenceTransactionDisposition,
        findings: [CanonicalValidationFinding],
        saveResult: CanonicalScoringTransactionSaveResult,
        rollbackResult: CanonicalScoringTransactionRollbackResult,
        reloadResult: CanonicalScoringTransactionReloadResult,
        idempotency: CanonicalScoringTransactionIdempotencyResult,
        retrySafety: CanonicalPersistenceRetrySafety,
        targetProven: Bool,
        saveProven: Bool,
        review: Bool,
        uncertain: Bool = false,
        existingCommitSequence: Int? = nil
    ) -> CanonicalScoringTransactionResult {
        let affected = [
            prepared?.gameIdentity.uuidString,
            prepared?.eventIdentity.uuidString,
            request.correctionIdentity?.uuidString
        ].compactMap { $0 }
        let transaction = CanonicalPersistenceTransactionResult(
            disposition: disposition,
            findings: findings,
            operationIdentity: request.operationIdentity.uuidString,
            affectedRecordIdentities: affected,
            priorAcceptedStateRemainsUsable: rollbackResult != .uncertain,
            retrySafety: retrySafety,
            explicitReloadRequired: reloadResult == .failed || reloadResult == .foundConflictingEvidence,
            repairOrReviewRequired: review,
            workflowMayContinue: targetProven || disposition == .duplicateAlreadyApplied,
            allowanceOrEntitlementMustRemainUnchanged: true,
            saveCompletionProven: saveProven,
            resultUncertainBecauseSaveCompletionCannotBeProven: uncertain
        )
        return CanonicalScoringTransactionResult(
            transaction: transaction,
            operationIdentity: request.operationIdentity,
            gameIdentity: prepared?.gameIdentity,
            acceptedEventIdentity: prepared?.eventIdentity,
            correctionIdentity: request.correctionIdentity,
            targetEventIdentity: request.targetEventIdentity,
            commitSequence: existingCommitSequence,
            payloadFingerprint: prepared?.payloadFingerprint,
            requestFingerprint: requestFingerprint?.rawValue,
            validationFindings: findings.sorted { $0.code < $1.code },
            saveResult: saveResult,
            rollbackResult: rollbackResult,
            reloadResult: reloadResult,
            idempotencyResult: idempotency,
            routingRemainsDisabled: true,
            managedObjectsEscaped: false
        )
    }

    private func fetchGame(_ identity: UUID, in context: ModelContext) throws -> Game? {
        try context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.ident == identity })).first
    }

    private func fetchOrCreateHistory(gameIdentity: UUID, game: Game, in context: ModelContext) throws -> CanonicalGameHistoryRecord {
        if let existing = try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>(predicate: #Predicate { $0.gameIdentity == gameIdentity })).first {
            return existing
        }
        return CanonicalGameHistoryRecord(gameIdentity: gameIdentity, game: game)
    }

    private func fetchOperation(_ identity: UUID, in context: ModelContext) throws -> CanonicalScoringOperationEvidenceRecord? {
        try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>(predicate: #Predicate { $0.operationIdentity == identity })).first
    }

    private func fetchEvent(_ identity: UUID, in context: ModelContext) throws -> CanonicalScoringEventEnvelopeRecord? {
        try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>(predicate: #Predicate { $0.eventIdentity == identity })).first
    }

    private func fetchPayload(eventIdentity: UUID, in context: ModelContext) throws -> CanonicalScoringEventPayloadRecord? {
        try context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>(predicate: #Predicate { $0.eventIdentity == eventIdentity })).first
    }

    private func fetchCorrectionTargeting(_ eventIdentity: UUID, in context: ModelContext) throws -> [CanonicalScoringCorrectionRecord] {
        try context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>(predicate: #Predicate { $0.originalEventIdentity == eventIdentity }))
    }

    private func payloadValue(for event: CanonicalScoringEventEvidence) -> CanonicalScoringPayloadValue {
        CanonicalScoringPayloadValue(
            eventFamily: eventFamily(for: event.resultEvidence),
            gameIdentity: event.gameIdentity.validIdentifier ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            eventIdentity: event.eventIdentity.validIdentifier ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            teamSide: event.teamSide?.rawValue ?? "unresolved",
            result: resultString(for: event.resultEvidence),
            batterIdentity: event.participants.batter?.playerIdentity.validIdentifier,
            runnerIdentities: runnerIdentities(from: event),
            outsRecorded: event.outsEvidence?.outsRecordedByEvent,
            runsScored: markerCount(event.runsScored),
            rbi: markerCount(event.rbiEvidence),
            ambiguityCodes: ambiguityCodes(for: event),
            unsupportedRawEvidence: event.unsupportedRawLegacyEvidence
        )
    }

    private func eventFamily(for result: ScoringEventResultEvidence) -> String {
        switch result {
        case .batterReachesBase:
            return "batterReaches"
        case .batterOut:
            return "batterOut"
        case .runnerAdvances:
            return "runnerAdvances"
        case .runnerScores:
            return "runnerScores"
        case .runnerOut:
            return "runnerOut"
        case .placeholder:
            return "placeholder"
        case .unknownRawResult:
            return "unknown"
        case .unsupportedRawResult:
            return "unsupported"
        case .conflicting:
            return "conflicting"
        }
    }

    private func resultString(for result: ScoringEventResultEvidence) -> String {
        switch result {
        case let .batterReachesBase(rawValue), let .batterOut(rawValue), let .runnerAdvances(rawValue),
             let .runnerScores(rawValue), let .runnerOut(rawValue), let .placeholder(rawValue),
             let .unknownRawResult(rawValue), let .unsupportedRawResult(rawValue):
            return rawValue
        case let .conflicting(values):
            return values.map(resultString(for:)).sorted().joined(separator: "|")
        }
    }

    private func runnerIdentities(from event: CanonicalScoringEventEvidence) -> [UUID] {
        let states = event.participants.runners + event.runnerAdvancement + [event.batterAdvancement].compactMap { $0 }
        return states.compactMap { state in
            switch state {
            case let .activeOccupant(_, runner), let .scored(runner, _), let .out(runner, _),
                 let .batterRunner(runner), let .historicalRunner(runner, _):
                return runner.identity.validIdentifier
            case .ambiguousLegacyMaxBase, .ambiguousLegacyOutAt, .unsupportedLegacyValue, .contradictory:
                return nil
            }
        }
    }

    private func markerCount(_ marker: ScoringEventMarkerEvidence) -> Int? {
        switch marker {
        case let .count(value):
            return value
        case let .flag(value):
            return value ? 1 : 0
        case .notRepresented, .conflicting:
            return nil
        }
    }

    private func ambiguityCodes(for event: CanonicalScoringEventEvidence) -> [String] {
        var codes = event.participants.unresolvedRelationships
        if case .conflicting = event.runsScored { codes.append("runsScoredConflicting") }
        if case .conflicting = event.rbiEvidence { codes.append("rbiConflicting") }
        if event.teamSide == nil { codes.append("teamSideMissing") }
        return codes.sorted()
    }

    private func finding(
        _ code: String,
        concept: CanonicalValidationConcept = .scoringEvent,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String
    ) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: concept, severity: severity, disposition: disposition, summary: summary)
    }
}

private struct PreparedScoringTransaction {
    let event: CanonicalScoringEventEvidence
    let eventIdentity: UUID
    let gameIdentity: UUID
    let payloadValue: CanonicalScoringPayloadValue
    let payloadData: Data
    let payloadFingerprint: String
    let validation: CanonicalScoringCommandValidation
}

private struct PreparedScoringRecordGraph {
    let history: CanonicalGameHistoryRecord
    let operation: CanonicalScoringOperationEvidenceRecord
    let event: CanonicalScoringEventEnvelopeRecord
    let payload: CanonicalScoringEventPayloadRecord
    let correction: CanonicalScoringCorrectionRecord?
}

private struct CanonicalScoringTransactionPreparationError: Error {
    let finding: CanonicalValidationFinding
}

private enum CanonicalScoringTransactionInjectedSaveError: Error {
    case deterministicFailure
}
