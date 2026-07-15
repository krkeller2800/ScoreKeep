import Foundation
import Testing
@testable import ScoreKeep

@Suite("Canonical persistence foundation")
struct CanonicalPersistenceFoundationTests {
    @Test func canonicalToPersistedMappingClassifiesRequiredConceptsDeterministically() {
        let all = CanonicalPersistenceConceptMapper.mapAll()
        let repeated = CanonicalPersistenceConceptMapper.mapAll()

        #expect(all == repeated)
        #expect(all.count == CanonicalPersistenceConcept.allCases.count)
        #expect(CanonicalPersistenceConceptMapper.map(.team).representations.contains(.directStoredFact))
        #expect(CanonicalPersistenceConceptMapper.map(.reusablePlayer).representations.contains(.media))
        #expect(CanonicalPersistenceConceptMapper.map(.rosterMembership).representations.contains(.relationship))
        #expect(CanonicalPersistenceConceptMapper.map(.gameSide).representations.contains(.relationship))
        #expect(CanonicalPersistenceConceptMapper.map(.lineup).representations.contains(.relationship))
        #expect(CanonicalPersistenceConceptMapper.map(.battingOrder).representations.contains(.ambiguousRepresentation))
        #expect(CanonicalPersistenceConceptMapper.map(.scoringEvent).representations.contains(.directStoredFact))
        #expect(CanonicalPersistenceConceptMapper.map(.score).representations.contains(.derivedStoredValue))
        #expect(CanonicalPersistenceConceptMapper.map(.pitcherAppearanceAndResponsibility).representations.contains(.relationship))
        #expect(CanonicalPersistenceConceptMapper.map(.substitution).representations.contains(.ambiguousRepresentation))
        #expect(CanonicalPersistenceConceptMapper.map(.correctionAndSupersession).representations.contains(.missingRepresentation))
        #expect(CanonicalPersistenceConceptMapper.map(.unsupportedCanonicalValue).representations.contains(.unsupportedRepresentation))
    }

    @Test func persistedStyleSnapshotsInterpretReadOnlyWithoutIdentityFabrication() {
        let team = Team(ident: StableIdentityAndOrderingTestSupport.teamA, name: "Tigers", coach: "Coach", details: "Details")
        let player = Player(identifier: StableIdentityAndOrderingTestSupport.playerA, name: "Casey", number: "8", position: "SS", batDir: "R", batOrder: 1, team: team)
        team.players = [player]
        let game = Game(ident: StableIdentityAndOrderingTestSupport.gameA, date: "2026-07-15", location: "Field", highLights: "", hscore: 1, vscore: 0, everyOneHits: false, numInnings: 7, vteam: Team(ident: StableIdentityAndOrderingTestSupport.teamB, name: "Hawks", coach: "", details: ""), hteam: team, players: [player])
        let lineup = Lineup(ident: StableIdentityAndOrderingTestSupport.fixedUUID("41000000-0000-0000-0000-000000000020"), everyoneHits: false, game: game, team: team, inning: 1, players: [player])
        let atbat = Atbat(ident: StableIdentityAndOrderingTestSupport.eventA, game: game, team: team, player: player, result: "Single", maxbase: "First", batOrder: 1, outAt: "", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        let pitcher = Pitcher(ident: StableIdentityAndOrderingTestSupport.fixedUUID("50000000-0000-0000-0000-000000000020"), player: player, team: team, game: game, startInn: 1, sOuts: 0, sBats: 0)
        let homeSide = GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .home, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(team.ident))))
        let visitingSide = GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .visiting, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(StableIdentityAndOrderingTestSupport.teamB))))

        #expect(CanonicalPersistedEvidenceInterpreter.interpretTeam(LegacyTeamEvidenceSnapshot(team: team)).sourceIdentity == .valid(team.ident))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretPlayer(LegacyPlayerEvidenceSnapshot(player: player)).sourceIdentity == .valid(player.identifier))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretRosterMembership(LegacyPlayerEvidenceSnapshot(player: player)).sourceIdentity == .valid(player.identifier))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretGame(LegacyGameEvidenceSnapshot(game: game)).sourceIdentity == .valid(game.ident))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretLineup(LegacyLineupEvidenceSnapshot(lineup: lineup), homeSide: homeSide, visitingSide: visitingSide).sourceIdentity == .valid(lineup.ident))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(LegacyAtbatEvidenceSnapshot(atbat: atbat)).sourceIdentity == .valid(atbat.ident))
        #expect(CanonicalPersistedEvidenceInterpreter.interpretPitcherAppearance(LegacyPitcherEvidenceSnapshot(pitcher: pitcher), homeSide: homeSide, visitingSide: visitingSide).sourceIdentity == .valid(pitcher.ident))
        #expect(player.identifier == StableIdentityAndOrderingTestSupport.playerA)
        #expect(game.atbats.isEmpty)
    }

    @Test func persistedInterpretationClassifiesMissingBrokenAmbiguousUnsupportedAndOrderingEvidence() {
        let missingPlayer = LegacyPlayerEvidenceSnapshot(identity: .missing, name: "No ID", number: "12", position: "CF", battingDirection: "L", battingOrder: 1)
        let missingPlayerResult = CanonicalPersistedEvidenceInterpreter.interpretPlayer(missingPlayer)
        let brokenLineup = LegacyLineupEvidenceSnapshot(
            identity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("41000000-0000-0000-0000-000000000030")),
            gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
            teamIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("99999999-0000-0000-0000-000000000001")),
            everyoneHits: false,
            inning: 1,
            players: [missingPlayer]
        )
        let homeSide = GameSideTeamParticipation(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), role: .home, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(StableIdentityAndOrderingTestSupport.teamA))))
        let lineupResult = CanonicalPersistedEvidenceInterpreter.interpretLineup(brokenLineup, homeSide: homeSide, visitingSide: nil)
        let unsupportedEvent = CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(
            LegacyAtbatEvidenceSnapshot(
                identity: .valid(StableIdentityAndOrderingTestSupport.eventA),
                gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
                teamIdentity: .valid(StableIdentityAndOrderingTestSupport.teamA),
                player: missingPlayer,
                result: "Balkish",
                maxbase: "Moon",
                battingOrder: 1,
                outAt: "",
                inning: 1,
                sequence: 1,
                scorecardColumn: 1,
                rbis: 0,
                outs: 0,
                sacrificeFly: 0,
                sacrificeBunt: 0,
                stolenBases: 0,
                earnedRun: true,
                playRecord: "",
                endOfInning: false
            )
        )
        let substitutions = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: [missingPlayer],
            outgoing: [],
            gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
            sourceLocation: "synthetic"
        )
        let negativeScore = CanonicalPersistedEvidenceInterpreter.interpretStoredScore(
            CanonicalPersistedStoredScoreSnapshot(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), home: -1, visiting: 0)
        )

        #expect(missingPlayerResult.sourceIdentity == .missing)
        #expect(missingPlayerResult.canonicalValue?.identity == .missing)
        let brokenLineupDisposition = lineupResult.disposition
        #expect(brokenLineupDisposition == CanonicalPersistedInterpretationDisposition.contradictory || brokenLineupDisposition == CanonicalPersistedInterpretationDisposition.unresolved)
        #expect(unsupportedEvent.disposition == .unsupported)
        #expect(unsupportedEvent.unsupportedRawEvidence.contains("result=Balkish"))
        #expect(substitutions.count == 1)
        #expect(substitutions[0].disposition == .unresolved)
        #expect(negativeScore.disposition == .rejectedForFutureWrite)
        #expect(CanonicalPersistedEvidenceInterpreter.interpretStoredScore(CanonicalPersistedStoredScoreSnapshot(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), home: 2, visiting: 1)).canonicalValue == CanonicalProjectedScore(home: 2, visiting: 1))
    }

    @Test func transactionClassifierDistinguishesRequiredOutcomesAndSideEffectRules() {
        let finding = CanonicalDomainValidator.finding("persistence.test", concept: .game, severity: .rejection, disposition: .rejected, summary: "Rejected.")
        let warning = CanonicalDomainValidator.finding("persistence.warning", concept: .ordering, severity: .warning, disposition: .validWithWarnings, summary: "Warning.")

        let success = CanonicalPersistenceTransactionClassifier.success(operationIdentity: "op", affectedRecordIdentities: ["b", "a"])
        let warningSuccess = CanonicalPersistenceTransactionClassifier.successWithWarnings([warning])
        let validation = CanonicalPersistenceTransactionClassifier.validationRejected([finding])
        let saveFailure = CanonicalPersistenceTransactionClassifier.saveFailed([finding])
        let partial = CanonicalPersistenceTransactionClassifier.partialOrUncertainOutcome([finding])
        let stale = CanonicalPersistenceTransactionClassifier.staleProjection()
        let relationship = CanonicalPersistenceTransactionClassifier.relationshipFailure([finding])
        let ordering = CanonicalPersistenceTransactionClassifier.orderingFailure([finding])
        let media = CanonicalPersistenceTransactionClassifier.mediaFailure([finding])
        let interrupted = CanonicalPersistenceTransactionClassifier.interruptedOperation()
        let safeRetry = CanonicalPersistenceTransactionClassifier.retrySafe()
        let unsafeRetry = CanonicalPersistenceTransactionClassifier.retryUnsafe()
        let duplicate = CanonicalPersistenceTransactionClassifier.duplicateAlreadyApplied()
        let unsupported = CanonicalPersistenceTransactionClassifier.unsupported([finding])
        let contradictory = CanonicalPersistenceTransactionClassifier.contradictory([finding])
        let unresolved = CanonicalPersistenceTransactionClassifier.unresolved([finding])

        #expect(success.disposition == .success)
        #expect(success.affectedRecordIdentities == ["a", "b"])
        #expect(warningSuccess.disposition == CanonicalPersistenceTransactionDisposition.successWithWarnings)
        #expect(validation.priorAcceptedStateRemainsUsable)
        #expect(validation.allowanceOrEntitlementMustRemainUnchanged)
        #expect(saveFailure.resultUncertainBecauseSaveCompletionCannotBeProven)
        #expect(saveFailure.explicitReloadRequired)
        #expect(partial.priorAcceptedStateRemainsUsable == false)
        #expect(stale.retryIsSafe)
        #expect(relationship.repairOrReviewRequired)
        #expect(ordering.explicitReloadRequired)
        #expect(media.retryIsSafe)
        #expect(interrupted.resultUncertainBecauseSaveCompletionCannotBeProven)
        #expect(safeRetry.retryIsSafe)
        #expect(unsafeRetry.retryIsUnsafe)
        #expect(duplicate.workflowMayContinue)
        #expect(unsupported.workflowMayContinue == false)
        #expect(contradictory.recoveryIsAvailable)
        #expect(unresolved.repairOrReviewRequired)
        let allowanceAndEntitlementInvariant = [validation, saveFailure, partial, relationship, ordering, media, interrupted, unsupported, contradictory, unresolved]
            .allSatisfy { $0.allowanceOrEntitlementMustRemainUnchanged }
        #expect(allowanceAndEntitlementInvariant)
    }
}
