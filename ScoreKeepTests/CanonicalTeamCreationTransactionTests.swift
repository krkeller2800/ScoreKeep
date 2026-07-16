import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical team creation transaction adapter verification")
struct CanonicalTeamCreationTransactionTests {
    @Test("valid request passes shallow validation without persistence")
    func validRequestPassesShallowValidationWithoutPersistence() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.insertPreparation]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.map(\.code) == ["teamCreation.insertPreparation.failed"])
        #expect(result.saveResult == .notAttempted)
        #expect(try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container).teams.isEmpty)
    }

    @Test("missing identity evidence is rejected before save")
    func missingIdentityEvidenceIsRejectedBeforeSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request(operationIdentity: "")
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.operationIdentity.missing" })
        #expect(result.saveResult == .notAttempted)
    }

    @Test("missing team name is rejected before save")
    func missingTeamNameIsRejectedBeforeSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request(teamName: "  ")
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.name.missing" })
        #expect(result.saveResult == .notAttempted)
    }

    @Test("unsupported request field is rejected before save")
    func unsupportedRequestFieldIsRejectedBeforeSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request(unsupportedEvidenceFields: ["logo", "players"])
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.unsupportedEvidence" })
        #expect(try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container).teams.isEmpty)
    }

    @Test("gate failures reject before save")
    func gateFailuresRejectBeforeSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request(gateState: .productionUnknown)
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)
        let codes = Set(result.validationFindings.map(\.code))

        #expect(result.transaction.disposition == .validationRejected)
        #expect(codes.contains("teamCreation.gate.schemaUnknown"))
        #expect(codes.contains("teamCreation.gate.sourceVersionUnknown"))
        #expect(codes.contains("teamCreation.gate.migrationIncomplete"))
        #expect(codes.contains("teamCreation.gate.migrationUncertain"))
        #expect(codes.contains("teamCreation.gate.oneWriterMissing"))
        #expect(codes.contains("teamCreation.gate.disablePathMissing"))
        #expect(codes.contains("teamCreation.gate.rollbackPolicyMissing"))
        #expect(result.saveResult == .notAttempted)
    }

    @Test("cutover approval present keeps isolated adapter non-routed")
    func cutoverApprovalPresentKeepsIsolatedAdapterNonRouted() throws {
        let environment = try IsolatedPersistenceEnvironment()
        var gates = CanonicalTeamCreationGateState.readyForIsolatedAdapter
        gates.cutoverApprovalAbsent = false
        let request = IsolatedTeamCreationTransactionSupport.request(gateState: gates)
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.gate.routingApprovalPresent" })
        #expect(result.routingRemainsDisabled)
    }

    @Test("dirty context is rejected without rollback")
    func dirtyContextIsRejectedWithoutRollback() throws {
        let environment = try IsolatedPersistenceEnvironment()
        environment.context.insert(Team(ident: TeamCreationTransactionVerificationIDs.unrelatedTeam, name: "Pending", coach: "", details: ""))
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.context.dirty" })
        #expect(result.rollbackResult == .notAttemptedUnsafeIncomingContext)
        #expect(environment.context.hasChanges)
    }

    @Test("purchase and allowance probe failures reject before save")
    func purchaseAndAllowanceProbeFailuresRejectBeforeSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let changedProbe = CanonicalTeamCreationPurchaseAllowanceProbe(
            purchaseMarker: "changed",
            entitlementMarker: "changed",
            freeGameCreatesRemaining: 1,
            mlbDownloadUseCount: 1
        )
        let request = IsolatedTeamCreationTransactionSupport.request(afterProbe: changedProbe)
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)
        let codes = Set(result.validationFindings.map(\.code))

        #expect(result.transaction.disposition == .validationRejected)
        #expect(codes.contains("teamCreation.purchaseSeparation.changed"))
        #expect(codes.contains("teamCreation.allowanceBoundary.changed"))
        #expect(result.saveResult == .notAttempted)
    }

    @Test("one team is inserted saved reloaded and semantically verified")
    func oneTeamIsInsertedSavedReloadedAndSemanticallyVerified() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedTeamCreationTransactionSupport.insertUnrelatedGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)
        let request = IsolatedTeamCreationTransactionSupport.request()

        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)
        let after = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(result.transaction.disposition == .success)
        #expect(result.saveResult == .succeeded)
        #expect(result.reloadResult == .succeeded)
        #expect(result.semanticVerificationResult == .succeeded)
        #expect(result.targetStateProven)
        #expect(result.affectedRecordIdentities == [request.teamIdentity.uuidString])
        #expect(result.routingRemainsDisabled)
        IsolatedTeamCreationTransactionSupport.assertOnlyCreatedTeamChanged(before: before, after: after, request: request)
    }

    @Test("dedicated operation context ignores environment context and disables autosave")
    func dedicatedOperationContextIgnoresEnvironmentContextAndDisablesAutosave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        environment.context.insert(Team(ident: TeamCreationTransactionVerificationIDs.unrelatedTeam, name: "Pending", coach: "", details: ""))
        let request = IsolatedTeamCreationTransactionSupport.request()
        var saveSawAutosaveDisabled = false
        var saveUsedEnvironmentContext = false
        var reloadContext: ModelContext?
        let dependencies = CanonicalTeamCreationTransactionDependencies(
            save: { context in
                saveSawAutosaveDisabled = context.autosaveEnabled == false
                saveUsedEnvironmentContext = context === environment.context
                try context.save()
            },
            makeReloadContext: { container in
                let context = ModelContext(container)
                reloadContext = context
                return context
            }
        )
        let adapter = CanonicalTeamCreationTransactionAdapter(container: environment.container, dependencies: dependencies)

        let result = adapter.applyUsingDedicatedOperationContext(request)
        let snapshot = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(result.transaction.disposition == .success)
        #expect(saveSawAutosaveDisabled)
        #expect(saveUsedEnvironmentContext == false)
        #expect(reloadContext?.autosaveEnabled == false)
        #expect(environment.context.hasChanges)
        #expect(snapshot.teams[request.teamIdentity]?.name == request.teamName)
    }

    @Test("result is deterministic for equivalent isolated successes")
    func resultIsDeterministicForEquivalentIsolatedSuccesses() throws {
        let firstEnvironment = try IsolatedPersistenceEnvironment()
        let secondEnvironment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()

        let first = IsolatedTeamCreationTransactionSupport.adapter(for: firstEnvironment).apply(request, in: firstEnvironment.context)
        let second = IsolatedTeamCreationTransactionSupport.adapter(for: secondEnvironment).apply(request, in: secondEnvironment.context)

        #expect(first == second)
    }

    @Test("exact repeat creates no duplicate")
    func exactRepeatCreatesNoDuplicate() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let adapter = IsolatedTeamCreationTransactionSupport.adapter(for: environment)

        let first = adapter.apply(request, in: environment.context)
        let known = [request.operationIdentity: CanonicalTeamCreationRequestFingerprint(request: request)]
        let repeatRequest = IsolatedTeamCreationTransactionSupport.request(knownInvocationFingerprints: known)
        let second = adapter.apply(repeatRequest, in: ModelContext(environment.container))
        let snapshot = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(first.transaction.disposition == .success)
        #expect(second.transaction.disposition == .duplicateAlreadyApplied)
        #expect(second.idempotencyResult == .exactRepeatAlreadyApplied)
        #expect(snapshot.teams.keys.filter { $0 == request.teamIdentity }.count == 1)
    }

    @Test("matching existing team with different operation creates no duplicate")
    func matchingExistingTeamWithDifferentOperationCreatesNoDuplicate() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        IsolatedTeamCreationTransactionSupport.insertExistingMatchingTeam(request, into: environment.context)
        try environment.save()

        let differentOperation = IsolatedTeamCreationTransactionSupport.request(operationIdentity: "team-create-op-002")
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(differentOperation, in: ModelContext(environment.container))
        let snapshot = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(result.transaction.disposition == .duplicateAlreadyApplied)
        #expect(result.idempotencyResult == .matchingExistingDifferentOperation)
        #expect(snapshot.teams.count == 1)
    }

    @Test("conflicting operation identity is rejected")
    func conflictingOperationIdentityIsRejected() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let first = IsolatedTeamCreationTransactionSupport.request(teamName: "First Meaning")
        let conflicting = IsolatedTeamCreationTransactionSupport.request(teamName: "Second Meaning")
        let request = IsolatedTeamCreationTransactionSupport.request(
            teamName: "Second Meaning",
            knownInvocationFingerprints: [conflicting.operationIdentity: CanonicalTeamCreationRequestFingerprint(request: first)]
        )
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.idempotencyResult == .conflictingOperationIdentity)
        #expect(result.validationFindings.contains { $0.code == "teamCreation.operationIdentity.conflict" })
    }

    @Test("conflicting team meaning requires review")
    func conflictingTeamMeaningRequiresReview() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        IsolatedTeamCreationTransactionSupport.insertExistingConflictingTeam(request, into: environment.context)
        try environment.save()

        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: ModelContext(environment.container))

        #expect(result.transaction.disposition == .contradictory)
        #expect(result.idempotencyResult == .duplicateTeamIdentityConflictingMeaning)
        #expect(result.reviewRequired)
        #expect(result.saveResult == .notAttempted)
    }

    @Test("failed save rolls back and safe retry creates one team")
    func failedSaveRollsBackAndSafeRetryCreatesOneTeam() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let failed = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.save]).apply(request, in: environment.context)
        let afterFailure = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)
        let retry = IsolatedTeamCreationTransactionSupport.adapter(for: environment).apply(request, in: ModelContext(environment.container))
        let afterRetry = try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container)

        #expect(failed.transaction.disposition == .saveFailed)
        #expect(failed.rollbackResult == .completed)
        #expect(failed.retryIsSafe)
        #expect(afterFailure.teams.isEmpty)
        #expect(retry.transaction.disposition == .success)
        #expect(afterRetry.teams.count == 1)
    }

    @Test("uncertain completion blocks blind retry")
    func uncertainCompletionBlocksBlindRetry() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.completionUncertain]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .partialOrUncertainOutcome)
        #expect(result.saveResult == .completionUncertain)
        #expect(result.transaction.resultUncertainBecauseSaveCompletionCannotBeProven)
        #expect(result.transaction.retrySafety == .unknown)
        #expect(result.reviewRequired)
    }

    @Test("rollback uncertainty requires review and is not retry safe")
    func rollbackUncertaintyRequiresReviewAndIsNotRetrySafe() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.save, .rollbackUncertain]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .saveFailed)
        #expect(result.rollbackResult == .uncertain)
        #expect(result.transaction.retrySafety == .unknown)
        #expect(result.reviewRequired)
        #expect(result.priorAcceptedStateRemainsUsable == false)
    }

    @Test("reload failure is classified after save")
    func reloadFailureIsClassifiedAfterSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.reload]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .staleProjection)
        #expect(result.saveResult == .succeeded)
        #expect(result.reloadResult == .failed)
        #expect(result.semanticVerificationResult == .notAttempted)
        #expect(result.reviewRequired)
    }

    @Test("semantic verification failure is classified after reload")
    func semanticVerificationFailureIsClassifiedAfterReload() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.semanticVerification]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .contradictory)
        #expect(result.saveResult == .succeeded)
        #expect(result.reloadResult == .succeeded)
        #expect(result.semanticVerificationResult == .failed)
        #expect(result.reviewRequired)
    }

    @Test("duplicate lookup failure performs no insert")
    func duplicateLookupFailurePerformsNoInsert() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.duplicateLookup]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .unresolved)
        #expect(result.idempotencyResult == .duplicateLookupFailed)
        #expect(result.saveResult == .notAttempted)
        #expect(try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container).teams.isEmpty)
    }

    @Test("injected separation failures preserve probes and perform no save")
    func injectedSeparationFailuresPreserveProbesAndPerformNoSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let request = IsolatedTeamCreationTransactionSupport.request()
        let result = IsolatedTeamCreationTransactionSupport.adapter(for: environment, injectedFailures: [.purchaseSeparation, .allowanceBoundary]).apply(request, in: environment.context)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.saveResult == .notAttempted)
        #expect(result.purchaseAllowanceSeparationFindings.count == 2)
        #expect(try IsolatedTeamCreationTransactionSupport.snapshot(from: environment.container).allowanceProbe == IsolatedTeamCreationTransactionSupport.baselineProbe)
    }

    @Test("adapter has no production route reference")
    func adapterHasNoProductionRouteReference() throws {
        let route = CanonicalPersistenceCutoverRouteManifest.route(for: .teamCreationAndEditing)
        #expect(route.currentAuthority == .legacySwiftData)
        #expect(route.proposedFutureAuthority == .proposedPersistenceAuthority)
        #expect(route.activeProductionWriterCount == 1)
        #expect(route.classifications.contains(.candidateForFirstBoundedRouting))

        let root = try repositoryRoot()
        let productionReferences = try productionSwiftFiles(root: root).filter { url in
            url.lastPathComponent != "CanonicalTeamCreationTransaction.swift"
        }.filter { url in
            let source = try String(contentsOf: url, encoding: .utf8)
            return source.contains("CanonicalTeamCreationTransactionAdapter")
                || source.contains("CanonicalTeamCreationRequest(")
        }

        #expect(productionReferences.isEmpty)
    }

    @Test("legacy team creation references remain active")
    func legacyTeamCreationReferencesRemainActive() throws {
        let root = try repositoryRoot()
        let teamView = root.appendingPathComponent("ScoreKeep/List Data/TeamView.swift")
        let scoreContentView = root.appendingPathComponent("ScoreKeep/Content Views/ScoreContentView.swift")
        let teamSource = try String(contentsOf: teamView, encoding: .utf8)
        let scoreSource = try String(contentsOf: scoreContentView, encoding: .utf8)

        #expect(teamSource.contains("modelContext.insert(theTeam)"))
        #expect(teamSource.contains("try? self.modelContext.save()"))
        #expect(scoreSource.contains("modelContext.insert(team)"))
        #expect(scoreSource.contains("try? modelContext.save()"))
    }

    private func repositoryRoot() throws -> URL {
        try StableIdentityAndOrderingTestSupport.repositoryRoot()
    }

    private func productionSwiftFiles(root: URL) throws -> [URL] {
        let sourceRoot = root.appendingPathComponent("ScoreKeep")
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: Array(keys)) else {
            throw TeamCreationTransactionTestError.repositoryRootNotFound
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, url.pathExtension == "swift" else { return nil }
            return url
        }
    }
}

enum TeamCreationTransactionTestError: Error {
    case repositoryRootNotFound
}
