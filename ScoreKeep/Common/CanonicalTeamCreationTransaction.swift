import Foundation
import SwiftData

struct CanonicalTeamCreationRequestFingerprint: Hashable, Sendable {
    let operationIdentity: String
    let teamIdentity: UUID
    let teamName: String
    let coach: String
    let details: String
    let expectedDuplicatePolicy: CanonicalTeamCreationDuplicatePolicy
    let expectedSource: CanonicalTeamCreationSourceClassification

    init(request: CanonicalTeamCreationRequest) {
        operationIdentity = request.operationIdentity
        teamIdentity = request.teamIdentity
        teamName = request.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        coach = request.coach
        details = request.details
        expectedDuplicatePolicy = request.expectedDuplicatePolicy
        expectedSource = request.expectedSource
    }
}

enum CanonicalTeamCreationDuplicatePolicy: String, Hashable, Sendable {
    case rejectConflicts
    case allowMatchingExisting
}

enum CanonicalTeamCreationSourceClassification: String, Hashable, Sendable {
    case isolatedCandidateAdapter
    case productionRoute
    case importRoute
    case unknown
}

struct CanonicalTeamCreationPurchaseAllowanceProbe: Hashable, Sendable {
    let purchaseMarker: String
    let entitlementMarker: String
    let freeGameCreatesRemaining: Int
    let mlbDownloadUseCount: Int

    init(
        purchaseMarker: String,
        entitlementMarker: String,
        freeGameCreatesRemaining: Int,
        mlbDownloadUseCount: Int
    ) {
        self.purchaseMarker = purchaseMarker
        self.entitlementMarker = entitlementMarker
        self.freeGameCreatesRemaining = freeGameCreatesRemaining
        self.mlbDownloadUseCount = mlbDownloadUseCount
    }
}

struct CanonicalTeamCreationGateState: Hashable, Sendable {
    var schemaStateKnown: Bool
    var sourceStoreVersionKnown: Bool
    var migrationCompleted: Bool
    var migrationCompletionCertain: Bool
    var cutoverApprovalAbsent: Bool
    var oneWriterProofPresent: Bool
    var disablePathDefined: Bool
    var rollbackOrRecoveryPolicyResolved: Bool
    var purchaseSeparationVerified: Bool
    var allowanceBoundaryVerified: Bool

    static let readyForIsolatedAdapter = CanonicalTeamCreationGateState(
        schemaStateKnown: true,
        sourceStoreVersionKnown: true,
        migrationCompleted: true,
        migrationCompletionCertain: true,
        cutoverApprovalAbsent: true,
        oneWriterProofPresent: true,
        disablePathDefined: true,
        rollbackOrRecoveryPolicyResolved: true,
        purchaseSeparationVerified: true,
        allowanceBoundaryVerified: true
    )

    static let productionUnknown = CanonicalTeamCreationGateState(
        schemaStateKnown: false,
        sourceStoreVersionKnown: false,
        migrationCompleted: false,
        migrationCompletionCertain: false,
        cutoverApprovalAbsent: true,
        oneWriterProofPresent: false,
        disablePathDefined: false,
        rollbackOrRecoveryPolicyResolved: false,
        purchaseSeparationVerified: true,
        allowanceBoundaryVerified: true
    )

    static let readyForProductionSimpleTeamCreation = CanonicalTeamCreationGateState(
        schemaStateKnown: true,
        sourceStoreVersionKnown: true,
        migrationCompleted: true,
        migrationCompletionCertain: true,
        cutoverApprovalAbsent: false,
        oneWriterProofPresent: true,
        disablePathDefined: true,
        rollbackOrRecoveryPolicyResolved: true,
        purchaseSeparationVerified: true,
        allowanceBoundaryVerified: true
    )
}

struct CanonicalTeamCreationRequest: Hashable, Sendable {
    let operationIdentity: String
    let teamIdentity: UUID
    let teamName: String
    let coach: String
    let details: String
    let expectedDuplicatePolicy: CanonicalTeamCreationDuplicatePolicy
    let expectedSource: CanonicalTeamCreationSourceClassification
    let knownInvocationFingerprints: [String: CanonicalTeamCreationRequestFingerprint]
    let unsupportedEvidenceFields: [String]
    let beforeProbe: CanonicalTeamCreationPurchaseAllowanceProbe
    let afterProbe: CanonicalTeamCreationPurchaseAllowanceProbe
    let gateState: CanonicalTeamCreationGateState

    init(
        operationIdentity: String,
        teamIdentity: UUID,
        teamName: String,
        coach: String = "",
        details: String = "",
        expectedDuplicatePolicy: CanonicalTeamCreationDuplicatePolicy = .rejectConflicts,
        expectedSource: CanonicalTeamCreationSourceClassification = .isolatedCandidateAdapter,
        knownInvocationFingerprints: [String: CanonicalTeamCreationRequestFingerprint] = [:],
        unsupportedEvidenceFields: [String] = [],
        beforeProbe: CanonicalTeamCreationPurchaseAllowanceProbe,
        afterProbe: CanonicalTeamCreationPurchaseAllowanceProbe,
        gateState: CanonicalTeamCreationGateState
    ) {
        self.operationIdentity = operationIdentity
        self.teamIdentity = teamIdentity
        self.teamName = teamName
        self.coach = coach
        self.details = details
        self.expectedDuplicatePolicy = expectedDuplicatePolicy
        self.expectedSource = expectedSource
        self.knownInvocationFingerprints = knownInvocationFingerprints
        self.unsupportedEvidenceFields = unsupportedEvidenceFields.sorted()
        self.beforeProbe = beforeProbe
        self.afterProbe = afterProbe
        self.gateState = gateState
    }
}

enum CanonicalTeamCreationSaveResult: String, Hashable, Sendable {
    case notAttempted
    case succeeded
    case succeededWithWarnings
    case failed
    case completionUncertain
}

enum CanonicalTeamCreationRollbackResult: String, Hashable, Sendable {
    case notRequired
    case notAttemptedUnsafeIncomingContext
    case completed
    case uncertain
}

enum CanonicalTeamCreationReloadResult: String, Hashable, Sendable {
    case notRequired
    case required
    case succeeded
    case failed
}

enum CanonicalTeamCreationSemanticVerificationResult: String, Hashable, Sendable {
    case notAttempted
    case succeeded
    case failed
}

enum CanonicalTeamCreationIdempotencyResult: String, Hashable, Sendable {
    case firstInvocation
    case exactRepeatAlreadyApplied
    case matchingExistingDifferentOperation
    case conflictingOperationIdentity
    case duplicateTeamIdentityConflictingMeaning
    case duplicateLookupFailed
}

struct CanonicalTeamCreationTransactionResult: Hashable, Sendable {
    let operationIdentity: String
    let teamIdentity: UUID
    let transaction: CanonicalPersistenceTransactionResult
    let validationFindings: [CanonicalValidationFinding]
    let saveResult: CanonicalTeamCreationSaveResult
    let rollbackResult: CanonicalTeamCreationRollbackResult
    let reloadResult: CanonicalTeamCreationReloadResult
    let semanticVerificationResult: CanonicalTeamCreationSemanticVerificationResult
    let idempotencyResult: CanonicalTeamCreationIdempotencyResult
    let affectedRecordIdentities: [String]
    let priorAcceptedStateRemainsUsable: Bool
    let targetStateProven: Bool
    let retryIsSafe: Bool
    let reviewRequired: Bool
    let routingRemainsDisabled: Bool
    let purchaseAllowanceSeparationFindings: [CanonicalValidationFinding]
}

enum CanonicalTeamCreationInjectedFailure: Hashable, Sendable {
    case insertPreparation
    case duplicateLookup
    case save
    case completionUncertain
    case rollbackUncertain
    case reload
    case semanticVerification
    case purchaseSeparation
    case allowanceBoundary
}

struct CanonicalTeamCreationTransactionDependencies {
    var injectedFailures: Set<CanonicalTeamCreationInjectedFailure>
    var save: @MainActor (ModelContext) throws -> Void
    var rollback: @MainActor (ModelContext) -> Void
    var makeReloadContext: @MainActor (ModelContainer) -> ModelContext

    init(
        injectedFailures: Set<CanonicalTeamCreationInjectedFailure> = [],
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
struct CanonicalTeamCreationTransactionAdapter {
    private let container: ModelContainer
    private let dependencies: CanonicalTeamCreationTransactionDependencies

    init(container: ModelContainer, dependencies: CanonicalTeamCreationTransactionDependencies = CanonicalTeamCreationTransactionDependencies()) {
        self.container = container
        self.dependencies = dependencies
    }

    func applyUsingDedicatedOperationContext(_ request: CanonicalTeamCreationRequest) -> CanonicalTeamCreationTransactionResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return apply(request, in: context)
    }

    func apply(_ request: CanonicalTeamCreationRequest, in context: ModelContext) -> CanonicalTeamCreationTransactionResult {
        let requestFingerprint = CanonicalTeamCreationRequestFingerprint(request: request)
        var findings = validate(request, context: context, requestFingerprint: requestFingerprint)
        let separationFindings = purchaseAllowanceFindings(request)
        findings.append(contentsOf: separationFindings)

        guard findings.isEmpty else {
            return result(
                request: request,
                disposition: .validationRejected,
                findings: findings,
                saveResult: .notAttempted,
                rollbackResult: context.hasChanges ? .notAttemptedUnsafeIncomingContext : .notRequired,
                reloadResult: .notRequired,
                verificationResult: .notAttempted,
                idempotencyResult: idempotencyForValidation(request, requestFingerprint: requestFingerprint),
                affected: [],
                priorUsable: true,
                retrySafety: .unsafe,
                targetProven: false,
                review: true,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        if dependencies.injectedFailures.contains(.duplicateLookup) {
            let duplicateFinding = finding(
                "teamCreation.duplicateLookup.failed",
                severity: .unresolved,
                disposition: .unresolved,
                summary: "Duplicate team lookup failed before insertion."
            )
            return result(
                request: request,
                disposition: .unresolved,
                findings: [duplicateFinding],
                saveResult: .notAttempted,
                rollbackResult: .notRequired,
                reloadResult: .notRequired,
                verificationResult: .notAttempted,
                idempotencyResult: .duplicateLookupFailed,
                affected: [],
                priorUsable: true,
                retrySafety: .unsafe,
                targetProven: false,
                review: true,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        let existingTeams: [Team]
        do {
            existingTeams = try fetchTeams(with: request.teamIdentity, in: context)
        } catch {
            return lookupFailureResult(request, separationFindings: separationFindings)
        }

        if let duplicateResult = classifyExistingTeams(existingTeams, request: request, requestFingerprint: requestFingerprint, separationFindings: separationFindings) {
            return duplicateResult
        }

        if dependencies.injectedFailures.contains(.insertPreparation) {
            let insertFinding = finding(
                "teamCreation.insertPreparation.failed",
                severity: .rejection,
                disposition: .rejected,
                summary: "Team insert preparation failed before persistence."
            )
            return result(
                request: request,
                disposition: .validationRejected,
                findings: [insertFinding],
                saveResult: .notAttempted,
                rollbackResult: .notRequired,
                reloadResult: .notRequired,
                verificationResult: .notAttempted,
                idempotencyResult: .firstInvocation,
                affected: [],
                priorUsable: true,
                retrySafety: .safe,
                targetProven: false,
                review: false,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        let team = Team(
            ident: request.teamIdentity,
            name: request.teamName.trimmingCharacters(in: .whitespacesAndNewlines),
            coach: request.coach,
            details: request.details,
            players: [],
            games: [],
            logo: nil
        )
        context.insert(team)

        if dependencies.injectedFailures.contains(.completionUncertain) {
            return rollbackAfterUncertainSave(request: request, context: context, separationFindings: separationFindings)
        }

        do {
            if dependencies.injectedFailures.contains(.save) {
                throw CanonicalTeamCreationInjectedSaveError.deterministicFailure
            }
            try dependencies.save(context)
        } catch {
            return rollbackAfterFailedSave(request: request, context: context, separationFindings: separationFindings)
        }

        if dependencies.injectedFailures.contains(.reload) {
            let reloadFinding = finding(
                "teamCreation.reload.failed",
                severity: .repair,
                disposition: .repairRequired,
                summary: "Fresh reload failed after save."
            )
            return result(
                request: request,
                disposition: .staleProjection,
                findings: [reloadFinding],
                saveResult: .succeeded,
                rollbackResult: .notRequired,
                reloadResult: .failed,
                verificationResult: .notAttempted,
                idempotencyResult: .firstInvocation,
                affected: [request.teamIdentity.uuidString],
                priorUsable: true,
                retrySafety: .unsafe,
                targetProven: false,
                review: true,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        let reloadContext = dependencies.makeReloadContext(container)
        reloadContext.autosaveEnabled = false
        let reloadedTeams: [Team]
        do {
            reloadedTeams = try fetchTeams(with: request.teamIdentity, in: reloadContext)
        } catch {
            let reloadFinding = finding(
                "teamCreation.reload.fetchFailed",
                severity: .repair,
                disposition: .repairRequired,
                summary: "Fresh reload could not fetch the persisted team."
            )
            return result(
                request: request,
                disposition: .staleProjection,
                findings: [reloadFinding],
                saveResult: .succeeded,
                rollbackResult: .notRequired,
                reloadResult: .failed,
                verificationResult: .notAttempted,
                idempotencyResult: .firstInvocation,
                affected: [request.teamIdentity.uuidString],
                priorUsable: true,
                retrySafety: .unsafe,
                targetProven: false,
                review: true,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        let verification = verifyReloadedTeams(reloadedTeams, request: request)
        if dependencies.injectedFailures.contains(.semanticVerification) || verification.futureWriteMustStop {
            let semanticFinding = verification.findings.isEmpty
                ? finding("teamCreation.semanticVerification.failed", severity: .contradiction, disposition: .contradictory, summary: "Persisted team semantic verification failed.")
                : verification.findings[0]
            return result(
                request: request,
                disposition: .contradictory,
                findings: [semanticFinding],
                saveResult: .succeeded,
                rollbackResult: .notRequired,
                reloadResult: .succeeded,
                verificationResult: .failed,
                idempotencyResult: .firstInvocation,
                affected: [request.teamIdentity.uuidString],
                priorUsable: true,
                retrySafety: .unsafe,
                targetProven: false,
                review: true,
                saveProven: true,
                uncertain: false,
                separationFindings: separationFindings
            )
        }

        return result(
            request: request,
            disposition: .success,
            findings: [],
            saveResult: .succeeded,
            rollbackResult: .notRequired,
            reloadResult: .succeeded,
            verificationResult: .succeeded,
            idempotencyResult: .firstInvocation,
            affected: [request.teamIdentity.uuidString],
            priorUsable: true,
            retrySafety: .notNeeded,
            targetProven: true,
            review: false,
            saveProven: true,
            uncertain: false,
            separationFindings: separationFindings
        )
    }

    private func validate(
        _ request: CanonicalTeamCreationRequest,
        context: ModelContext,
        requestFingerprint: CanonicalTeamCreationRequestFingerprint
    ) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []

        if request.operationIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(finding("teamCreation.operationIdentity.missing", severity: .rejection, disposition: .rejected, summary: "Team creation requires a stable operation identity."))
        }
        if request.teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(finding("teamCreation.name.missing", severity: .rejection, disposition: .rejected, summary: "Team creation requires a non-empty team name."))
        }
        if context.hasChanges {
            findings.append(finding("teamCreation.context.dirty", severity: .rejection, disposition: .rejected, summary: "The supplied transaction context has unrelated pending changes."))
        }
        if !request.unsupportedEvidenceFields.isEmpty {
            findings.append(finding("teamCreation.unsupportedEvidence", severity: .rejection, disposition: .rejected, summary: "Unsupported team creation evidence was supplied: \(request.unsupportedEvidenceFields.joined(separator: ", "))."))
        }
        switch request.expectedSource {
        case .isolatedCandidateAdapter:
            if !request.gateState.cutoverApprovalAbsent {
                findings.append(finding("teamCreation.gate.routingApprovalPresent", severity: .rejection, disposition: .rejected, summary: "The isolated adapter path cannot run with production routing approval."))
            }
        case .productionRoute:
            if request.gateState.cutoverApprovalAbsent {
                findings.append(finding("teamCreation.gate.routingApprovalMissing", severity: .rejection, disposition: .rejected, summary: "The production route requires explicit routing approval."))
            }
        case .importRoute, .unknown:
            findings.append(finding("teamCreation.source.unsupported", severity: .rejection, disposition: .rejected, summary: "This team creation source is not supported by the simple-team transaction adapter."))
        }
        if let knownFingerprint = request.knownInvocationFingerprints[request.operationIdentity], knownFingerprint != requestFingerprint {
            findings.append(finding("teamCreation.operationIdentity.conflict", severity: .contradiction, disposition: .contradictory, summary: "The operation identity has already been used for conflicting team creation evidence."))
        }

        let gateFindings = gateFindings(for: request.gateState)
        findings.append(contentsOf: gateFindings)

        let canonicalTeam = canonicalTeam(from: request)
        findings.append(contentsOf: CanonicalDomainValidator.validateTeam(canonicalTeam).findings)

        return findings.sorted { lhs, rhs in lhs.code == rhs.code ? lhs.summary < rhs.summary : lhs.code < rhs.code }
    }

    private func gateFindings(for gates: CanonicalTeamCreationGateState) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        if !gates.schemaStateKnown {
            findings.append(finding("teamCreation.gate.schemaUnknown", severity: .rejection, disposition: .rejected, summary: "Production schema readiness is unknown."))
        }
        if !gates.sourceStoreVersionKnown {
            findings.append(finding("teamCreation.gate.sourceVersionUnknown", severity: .rejection, disposition: .rejected, summary: "Source-store version is unknown."))
        }
        if !gates.migrationCompleted {
            findings.append(finding("teamCreation.gate.migrationIncomplete", severity: .rejection, disposition: .rejected, summary: "Migration status is incomplete."))
        }
        if !gates.migrationCompletionCertain {
            findings.append(finding("teamCreation.gate.migrationUncertain", severity: .rejection, disposition: .rejected, summary: "Migration completion is uncertain."))
        }
        if !gates.oneWriterProofPresent {
            findings.append(finding("teamCreation.gate.oneWriterMissing", severity: .rejection, disposition: .rejected, summary: "One-writer proof is absent."))
        }
        if !gates.disablePathDefined {
            findings.append(finding("teamCreation.gate.disablePathMissing", severity: .rejection, disposition: .rejected, summary: "Disable path is undefined."))
        }
        if !gates.rollbackOrRecoveryPolicyResolved {
            findings.append(finding("teamCreation.gate.rollbackPolicyMissing", severity: .rejection, disposition: .rejected, summary: "Rollback or recovery policy is unresolved."))
        }
        if !gates.purchaseSeparationVerified {
            findings.append(finding("teamCreation.gate.purchaseSeparationFailed", severity: .rejection, disposition: .rejected, summary: "Purchase separation verification failed."))
        }
        if !gates.allowanceBoundaryVerified {
            findings.append(finding("teamCreation.gate.allowanceBoundaryFailed", severity: .rejection, disposition: .rejected, summary: "Allowance boundary verification failed."))
        }
        return findings
    }

    private func purchaseAllowanceFindings(_ request: CanonicalTeamCreationRequest) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        if request.beforeProbe != request.afterProbe || dependencies.injectedFailures.contains(.purchaseSeparation) {
            findings.append(finding("teamCreation.purchaseSeparation.changed", severity: .rejection, disposition: .rejected, summary: "Purchase or entitlement probe changed during team creation."))
        }
        if request.beforeProbe.freeGameCreatesRemaining != request.afterProbe.freeGameCreatesRemaining
            || request.beforeProbe.mlbDownloadUseCount != request.afterProbe.mlbDownloadUseCount
            || dependencies.injectedFailures.contains(.allowanceBoundary) {
            findings.append(finding("teamCreation.allowanceBoundary.changed", severity: .rejection, disposition: .rejected, summary: "Allowance probe changed during team creation."))
        }
        return findings
    }

    private func classifyExistingTeams(
        _ existingTeams: [Team],
        request: CanonicalTeamCreationRequest,
        requestFingerprint: CanonicalTeamCreationRequestFingerprint,
        separationFindings: [CanonicalValidationFinding]
    ) -> CanonicalTeamCreationTransactionResult? {
        guard !existingTeams.isEmpty else { return nil }

        if existingTeams.count != 1 {
            let duplicateFinding = finding("teamCreation.teamIdentity.duplicateRecords", severity: .contradiction, disposition: .contradictory, summary: "More than one persisted team has the requested identity.")
            return result(request: request, disposition: .contradictory, findings: [duplicateFinding], saveResult: .notAttempted, rollbackResult: .notRequired, reloadResult: .notRequired, verificationResult: .failed, idempotencyResult: .duplicateTeamIdentityConflictingMeaning, affected: existingTeams.map { $0.ident.uuidString }, priorUsable: true, retrySafety: .unsafe, targetProven: false, review: true, saveProven: true, uncertain: false, separationFindings: separationFindings)
        }

        let existing = existingTeams[0]
        let matches = team(existing, matches: request)
        let known = request.knownInvocationFingerprints[request.operationIdentity]
        if known == requestFingerprint && matches {
            return result(request: request, disposition: .duplicateAlreadyApplied, findings: [], saveResult: .notAttempted, rollbackResult: .notRequired, reloadResult: .succeeded, verificationResult: .succeeded, idempotencyResult: .exactRepeatAlreadyApplied, affected: [request.teamIdentity.uuidString], priorUsable: true, retrySafety: .notNeeded, targetProven: true, review: false, saveProven: true, uncertain: false, separationFindings: separationFindings)
        }
        if matches {
            return result(request: request, disposition: .duplicateAlreadyApplied, findings: [], saveResult: .notAttempted, rollbackResult: .notRequired, reloadResult: .succeeded, verificationResult: .succeeded, idempotencyResult: .matchingExistingDifferentOperation, affected: [request.teamIdentity.uuidString], priorUsable: true, retrySafety: .notNeeded, targetProven: true, review: false, saveProven: true, uncertain: false, separationFindings: separationFindings)
        }

        let conflictFinding = finding("teamCreation.teamIdentity.conflictingMeaning", severity: .contradiction, disposition: .contradictory, summary: "A persisted team with the same identity has conflicting supported meaning.")
        return result(request: request, disposition: .contradictory, findings: [conflictFinding], saveResult: .notAttempted, rollbackResult: .notRequired, reloadResult: .succeeded, verificationResult: .failed, idempotencyResult: .duplicateTeamIdentityConflictingMeaning, affected: [request.teamIdentity.uuidString], priorUsable: true, retrySafety: .unsafe, targetProven: false, review: true, saveProven: true, uncertain: false, separationFindings: separationFindings)
    }

    private func rollbackAfterFailedSave(
        request: CanonicalTeamCreationRequest,
        context: ModelContext,
        separationFindings: [CanonicalValidationFinding]
    ) -> CanonicalTeamCreationTransactionResult {
        let rollbackResult: CanonicalTeamCreationRollbackResult
        if dependencies.injectedFailures.contains(.rollbackUncertain) {
            rollbackResult = .uncertain
        } else {
            dependencies.rollback(context)
            rollbackResult = .completed
        }
        let saveFinding = finding("teamCreation.save.failed", severity: .rejection, disposition: .rejected, summary: "Team creation save failed before completion was proven.")
        return result(
            request: request,
            disposition: .saveFailed,
            findings: [saveFinding],
            saveResult: .failed,
            rollbackResult: rollbackResult,
            reloadResult: .required,
            verificationResult: .notAttempted,
            idempotencyResult: .firstInvocation,
            affected: [],
            priorUsable: rollbackResult == .completed,
            retrySafety: rollbackResult == .completed ? .safe : .unknown,
            targetProven: false,
            review: rollbackResult != .completed,
            saveProven: false,
            uncertain: true,
            separationFindings: separationFindings
        )
    }

    private func rollbackAfterUncertainSave(
        request: CanonicalTeamCreationRequest,
        context: ModelContext,
        separationFindings: [CanonicalValidationFinding]
    ) -> CanonicalTeamCreationTransactionResult {
        let rollbackResult: CanonicalTeamCreationRollbackResult
        if dependencies.injectedFailures.contains(.rollbackUncertain) {
            rollbackResult = .uncertain
        } else {
            dependencies.rollback(context)
            rollbackResult = .completed
        }
        let uncertainFinding = finding("teamCreation.save.completionUncertain", severity: .unresolved, disposition: .unresolved, summary: "Team creation save completion cannot be proven.")
        return result(
            request: request,
            disposition: .partialOrUncertainOutcome,
            findings: [uncertainFinding],
            saveResult: .completionUncertain,
            rollbackResult: rollbackResult,
            reloadResult: .required,
            verificationResult: .notAttempted,
            idempotencyResult: .firstInvocation,
            affected: [request.teamIdentity.uuidString],
            priorUsable: rollbackResult == .completed,
            retrySafety: .unknown,
            targetProven: false,
            review: true,
            saveProven: false,
            uncertain: true,
            separationFindings: separationFindings
        )
    }

    private func lookupFailureResult(
        _ request: CanonicalTeamCreationRequest,
        separationFindings: [CanonicalValidationFinding]
    ) -> CanonicalTeamCreationTransactionResult {
        let duplicateFinding = finding("teamCreation.duplicateLookup.fetchFailed", severity: .unresolved, disposition: .unresolved, summary: "Duplicate team lookup could not be completed.")
        return result(request: request, disposition: .unresolved, findings: [duplicateFinding], saveResult: .notAttempted, rollbackResult: .notRequired, reloadResult: .notRequired, verificationResult: .notAttempted, idempotencyResult: .duplicateLookupFailed, affected: [], priorUsable: true, retrySafety: .unsafe, targetProven: false, review: true, saveProven: true, uncertain: false, separationFindings: separationFindings)
    }

    private func verifyReloadedTeams(_ teams: [Team], request: CanonicalTeamCreationRequest) -> CanonicalValidationResult {
        guard teams.count == 1 else {
            return CanonicalValidationResult(findings: [finding("teamCreation.reload.countMismatch", severity: .contradiction, disposition: .contradictory, summary: "Fresh reload did not find exactly one matching team.")])
        }
        guard team(teams[0], matches: request) else {
            return CanonicalValidationResult(findings: [finding("teamCreation.reload.semanticMismatch", severity: .contradiction, disposition: .contradictory, summary: "Freshly reloaded team does not match supported canonical meaning.")])
        }
        let interpretation = CanonicalPersistedEvidenceInterpreter.interpretTeam(LegacyTeamEvidenceSnapshot(team: teams[0]))
        if interpretation.futureWriteMustStop || interpretation.canonicalValue?.identity != .valid(request.teamIdentity) {
            return CanonicalValidationResult(findings: [finding("teamCreation.reload.interpretationFailed", severity: .contradiction, disposition: .contradictory, summary: "Persisted-to-canonical interpretation did not prove team identity.")])
        }
        return .valid
    }

    private func idempotencyForValidation(
        _ request: CanonicalTeamCreationRequest,
        requestFingerprint: CanonicalTeamCreationRequestFingerprint
    ) -> CanonicalTeamCreationIdempotencyResult {
        if let known = request.knownInvocationFingerprints[request.operationIdentity], known != requestFingerprint {
            return .conflictingOperationIdentity
        }
        return .firstInvocation
    }

    private func canonicalTeam(from request: CanonicalTeamCreationRequest) -> ReusableCanonicalTeam {
        ReusableCanonicalTeam(
            identity: .valid(request.teamIdentity),
            display: TeamDisplayEvidence(
                name: .present(request.teamName.trimmingCharacters(in: .whitespacesAndNewlines)),
                coach: .present(request.coach),
                details: .present(request.details),
                logo: .missing
            ),
            rosterEvidence: .notRepresented,
            source: .currentReusableRecord
        )
    }

    private func team(_ team: Team, matches request: CanonicalTeamCreationRequest) -> Bool {
        team.ident == request.teamIdentity
        && team.name == request.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        && team.coach == request.coach
        && team.details == request.details
        && team.logo == nil
        && team.players.isEmpty
        && team.games.isEmpty
    }

    private func fetchTeams(with identity: UUID, in context: ModelContext) throws -> [Team] {
        let descriptor = FetchDescriptor<Team>(predicate: #Predicate { team in
            team.ident == identity
        })
        return try context.fetch(descriptor)
    }

    private func result(
        request: CanonicalTeamCreationRequest,
        disposition: CanonicalPersistenceTransactionDisposition,
        findings: [CanonicalValidationFinding],
        saveResult: CanonicalTeamCreationSaveResult,
        rollbackResult: CanonicalTeamCreationRollbackResult,
        reloadResult: CanonicalTeamCreationReloadResult,
        verificationResult: CanonicalTeamCreationSemanticVerificationResult,
        idempotencyResult: CanonicalTeamCreationIdempotencyResult,
        affected: [String],
        priorUsable: Bool,
        retrySafety: CanonicalPersistenceRetrySafety,
        targetProven: Bool,
        review: Bool,
        saveProven: Bool,
        uncertain: Bool,
        separationFindings: [CanonicalValidationFinding]
    ) -> CanonicalTeamCreationTransactionResult {
        let allFindings = (findings + separationFindings).sorted { lhs, rhs in
            lhs.code == rhs.code ? lhs.summary < rhs.summary : lhs.code < rhs.code
        }
        let transaction = CanonicalPersistenceTransactionResult(
            disposition: disposition,
            findings: allFindings,
            operationIdentity: request.operationIdentity,
            affectedRecordIdentities: affected,
            priorAcceptedStateRemainsUsable: priorUsable,
            retrySafety: retrySafety,
            explicitReloadRequired: reloadResult == .required || reloadResult == .failed,
            repairOrReviewRequired: review,
            workflowMayContinue: targetProven || disposition == .duplicateAlreadyApplied || disposition == .noChange,
            allowanceOrEntitlementMustRemainUnchanged: true,
            saveCompletionProven: saveProven,
            resultUncertainBecauseSaveCompletionCannotBeProven: uncertain
        )
        return CanonicalTeamCreationTransactionResult(
            operationIdentity: request.operationIdentity,
            teamIdentity: request.teamIdentity,
            transaction: transaction,
            validationFindings: allFindings,
            saveResult: saveResult,
            rollbackResult: rollbackResult,
            reloadResult: reloadResult,
            semanticVerificationResult: verificationResult,
            idempotencyResult: idempotencyResult,
            affectedRecordIdentities: affected.sorted(),
            priorAcceptedStateRemainsUsable: priorUsable,
            targetStateProven: targetProven,
            retryIsSafe: retrySafety == .safe,
            reviewRequired: review,
            routingRemainsDisabled: true,
            purchaseAllowanceSeparationFindings: separationFindings
        )
    }

    private func finding(
        _ code: String,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String
    ) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(
            code,
            concept: .team,
            severity: severity,
            disposition: disposition,
            summary: summary
        )
    }
}

enum CanonicalTeamCreationInjectedSaveError: Error {
    case deterministicFailure
}
