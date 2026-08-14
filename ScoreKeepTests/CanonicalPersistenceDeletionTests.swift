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

    @Test("production game delete removes aggregate hitting and pitching report sources")
    func productionGameDeleteRemovesAggregateHittingAndPitchingReportSources() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let fixture = insertAggregateDeletionFixture(into: environment.context)
        try environment.save()

        let before = try aggregateDeletionSnapshot(from: environment.container, teamName: fixture.visitingTeamName, pitchingTeamName: fixture.homeTeamName)
        let gameToDelete = try #require(try environment.fetch(FetchDescriptor<Game>()).first { $0.ident == fixture.deletedGameID })
        let atbats = try environment.fetch(FetchDescriptor<Atbat>())
        let pitchers = try environment.fetch(FetchDescriptor<Pitcher>())
        let lineups = try environment.fetch(FetchDescriptor<Lineup>())

        GameDeletionPersistence.deleteGame(
            gameToDelete,
            in: environment.context,
            atbats: atbats,
            pitchers: pitchers,
            lineups: lineups
        )
        try environment.save()

        let after = try aggregateDeletionSnapshot(from: environment.container, teamName: fixture.visitingTeamName, pitchingTeamName: fixture.homeTeamName)

        #expect(before.hittingAtbatIDsByGame[fixture.deletedGameID]?.count == 3)
        #expect(before.hittingAtbatIDsByGame[fixture.survivingGameID]?.count == 6)
        #expect(before.pitcherIDsByGame[fixture.deletedGameID]?.count == 1)
        #expect(before.pitcherIDsByGame[fixture.survivingGameID]?.count == 1)
        #expect(before.reportPitchingInnings == 3)

        #expect(after.gameIDs.contains(fixture.deletedGameID) == false)
        #expect(after.gameIDs == [fixture.survivingGameID])
        #expect(after.hittingAtbatIDsByGame[fixture.deletedGameID] == nil)
        #expect(after.hittingAtbatIDsByGame[fixture.survivingGameID]?.count == 6)
        #expect(after.pitcherIDsByGame[fixture.deletedGameID] == nil)
        #expect(after.pitcherIDsByGame[fixture.survivingGameID]?.count == 1)
        #expect(after.reportPitchingInnings == 2)
        #expect(after.allAtbatGameIDs == [fixture.survivingGameID])
        #expect(after.allLineupGameIDs == [fixture.survivingGameID])
        #expect(after.allPitcherGameIDs == [fixture.survivingGameID])
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

    private struct AggregateDeletionFixture {
        let deletedGameID: UUID
        let survivingGameID: UUID
        let visitingTeamName: String
        let homeTeamName: String
    }

    private struct AggregateDeletionSnapshot {
        let gameIDs: [UUID]
        let hittingAtbatIDsByGame: [UUID: [UUID]]
        let pitcherIDsByGame: [UUID: [UUID]]
        let reportPitchingInnings: Int
        let allAtbatGameIDs: [UUID]
        let allLineupGameIDs: [UUID]
        let allPitcherGameIDs: [UUID]
    }

    private func insertAggregateDeletionFixture(into context: ModelContext) -> AggregateDeletionFixture {
        let visitingTeam = Team(ident: UUID(uuidString: "00000000-0000-0000-0000-000000004101")!, name: "Deletion Visitors", coach: "", details: "")
        let homeTeam = Team(ident: UUID(uuidString: "00000000-0000-0000-0000-000000004102")!, name: "Deletion Home", coach: "", details: "")
        let batter = Player(identifier: UUID(uuidString: "00000000-0000-0000-0000-000000004201")!, name: "Deletion Batter", number: "7", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let pitcher = Player(identifier: UUID(uuidString: "00000000-0000-0000-0000-000000004202")!, name: "Deletion Pitcher", number: "11", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let deletedGame = Game(
            ident: UUID(uuidString: "00000000-0000-0000-0000-000000004301")!,
            date: "2026-08-01T12:00:00Z",
            location: "Deleted Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: visitingTeam,
            hteam: homeTeam,
            players: [batter, pitcher]
        )
        let survivingGame = Game(
            ident: UUID(uuidString: "00000000-0000-0000-0000-000000004302")!,
            date: "2026-08-02T12:00:00Z",
            location: "Surviving Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: visitingTeam,
            hteam: homeTeam,
            players: [batter, pitcher]
        )
        let deletedAtbats = makeOutAtbats(
            game: deletedGame,
            team: visitingTeam,
            player: batter,
            idPrefix: "00000000-0000-0000-0000-0000000043",
            innings: [0],
            startingSequence: 1
        )
        let survivingAtbats = makeOutAtbats(
            game: survivingGame,
            team: visitingTeam,
            player: batter,
            idPrefix: "00000000-0000-0000-0000-0000000044",
            innings: [0, 1],
            startingSequence: 1
        )
        let deletedPitcher = Pitcher(
            ident: UUID(uuidString: "00000000-0000-0000-0000-000000004601")!,
            player: pitcher,
            team: homeTeam,
            game: deletedGame,
            startInn: 1,
            endInn: 1,
            eOuts: 3,
            eBats: 3
        )
        let survivingPitcher = Pitcher(
            ident: UUID(uuidString: "00000000-0000-0000-0000-000000004602")!,
            player: pitcher,
            team: homeTeam,
            game: survivingGame,
            startInn: 1,
            endInn: 2,
            eOuts: 3,
            eBats: 6
        )
        let deletedLineup = Lineup(ident: UUID(uuidString: "00000000-0000-0000-0000-000000004501")!, everyoneHits: false, game: deletedGame, team: visitingTeam, inning: 1, players: [batter])
        let survivingLineup = Lineup(ident: UUID(uuidString: "00000000-0000-0000-0000-000000004502")!, everyoneHits: false, game: survivingGame, team: visitingTeam, inning: 1, players: [batter])

        visitingTeam.players = [batter]
        homeTeam.players = [pitcher]
        visitingTeam.games = [deletedGame, survivingGame]
        homeTeam.games = [deletedGame, survivingGame]
        deletedGame.atbats = deletedAtbats
        deletedGame.pitchers = [deletedPitcher]
        deletedGame.lineups = [deletedLineup]
        survivingGame.atbats = survivingAtbats
        survivingGame.pitchers = [survivingPitcher]
        survivingGame.lineups = [survivingLineup]

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(batter)
        context.insert(pitcher)
        context.insert(deletedGame)
        context.insert(survivingGame)
        (deletedAtbats + survivingAtbats).forEach(context.insert)
        context.insert(deletedPitcher)
        context.insert(survivingPitcher)
        context.insert(deletedLineup)
        context.insert(survivingLineup)

        return AggregateDeletionFixture(
            deletedGameID: deletedGame.ident,
            survivingGameID: survivingGame.ident,
            visitingTeamName: visitingTeam.name,
            homeTeamName: homeTeam.name
        )
    }

    private func makeOutAtbats(
        game: Game,
        team: Team,
        player: Player,
        idPrefix: String,
        innings: [Int],
        startingSequence: Int
    ) -> [Atbat] {
        var sequence = startingSequence
        var atbats: [Atbat] = []

        for inning in innings {
            for outs in 1...3 {
                let suffix = String(format: "%02d", sequence)
                atbats.append(Atbat(
                    ident: UUID(uuidString: "\(idPrefix)\(suffix)")!,
                    game: game,
                    team: team,
                    player: player,
                    result: "Strikeout",
                    maxbase: "Out",
                    batOrder: 1,
                    outAt: "",
                    inning: CGFloat(inning),
                    seq: sequence,
                    col: sequence,
                    rbis: 0,
                    outs: outs,
                    sacFly: 0,
                    sacBunt: 0,
                    stolenBases: 0
                ))
                sequence += 1
            }
        }

        return atbats
    }

    private func aggregateDeletionSnapshot(from container: ModelContainer, teamName: String, pitchingTeamName: String) throws -> AggregateDeletionSnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>())
        let allAtbats = try context.fetch(FetchDescriptor<Atbat>())
        let allLineups = try context.fetch(FetchDescriptor<Lineup>())
        let allPitchers = try context.fetch(FetchDescriptor<Pitcher>())
        var hittingFetch = FetchDescriptor<Atbat>()
        hittingFetch.predicate = #Predicate { $0.team.name == teamName }
        var pitchingFetch = FetchDescriptor<Pitcher>()
        pitchingFetch.predicate = #Predicate { $0.team.name == pitchingTeamName }

        let reportAtbats = try context.fetch(hittingFetch)
        let reportPitchers = try context.fetch(pitchingFetch)

        return AggregateDeletionSnapshot(
            gameIDs: games.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            hittingAtbatIDsByGame: Dictionary(grouping: reportAtbats, by: { $0.game.ident })
                .mapValues { $0.map(\.ident).sorted { $0.uuidString < $1.uuidString } },
            pitcherIDsByGame: Dictionary(grouping: reportPitchers, by: { $0.game.ident })
                .mapValues { $0.map(\.ident).sorted { $0.uuidString < $1.uuidString } },
            reportPitchingInnings: reportPitchers.reduce(0) { $0 + pitchingInnings(for: $1) },
            allAtbatGameIDs: Array(Set(allAtbats.map { $0.game.ident })).sorted { $0.uuidString < $1.uuidString },
            allLineupGameIDs: Array(Set(allLineups.map { $0.game.ident })).sorted { $0.uuidString < $1.uuidString },
            allPitcherGameIDs: Array(Set(allPitchers.map { $0.game.ident })).sorted { $0.uuidString < $1.uuidString }
        )
    }

    private func pitchingInnings(for pitcher: Pitcher) -> Int {
        let opposingAtbats = pitcher.game.atbats.filter { $0.team != pitcher.team }
        guard opposingAtbats.isEmpty == false else {
            return 0
        }

        let endInning = pitcher.endInn > 0 ? pitcher.endInn : Int(opposingAtbats[opposingAtbats.count - 1].inning) + 1
        return opposingAtbats.filter {
            Common().outresults.contains($0.result)
                && (10 * (Int($0.inning + 1)) + $0.outs >= (10 * pitcher.startInn) + pitcher.sOuts)
                && (
                    10 * (Int($0.inning + 1)) + $0.outs <= (10 * endInning) + pitcher.eOuts
                    || (Int($0.inning) == endInning - 1 && $0.outs == 3)
                )
        }.count / 3
    }
}
