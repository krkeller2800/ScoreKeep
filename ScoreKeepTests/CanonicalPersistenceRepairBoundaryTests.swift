import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence repair boundary verification")
struct CanonicalPersistenceRepairBoundaryTests {
    @Test("repair assessment vocabulary is side effect free and reviewable")
    func repairAssessmentVocabularyIsSideEffectFreeAndReviewable() {
        let finding = CanonicalDomainValidator.finding(
            "repair.relationship.candidate",
            concept: .lineup,
            severity: .repair,
            disposition: .repairRequired,
            summary: "Relationship evidence requires explicit review."
        )
        let assessments = CanonicalPersistenceRepairAssessmentDisposition.allCases.map {
            CanonicalPersistenceRepairAssessor.assess($0, findings: $0 == .noRepairRequired ? [] : [finding])
        }

        let allVocabularyAssessmentsOnly = assessments.allSatisfy(\.isAssessmentOnly)

        #expect(allVocabularyAssessmentsOnly)
        #expect(assessments.first { $0.disposition == .relationshipRepairCandidate }?.requiresExplicitReview == true)
        #expect(assessments.first { $0.disposition == .mediaCleanupCandidate }?.requiresExplicitReview == true)
        #expect(assessments.first { $0.disposition == .unsafeAutomaticRepair }?.requiresExplicitReview == true)
        #expect(assessments.first { $0.disposition == .recordShouldRemainPreserved }?.requiresExplicitReview == false)
    }

    @Test("broken duplicate ordering media and orphan evidence assess without mutation")
    func brokenDuplicateOrderingMediaAndOrphanEvidenceAssessWithoutMutation() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)
        let duplicateValidation = CanonicalDomainValidator.validateDuplicateIdentities([
            StableIdentityAndOrderingTestSupport.playerEvidence(id: PersistenceVerificationIDs.visitingPlayerOne, name: "One", number: "1"),
            StableIdentityAndOrderingTestSupport.playerEvidence(id: PersistenceVerificationIDs.visitingPlayerOne, name: "Other", number: "99")
        ])
        let orderingValidation = CanonicalDomainValidator.validateOrdering([
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0),
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 1)
        ], expectedKind: .eventSequence)
        let mediaValidation = CanonicalDomainValidator.validatePlayer(
            ReusableCanonicalPlayer(
                identity: .valid(PersistenceVerificationIDs.visitingPlayerOne),
                display: PlayerDisplayEvidence(
                    name: .present("One"),
                    jerseyNumber: .present("1"),
                    position: .present("SS"),
                    battingDirection: .present("R"),
                    photo: .invalid("malformed bytes")
                )
            )
        )
        let orphanFinding = CanonicalDomainValidator.finding(
            "repair.orphan.candidate",
            concept: .gameParticipant,
            severity: .repair,
            disposition: .repairRequired,
            summary: "A referenced relationship cannot be resolved."
        )
        let duplicate = CanonicalPersistenceRepairAssessor.assessment(for: duplicateValidation)
        let ordering = CanonicalPersistenceRepairAssessor.assessment(for: orderingValidation)
        let media = CanonicalPersistenceRepairAssessor.assessment(for: mediaValidation)
        let orphan = CanonicalPersistenceRepairAssessor.assess(.orphanCandidate, findings: [orphanFinding])
        let after = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)

        #expect(duplicate.disposition == .duplicateIdentityCandidate)
        #expect(ordering.disposition == .orderingRepairCandidate)
        let allAssessmentsOnly = [duplicate, ordering, media, orphan].allSatisfy(\.isAssessmentOnly)
        let storeUnchanged = before == after

        #expect(media.disposition == .mediaCleanupCandidate)
        #expect(orphan.disposition == .orphanCandidate)
        #expect(allAssessmentsOnly)
        #expect(storeUnchanged)
    }

    @Test("ordinary read paths do not repair delete merge resequence or save")
    func ordinaryReadPathsDoNotRepairDeleteMergeResequenceOrSave() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)
        let context = ModelContext(environment.container)
        let game = try #require(try context.fetch(FetchDescriptor<Game>()).first)
        let atbats = try context.fetch(FetchDescriptor<Atbat>())
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>())
        let homeSide = game.hteam.map {
            GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .home, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid($0.ident))))
        }
        let visitingSide = game.vteam.map {
            GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .visiting, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid($0.ident))))
        }

        _ = CanonicalPersistedEvidenceInterpreter.interpretGame(LegacyGameEvidenceSnapshot(game: game))
        _ = atbats.map { CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(LegacyAtbatEvidenceSnapshot(atbat: $0)) }
        _ = lineups.map { CanonicalPersistedEvidenceInterpreter.interpretLineup(LegacyLineupEvidenceSnapshot(lineup: $0), homeSide: homeSide, visitingSide: visitingSide) }
        _ = pitchers.map { CanonicalPersistedEvidenceInterpreter.interpretPitcherAppearance(LegacyPitcherEvidenceSnapshot(pitcher: $0), homeSide: homeSide, visitingSide: visitingSide) }
        _ = atbats.filter { $0.maxbase == "Home" }.count
        _ = LegacyTeamEvidenceSnapshot(team: try #require(game.hteam))
        _ = CanonicalDomainValidator.validateOrdering(
            atbats.map { OrderEvidence(kind: .eventSequence, value: $0.seq, sourceIndex: $0.col) },
            expectedKind: .eventSequence
        )
        _ = IsolatedMediaPersistenceSupport.classifyMediaEvidence(ownerIdentity: PersistenceVerificationIDs.visitingPlayerOne, data: IsolatedMediaPersistenceSupport.malformedBytes)
        let after = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)
        let contextHasChanges = context.hasChanges
        let storeUnchanged = before == after

        #expect(contextHasChanges == false)
        #expect(storeUnchanged)
    }

    @Test("explicit repair simulation remains separate from assessment and application")
    func explicitRepairSimulationRemainsSeparateFromAssessmentAndApplication() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)
        let assessment = CanonicalPersistenceRepairAssessor.assess(
            .explicitUserDecisionRequired,
            findings: [CanonicalDomainValidator.finding(
                "repair.explicit.required",
                concept: .substitution,
                severity: .repair,
                disposition: .repairRequired,
                summary: "A hypothetical repair would require a separate authorized transaction."
            )]
        )
        let proposedTransaction = CanonicalPersistenceTransactionClassifier.retryUnsafe(operationIdentity: "hypothetical-repair-application")
        let after = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container)
        let storeUnchanged = before == after

        #expect(assessment.isAssessmentOnly)
        #expect(assessment.requiresExplicitReview)
        #expect(proposedTransaction.retryIsUnsafe)
        #expect(proposedTransaction.repairOrReviewRequired)
        #expect(storeUnchanged)
    }
}
