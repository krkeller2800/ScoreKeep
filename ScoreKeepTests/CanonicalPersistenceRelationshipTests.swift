import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence relationship verification")
struct CanonicalPersistenceRelationshipTests {
    @Test("valid game team player atbat lineup pitcher and substitution relationships survive reload")
    func validRelationshipsSurviveReload() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)

        #expect(snapshot.homeTeamID == PersistenceVerificationIDs.homeTeam)
        #expect(snapshot.visitingTeamID == PersistenceVerificationIDs.visitingTeam)
        #expect(snapshot.playerIDs.contains(PersistenceVerificationIDs.visitingPlayerOne))
        #expect(snapshot.playerIDs.contains(PersistenceVerificationIDs.homePlayerOne))
        #expect(snapshot.atbatIDsBySequence == [PersistenceVerificationIDs.eventOne, PersistenceVerificationIDs.eventTwo])
        #expect(snapshot.lineupPlayerIDsByExplicitBattingOrder == [PersistenceVerificationIDs.visitingPlayerOne, PersistenceVerificationIDs.visitingPlayerTwo])
        #expect(snapshot.pitcherIDsByAppearanceOrder == [PersistenceVerificationIDs.pitcherOne, PersistenceVerificationIDs.pitcherTwo])
        #expect(snapshot.replacementPairIDs == [IsolatedPersistenceReplacementPair(outgoing: PersistenceVerificationIDs.visitingPlayerOne, incoming: PersistenceVerificationIDs.visitingPlayerTwo)])
    }

    @Test("missing team and participant evidence produces diagnostics without fabrication")
    func missingTeamAndParticipantEvidenceProducesDiagnosticsWithoutFabrication() {
        let missingTeamGame = LegacyGameEvidenceSnapshot(
            identity: .valid(PersistenceVerificationIDs.game),
            date: "2026-07-15",
            location: "Missing Team Field",
            homeScore: 0,
            visitingScore: 0,
            everyoneHits: false,
            expectedInnings: 7,
            homeTeam: nil,
            visitingTeam: LegacyTeamEvidenceSnapshot(identity: .valid(PersistenceVerificationIDs.visitingTeam), name: "Visitors")
        )
        let gameResult = CanonicalPersistedEvidenceInterpreter.interpretGame(missingTeamGame)
        let sideValidation = CanonicalDomainValidator.validateGameSides(
            home: nil,
            visiting: GameSideTeamParticipation(
                gameIdentity: .valid(PersistenceVerificationIDs.game),
                role: .visiting,
                resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(PersistenceVerificationIDs.visitingTeam)))
            )
        )
        let missingBatter = CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(
            LegacyAtbatEvidenceSnapshot(
                identity: .valid(PersistenceVerificationIDs.eventOne),
                gameIdentity: .valid(PersistenceVerificationIDs.game),
                teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam),
                player: nil,
                result: "Single",
                maxbase: "First",
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

        #expect(gameResult.sourceIdentity == .valid(PersistenceVerificationIDs.game))
        #expect(sideValidation.disposition == .incomplete)
        #expect(sideValidation.findings.map(\.code).contains("gameSide.homeMissing"))
        #expect(missingBatter.relationshipResolution == .unresolved)
        #expect(missingBatter.sourceIdentity == .valid(PersistenceVerificationIDs.eventOne))
    }

    @Test("duplicate identity wrong side and broken child relationships remain classified")
    func duplicateIdentityWrongSideAndBrokenChildRelationshipsRemainClassified() {
        let duplicateValidation = CanonicalDomainValidator.validateDuplicateIdentities([
            StableIdentityAndOrderingTestSupport.playerEvidence(id: PersistenceVerificationIDs.visitingPlayerOne, name: "One", number: "1"),
            StableIdentityAndOrderingTestSupport.playerEvidence(id: PersistenceVerificationIDs.visitingPlayerOne, name: "Different", number: "99")
        ])
        let homeSide = GameSideTeamParticipation(
            gameIdentity: .valid(PersistenceVerificationIDs.game),
            role: .home,
            resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(PersistenceVerificationIDs.homeTeam)))
        )
        let brokenLineup = CanonicalPersistedEvidenceInterpreter.interpretLineup(
            LegacyLineupEvidenceSnapshot(
                identity: .valid(PersistenceVerificationIDs.lineup),
                gameIdentity: .valid(PersistenceVerificationIDs.game),
                teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam),
                everyoneHits: false,
                inning: 1,
                players: [LegacyPlayerEvidenceSnapshot(identity: .missing, name: "Unknown", battingOrder: 1)]
            ),
            homeSide: homeSide,
            visitingSide: nil
        )
        let brokenPitcher = CanonicalPersistedEvidenceInterpreter.interpretPitcherAppearance(
            LegacyPitcherEvidenceSnapshot(
                pitcher: Pitcher(
                    ident: PersistenceVerificationIDs.pitcherOne,
                    player: Player(identifier: PersistenceVerificationIDs.visitingPlayerOne, name: "Wrong Side", number: "1", position: "P", batDir: "R", batOrder: 1),
                    team: Team(ident: PersistenceVerificationIDs.visitingTeam, name: "Visitors", coach: "", details: ""),
                    game: Game(ident: PersistenceVerificationIDs.game, date: "2026-07-15", location: "", highLights: "", hscore: 0, vscore: 0)
                )
            ),
            homeSide: homeSide,
            visitingSide: nil
        )

        #expect(duplicateValidation.disposition == .contradictory)
        #expect(brokenLineup.relationshipResolution == .conflicting)
        #expect(brokenLineup.futureWriteMustStop)
        #expect(brokenPitcher.relationshipResolution == .unresolved)
        #expect(brokenPitcher.interpretedReadOnlyMayContinue)
    }

    @Test("broken replacement pairs and ambiguous arrays remain unresolved without repair")
    func brokenReplacementPairsAndAmbiguousArraysRemainUnresolvedWithoutRepair() {
        let incoming = LegacyPlayerEvidenceSnapshot(
            identity: .valid(PersistenceVerificationIDs.visitingPlayerTwo),
            name: "Incoming",
            number: "2",
            position: "CF",
            battingDirection: "L",
            battingOrder: 2,
            teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam)
        )
        let outgoing = LegacyPlayerEvidenceSnapshot(
            identity: .missing,
            name: "Missing Outgoing",
            number: "",
            position: "",
            battingDirection: "",
            battingOrder: 1,
            teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam)
        )
        let brokenPair = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: [incoming],
            outgoing: [outgoing],
            gameIdentity: .valid(PersistenceVerificationIDs.game)
        )
        let ambiguousArrays = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: [incoming, incoming],
            outgoing: [outgoing],
            gameIdentity: .valid(PersistenceVerificationIDs.game)
        )

        #expect(brokenPair.count == 1)
        #expect(brokenPair[0].relationshipResolution == .unresolved)
        #expect(brokenPair[0].canonicalValue?.outgoing.identity.validIdentifier == nil)
        #expect(ambiguousArrays.count == 2)
        #expect(ambiguousArrays.map(\.relationshipResolution).contains(.unresolved))
        #expect(ambiguousArrays.allSatisfy { $0.canonicalValue != nil })
    }
}
