import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team creation SwiftData operation evidence store")
struct TeamCreationSwiftDataEvidenceStoreTests {
    @Test("begin persists operation team fingerprint phase proof retry and review evidence")
    func beginPersistsOperationTeamFingerprintPhaseProofRetryAndReviewEvidence() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)

        #expect(await store.begin(evidence) == .none)
        let reloaded = try await #require(store.evidence(for: request.operationIdentity))
        let byTeam = await store.evidenceForTeam(request.teamIdentity)

        #expect(reloaded.operationIdentity == request.operationIdentity)
        #expect(reloaded.teamIdentity == request.teamIdentity)
        #expect(reloaded.requestFingerprint == request.semanticFingerprint)
        #expect(reloaded.phase == .prepared)
        #expect(reloaded.completionProof == .noProof)
        #expect(reloaded.retryClassification == .retryBlockedWhileInProgress)
        #expect(reloaded.reviewRequired == false)
        #expect(byTeam.count == 1)
    }

    @Test("conflicting operation identity and team meaning are rejected")
    func conflictingOperationIdentityAndTeamMeaningAreRejected() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let sameOperationDifferentMeaning = IsolatedVersionedTeamCreationEvidenceSupport.request(teamName: "Changed")
        let sameTeamDifferentOperation = IsolatedVersionedTeamCreationEvidenceSupport.request(operationIdentity: "other-op", teamName: "Changed")

        #expect(await store.begin(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)) == .none)
        #expect(await store.begin(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: sameOperationDifferentMeaning)) == .sameOperationDifferentRequest)
        #expect(await store.begin(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: sameTeamDifferentOperation)) == .sameTeamDifferentMeaning)
        #expect(try IsolatedVersionedTeamCreationEvidenceSupport.evidenceCount(in: container) == 1)
    }

    @Test("phase advancement completion uncertainty safe failure and regression policy persist")
    func phaseAdvancementCompletionUncertaintySafeFailureAndRegressionPolicyPersist() async throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let store = TeamCreationSwiftDataEvidenceStore(container: container)
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)

        _ = await store.begin(evidence)
        await store.advance(evidence.advanced(to: .inProgress))
        await store.advance(evidence.advanced(to: .saveAttempted))
        await store.advance(evidence.advanced(to: .prepared))
        #expect(await store.evidence(for: request.operationIdentity)?.phase == .saveAttempted)

        await store.markCompletionUncertain(evidence.advanced(to: .saveAttempted))
        let uncertain = try await #require(store.evidence(for: request.operationIdentity))
        #expect(uncertain.phase == .failedWithUncertainCompletion)
        #expect(uncertain.completionProof == .completionUncertain)
        #expect(uncertain.retryClassification == .retryProhibitedCompletionUncertain)
        #expect(uncertain.reviewRequired)
    }

    @Test("fresh context instance and container reload preserve evidence")
    func freshContextInstanceAndContainerReloadPreserveEvidence() async throws {
        let url = try IsolatedVersionedTeamCreationEvidenceSupport.temporaryStoreURL()
        do {
            let firstContainer = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
            let firstStore = TeamCreationSwiftDataEvidenceStore(container: firstContainer)
            let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
            await firstStore.markCompletionProven(IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request))
        }

        let secondContainer = try IsolatedVersionedTeamCreationEvidenceSupport.v2DiskContainer(url: url)
        let secondStore = TeamCreationSwiftDataEvidenceStore(container: secondContainer)
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let reloaded = try await #require(secondStore.evidence(for: request.operationIdentity))

        #expect(reloaded.phase == .completed)
        #expect(reloaded.completionProof == .completionMarkerRecorded)
        #expect(reloaded.retryClassification == .retryUnnecessaryCompletionProven)
    }

    @Test("same context can save operation evidence and team together")
    func sameContextCanSaveOperationEvidenceAndTeamTogether() throws {
        let container = try IsolatedVersionedTeamCreationEvidenceSupport.v2InMemoryContainer()
        let context = ModelContext(container)
        let request = IsolatedVersionedTeamCreationEvidenceSupport.request()
        let evidence = IsolatedVersionedTeamCreationEvidenceSupport.evidence(for: request)

        context.insert(TeamCreationOperationEvidenceRecord(
            operationIdentity: evidence.operationIdentity.rawValue,
            targetTeamIdentity: evidence.teamIdentity,
            requestFingerprint: evidence.requestFingerprint.rawValue,
            phase: CanonicalTeamCreationOperationPhase.saveAttempted.rawValue,
            completionProof: CanonicalTeamCreationCompletionProof.noProof.rawValue,
            finalDisposition: CanonicalTeamCreationFinalDisposition.none.rawValue,
            retryClassification: CanonicalTeamCreationRetryClassification.retryBlockedWhileInProgress.rawValue,
            reviewRequired: false,
            diagnosticCodesStorage: "",
            source: "isolated-same-context-proof"
        ))
        context.insert(Team(ident: request.teamIdentity, name: request.teamName, coach: request.coach, details: request.details))
        try context.save()

        let fresh = ModelContext(container)
        let teams = try fresh.fetch(FetchDescriptor<Team>())
        let evidenceRecords = try fresh.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>())

        #expect(teams.count == 1)
        #expect(evidenceRecords.count == 1)
        #expect(teams.first?.ident == request.teamIdentity)
        #expect(evidenceRecords.first?.operationIdentity == request.operationIdentity.rawValue)
        #expect(evidenceRecords.first?.targetTeamIdentity == request.teamIdentity)
        #expect(evidenceRecords.first?.requestFingerprint == request.semanticFingerprint.rawValue)
    }
}
