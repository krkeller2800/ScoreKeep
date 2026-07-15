import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence save failure verification")
struct CanonicalPersistenceSaveFailureTests {
    @Test("successful and warning saves use transaction vocabulary")
    func successfulAndWarningSavesUseTransactionVocabulary() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let boundary = IsolatedPersistenceSaveBoundary()
        let warning = CanonicalDomainValidator.finding(
            "persistence.save.warning",
            concept: .game,
            severity: .warning,
            disposition: .validWithWarnings,
            summary: "Save completed with reviewable warning."
        )

        let success = boundary.apply(
            operationIdentity: "save-success",
            context: environment.context,
            affectedRecordIdentities: [PersistenceVerificationIDs.game.uuidString]
        ) {
            _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(
                into: environment.context,
                includeSecondEvent: false,
                includeSubstitution: false
            )
        }
        let warningSuccess = boundary.apply(
            operationIdentity: "save-warning",
            context: environment.context,
            warnings: [warning]
        ) {}

        #expect(success.disposition == .success)
        #expect(success.saveCompletionProven)
        #expect(success.workflowMayContinue)
        let gameCount = try environment.fetch(FetchDescriptor<Game>()).count

        #expect(warningSuccess.disposition == .successWithWarnings)
        #expect(warningSuccess.findings.map(\.code) == ["persistence.save.warning"])
        #expect(gameCount == 1)
    }

    @Test("validation rejection occurs before save and preserves isolated store")
    func validationRejectionOccursBeforeSaveAndPreservesIsolatedStore() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let boundary = IsolatedPersistenceSaveBoundary()
        let probe = IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 0, entitlementMarker: "unchanged")
        let finding = CanonicalDomainValidator.finding(
            "persistence.validation.relationship",
            concept: .game,
            severity: .rejection,
            disposition: .rejected,
            summary: "Relationship validation rejected the save."
        )

        let result = boundary.apply(
            operationIdentity: "validation-rejection",
            context: environment.context,
            validationFindings: [finding]
        ) {
            environment.context.insert(Team(ident: PersistenceVerificationIDs.homeTeam, name: "Should Not Insert", coach: "", details: ""))
        }

        #expect(result.disposition == .validationRejected)
        #expect(result.priorAcceptedStateRemainsUsable)
        let teamCount = try environment.fetch(FetchDescriptor<Team>()).count

        #expect(result.retryIsUnsafe)
        #expect(result.allowanceOrEntitlementMustRemainUnchanged)
        #expect(teamCount == 0)
        #expect(probe == IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 0, entitlementMarker: "unchanged"))
    }

    @Test("deterministic failed save preserves prior accepted state and unrelated records")
    func deterministicFailedSavePreservesPriorAcceptedStateAndUnrelatedRecords() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let successfulBoundary = IsolatedPersistenceSaveBoundary()
        let failingBoundary = IsolatedPersistenceSaveBoundary { _ in
            throw IsolatedPersistenceInjectedSaveError.deterministicFailure
        }
        let probeBefore = IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 1, entitlementMarker: "active-2026")

        let acceptedTeam = Team(ident: PersistenceVerificationIDs.homeTeam, name: "Accepted", coach: "", details: "")
        environment.context.insert(acceptedTeam)
        try environment.save()
        let acceptedBefore = try environment.fetch(FetchDescriptor<Team>()).map(\.ident)

        let result = failingBoundary.apply(operationIdentity: "failed-save", context: environment.context) {
            environment.context.insert(Team(ident: PersistenceVerificationIDs.visitingTeam, name: "Unaccepted", coach: "", details: ""))
        }
        environment.context.rollback()
        let retryResult = successfulBoundary.apply(operationIdentity: "safe-retry", context: environment.context) {}
        let acceptedAfter = try environment.fetch(FetchDescriptor<Team>()).map(\.ident)

        #expect(result.disposition == .saveFailed)
        #expect(result.resultUncertainBecauseSaveCompletionCannotBeProven)
        #expect(result.explicitReloadRequired)
        #expect(result.priorAcceptedStateRemainsUsable)
        #expect(result.allowanceOrEntitlementMustRemainUnchanged)
        #expect(acceptedBefore == acceptedAfter)
        #expect(acceptedAfter == [PersistenceVerificationIDs.homeTeam])
        #expect(probeBefore == IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 1, entitlementMarker: "active-2026"))
        #expect(retryResult.disposition == .success)
    }

    @Test("failure classifications include partial duplicate retry and boundary failures")
    func failureClassificationsIncludePartialDuplicateRetryAndBoundaryFailures() {
        let finding = CanonicalDomainValidator.finding(
            "persistence.boundary",
            concept: .ordering,
            severity: .repair,
            disposition: .repairRequired,
            summary: "Boundary requires review."
        )
        let partial = CanonicalPersistenceTransactionClassifier.partialOrUncertainOutcome([finding])
        let duplicate = CanonicalPersistenceTransactionClassifier.duplicateAlreadyApplied(operationIdentity: "same-operation")
        let stale = CanonicalPersistenceTransactionClassifier.staleProjection(operationIdentity: "reload-required")
        let safeRetry = CanonicalPersistenceTransactionClassifier.retrySafe(operationIdentity: "retry-safe")
        let unsafeRetry = CanonicalPersistenceTransactionClassifier.retryUnsafe(operationIdentity: "retry-unsafe")
        let relationship = CanonicalPersistenceTransactionClassifier.relationshipFailure([finding])
        let ordering = CanonicalPersistenceTransactionClassifier.orderingFailure([finding])
        let unsupported = CanonicalPersistenceTransactionClassifier.unsupported([finding])
        let contradictory = CanonicalPersistenceTransactionClassifier.contradictory([finding])
        let unresolved = CanonicalPersistenceTransactionClassifier.unresolved([finding])
        let interrupted = CanonicalPersistenceTransactionClassifier.interruptedOperation(operationIdentity: "interrupted")

        #expect(partial.disposition == .partialOrUncertainOutcome)
        #expect(partial.resultUncertainBecauseSaveCompletionCannotBeProven)
        #expect(duplicate.disposition == .duplicateAlreadyApplied)
        #expect(stale.explicitReloadRequired)
        #expect(safeRetry.retryIsSafe)
        #expect(unsafeRetry.retryIsUnsafe)
        #expect(relationship.disposition == .relationshipFailure)
        #expect(ordering.disposition == .orderingFailure)
        #expect(unsupported.disposition == .unsupported)
        #expect(contradictory.disposition == .contradictory)
        #expect(unresolved.disposition == .unresolved)
        let allKeepAllowanceAndEntitlementUnchanged = [partial, relationship, ordering, unsupported, contradictory, unresolved, interrupted]
            .allSatisfy { $0.allowanceOrEntitlementMustRemainUnchanged }

        #expect(interrupted.disposition == .interruptedOperation)
        #expect(allKeepAllowanceAndEntitlementUnchanged)
    }
}
