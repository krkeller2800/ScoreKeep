import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence deletion boundary verification")
struct CanonicalPersistenceDeletionTests {
    @Test("delete-rule inventory records current model as implicit SwiftData relationships")
    func deleteRuleInventoryRecordsCurrentModelAsImplicitSwiftDataRelationships() throws {
        let mappings = CanonicalPersistenceConceptMapper.mapAll()
        let media = try #require(mappings.first { $0.concept == .media })
        let substitution = try #require(mappings.first { $0.concept == .substitution })
        let lineup = try #require(mappings.first { $0.concept == .lineup })

        #expect(media.persistedEvidence == ["Team.logo and Player.photo external storage"])
        #expect(media.risks.contains("Replacement is direct field mutation without media transaction evidence"))
        #expect(substitution.persistedEvidence == ["Game.replaced and Game.incomings parallel arrays"])
        #expect(substitution.representations.contains(.ambiguousRepresentation))
        #expect(lineup.persistedEvidence == ["Lineup game, team, inning, everyone-hits, players"])
    }

    @Test("deleting a game is explicit and does not delete unrelated teams players or media")
    func deletingGameIsExplicitAndDoesNotDeleteUnrelatedTeamsPlayersOrMedia() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)
        let game = try #require(try environment.fetch(FetchDescriptor<Game>()).first { $0.ident == PersistenceVerificationIDs.game })

        environment.context.delete(game)
        try environment.save()
        let after = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)
        let result = CanonicalPersistenceTransactionClassifier.successWithWarnings([
            CanonicalDomainValidator.finding(
                "delete.game.relationshipEffectsRequireReview",
                concept: .game,
                severity: .warning,
                disposition: .validWithWarnings,
                summary: "Deleting a game is explicit; dependent relationship effects are verified from the isolated store."
            )
        ], operationIdentity: "delete-game")

        #expect(after.gameIDs.contains(PersistenceVerificationIDs.game) == false)
        #expect(after.teamIDs == before.teamIDs)
        #expect(after.playerIDs == before.playerIDs)
        #expect(after.teamLogoByteCounts[MediaPersistenceVerificationIDs.unrelatedTeam] == before.teamLogoByteCounts[MediaPersistenceVerificationIDs.unrelatedTeam])
        #expect(result.disposition == .successWithWarnings)
        #expect(result.allowanceOrEntitlementMustRemainUnchanged)
    }

    @Test("team deletion remains isolated and reloadable")
    func teamDeletionRemainsIsolatedAndReloadable() throws {
        let outcome = try recordInventoryAfter { environment in
            let teamID = PersistenceVerificationIDs.visitingTeam
            let team = try #require(try environment.fetch(FetchDescriptor<Team>()).first { $0.ident == teamID })
            environment.context.delete(team)
        }
        let assessment = CanonicalPersistenceRepairAssessor.assess(
            .relationshipRepairCandidate,
            findings: [deleteReviewFinding("delete.team.relationshipReview", concept: .team)],
            affectedRecordIdentities: [PersistenceVerificationIDs.visitingTeam.uuidString]
        )

        #expect(outcome.after.teamIDs.contains(PersistenceVerificationIDs.visitingTeam) == false)
        #expect(outcome.after.teamIDs.contains(MediaPersistenceVerificationIDs.unrelatedTeam))
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(outcome.after.playerIDs == outcome.before.playerIDs)
        #expect(outcome.after.allowanceProbe == outcome.before.allowanceProbe)
        #expect(assessment.isAssessmentOnly)
    }

    @Test("player deletion remains isolated and reloadable")
    func playerDeletionRemainsIsolatedAndReloadable() throws {
        let outcome = try recordInventoryAfter { environment in
            let playerID = PersistenceVerificationIDs.visitingPlayerTwo
            let player = try #require(try environment.fetch(FetchDescriptor<Player>()).first { $0.identifier == playerID })
            environment.context.delete(player)
        }
        let assessment = CanonicalPersistenceRepairAssessor.assess(
            .orphanCandidate,
            findings: [deleteReviewFinding("delete.player.relationshipReview", concept: .player)],
            affectedRecordIdentities: [PersistenceVerificationIDs.visitingPlayerTwo.uuidString]
        )

        #expect(outcome.after.playerIDs.contains(PersistenceVerificationIDs.visitingPlayerTwo) == false)
        #expect(outcome.after.teamIDs == outcome.before.teamIDs)
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(outcome.after.atbatIDs == outcome.before.atbatIDs)
        #expect(outcome.after.allowanceProbe == outcome.before.allowanceProbe)
        #expect(assessment.disposition == .orphanCandidate)
        #expect(assessment.isAssessmentOnly)
    }

    @Test("event deletion remains isolated and reloadable")
    func eventDeletionRemainsIsolatedAndReloadable() throws {
        let outcome = try recordInventoryAfter { environment in
            let eventID = PersistenceVerificationIDs.eventOne
            let event = try #require(try environment.fetch(FetchDescriptor<Atbat>()).first { $0.ident == eventID })
            environment.context.delete(event)
        }

        #expect(outcome.after.atbatIDs.contains(PersistenceVerificationIDs.eventOne) == false)
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(outcome.after.teamIDs == outcome.before.teamIDs)
        #expect(outcome.after.playerIDs == outcome.before.playerIDs)
        #expect(outcome.after.allowanceProbe == outcome.before.allowanceProbe)
    }

    @Test("lineup deletion remains isolated and reloadable")
    func lineupDeletionRemainsIsolatedAndReloadable() throws {
        let outcome = try recordInventoryAfter { environment in
            let lineupID = PersistenceVerificationIDs.lineup
            let lineup = try #require(try environment.fetch(FetchDescriptor<Lineup>()).first { $0.ident == lineupID })
            environment.context.delete(lineup)
        }

        #expect(outcome.after.lineupIDs.contains(PersistenceVerificationIDs.lineup) == false)
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(outcome.after.teamIDs == outcome.before.teamIDs)
        #expect(outcome.after.playerIDs == outcome.before.playerIDs)
        #expect(outcome.after.allowanceProbe == outcome.before.allowanceProbe)
    }

    @Test("pitcher deletion remains isolated and reloadable")
    func pitcherDeletionRemainsIsolatedAndReloadable() throws {
        let outcome = try recordInventoryAfter { environment in
            let pitcherID = PersistenceVerificationIDs.pitcherOne
            let pitcher = try #require(try environment.fetch(FetchDescriptor<Pitcher>()).first { $0.ident == pitcherID })
            environment.context.delete(pitcher)
        }

        #expect(outcome.after.pitcherIDs.contains(PersistenceVerificationIDs.pitcherOne) == false)
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(outcome.after.teamIDs == outcome.before.teamIDs)
        #expect(outcome.after.playerIDs == outcome.before.playerIDs)
        #expect(outcome.after.allowanceProbe == outcome.before.allowanceProbe)
    }

    @Test("participant substitution and media removals are scoped field mutations")
    func participantSubstitutionAndMediaRemovalsAreScopedFieldMutations() throws {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)
        let game = try #require(try environment.fetch(FetchDescriptor<Game>()).first { $0.ident == PersistenceVerificationIDs.game })
        let players = try environment.fetch(FetchDescriptor<Player>())
        let teams = try environment.fetch(FetchDescriptor<Team>())
        let removedParticipant = try #require(players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerTwo })
        let photoOwner = try #require(players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerOne })
        let logoOwner = try #require(teams.first { $0.ident == PersistenceVerificationIDs.homeTeam })

        game.players.removeAll { $0.identifier == removedParticipant.identifier }
        game.replaced.removeAll()
        game.incomings.removeAll()
        photoOwner.photo = nil
        logoOwner.logo = nil
        try environment.save()
        let after = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)

        #expect(after.gameIDs == before.gameIDs)
        #expect(after.teamIDs == before.teamIDs)
        #expect(after.playerIDs == before.playerIDs)
        #expect(after.atbatIDs == before.atbatIDs)
        #expect(after.gamePlayerIDs[PersistenceVerificationIDs.game]?.contains(PersistenceVerificationIDs.visitingPlayerTwo) == false)
        #expect(after.gameReplacementPairs[PersistenceVerificationIDs.game]?.isEmpty == true)
        #expect(after.playerPhotoByteCounts[PersistenceVerificationIDs.visitingPlayerOne]! == nil)
        #expect(after.teamLogoByteCounts[PersistenceVerificationIDs.homeTeam]! == nil)
        #expect(after.teamLogoByteCounts[MediaPersistenceVerificationIDs.unrelatedTeam] == before.teamLogoByteCounts[MediaPersistenceVerificationIDs.unrelatedTeam])
    }

    @Test("referenced-record deletion outcomes remain reviewable rather than assumed successful")
    func referencedRecordDeletionOutcomesRemainReviewableRatherThanAssumedSuccessful() throws {
        let outcome = try recordInventoryAfter { environment in
            let playerID = PersistenceVerificationIDs.visitingPlayerOne
            let player = try #require(try environment.fetch(FetchDescriptor<Player>()).first { $0.identifier == playerID })
            environment.context.delete(player)
        }
        let finding = CanonicalDomainValidator.finding(
            "delete.referencedRecord.reviewRequired",
            concept: .player,
            severity: .repair,
            disposition: .repairRequired,
            summary: "Deleting a referenced reusable player requires review of dependent event, lineup, pitcher, and substitution evidence."
        )
        let transaction = CanonicalPersistenceTransactionClassifier.relationshipFailure([finding], operationIdentity: "delete-referenced-player")
        let assessment = CanonicalPersistenceRepairAssessor.assess(
            .orphanCandidate,
            findings: [finding],
            affectedRecordIdentities: [PersistenceVerificationIDs.visitingPlayerOne.uuidString]
        )

        #expect(outcome.after.playerIDs.contains(PersistenceVerificationIDs.visitingPlayerOne) == false)
        #expect(outcome.after.gameIDs == outcome.before.gameIDs)
        #expect(transaction.disposition == .relationshipFailure)
        #expect(transaction.repairOrReviewRequired)
        #expect(assessment.disposition == .orphanCandidate)
        #expect(assessment.requiresExplicitReview)
        #expect(assessment.isAssessmentOnly)
    }

    private func deletionSnapshotAfter(_ delete: (IsolatedPersistenceEnvironment) throws -> Void) throws -> (before: IsolatedDeleteSnapshot, after: IsolatedDeleteSnapshot) {
        let environment = try IsolatedPersistenceEnvironment()
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)
        try delete(environment)
        try environment.save()
        let after = try IsolatedMediaPersistenceSupport.deleteSnapshot(from: environment.container)
        return (before, after)
    }

    private func recordInventoryAfter(_ delete: (IsolatedPersistenceEnvironment) throws -> Void) throws -> (before: IsolatedRecordInventorySnapshot, after: IsolatedRecordInventorySnapshot) {
        let environment = try IsolatedPersistenceEnvironment()
        let probe = IsolatedPersistenceProbeState(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 1, entitlementMarker: "active-2026")
        IsolatedMediaPersistenceSupport.insertMediaGraph(into: environment.context)
        try environment.save()
        let before = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container, allowanceProbe: probe)
        try delete(environment)
        try environment.save()
        let after = try IsolatedMediaPersistenceSupport.recordInventorySnapshot(from: environment.container, allowanceProbe: probe)
        return (before, after)
    }

    private func deleteReviewFinding(_ code: String, concept: CanonicalValidationConcept) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(
            code,
            concept: concept,
            severity: .repair,
            disposition: .repairRequired,
            summary: "Deletion relationship effects require explicit review before repair."
        )
    }
}
