import Foundation
import Testing
@testable import ScoreKeep

struct LegacyCanonicalVerificationMappingTests {
    @Test func rosterFixturesMapReadOnlyAndPreserveIdentityEvidence() throws {
        let fixtureNames = [
            "MinimalValid.ScoreKeep_Players",
            "CompleteRoster.ScoreKeep_Players",
            "MissingOptionalValues.ScoreKeep_Players"
        ]

        for fixtureName in fixtureNames {
            let before = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Players", filename: fixtureName)
            let players = try JSONDecoder().decode([SharePlayer].self, from: before)
            let mapping = LegacyCanonicalVerificationMapper.mapRoster(players, sourceLocation: fixtureName)
            let after = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Players", filename: fixtureName)

            #expect(before == after)
            #expect(mapping.players.count == players.count)
            #expect(mapping.memberships.count == players.count)
            #expect(mapping.players.allSatisfy { $0.canonicalValue != nil })
            #expect(mapping.players.map(\.sourceIdentity) == players.map { ImportedIdentifierEvidence.valid($0.id) })
            #expect(mapping.validation.processingMayContinueReadOnly)
            #expect(mapping == LegacyCanonicalVerificationMapper.mapRoster(players, sourceLocation: fixtureName))
        }
    }

    @Test func malformedRosterFixturesClassifyDuplicatesBrokenRelationshipsAndEmptyRostersSafely() throws {
        let duplicateData = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "DuplicatePlayerID.ScoreKeep_Players")
        let duplicatePlayers = try JSONDecoder().decode([SharePlayer].self, from: duplicateData)
        let duplicateMapping = LegacyCanonicalVerificationMapper.mapRoster(duplicatePlayers, sourceLocation: "DuplicatePlayerID.ScoreKeep_Players")

        let brokenData = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "BrokenTeamRelationship.ScoreKeep_Players")
        let brokenPlayers = try JSONDecoder().decode([SharePlayer].self, from: brokenData)
        let brokenMapping = LegacyCanonicalVerificationMapper.mapRoster(brokenPlayers, sourceLocation: "BrokenTeamRelationship.ScoreKeep_Players")

        let emptyData = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "EmptyArray.ScoreKeep_Players")
        let emptyPlayers = try JSONDecoder().decode([SharePlayer].self, from: emptyData)
        let emptyMapping = LegacyCanonicalVerificationMapper.mapRoster(emptyPlayers, sourceLocation: "EmptyArray.ScoreKeep_Players")

        #expect(duplicateData == (try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "DuplicatePlayerID.ScoreKeep_Players")))
        #expect(duplicateMapping.validation.disposition == .contradictory)
        #expect(duplicateMapping.memberships.count == duplicatePlayers.count)
        #expect(brokenMapping.validation.processingMayContinueReadOnly || brokenMapping.validation.futureWriteMustStop)
        #expect(brokenMapping.memberships.count == brokenPlayers.count)
        #expect(emptyPlayers.isEmpty)
        #expect(emptyMapping.validation.disposition == .validWithWarnings)
        #expect(emptyMapping.players.isEmpty)
    }

    @Test func validGameFixturesMapCanonicalGameLineupsEventsPitchersAndSubstitutionsReadOnly() throws {
        let fixtureNames = [
            "MinimalValid.ScoreKeep_Games",
            "CompletedGame.ScoreKeep_Games",
            "InProgressGame.ScoreKeep_Games",
            "MultipleAtbats.ScoreKeep_Games",
            "LineupGame.ScoreKeep_Games",
            "PitcherGame.ScoreKeep_Games"
        ]

        for fixtureName in fixtureNames {
            let before = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Games", filename: fixtureName)
            let game = try JSONDecoder().decode(ShareGame.self, from: before)
            let mapping = LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: fixtureName)
            let after = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Games", filename: fixtureName)

            #expect(before == after)
            #expect(mapping.game.canonicalValue != nil)
            #expect(mapping.game.sourceIdentity == .valid(game.id))
            #expect(mapping.players.count == game.players.count)
            #expect(mapping.lineups.count == game.lineups.count)
            #expect(mapping.scoringEvents.count == game.atbats.count)
            #expect(mapping.pitcherAppearances.count == game.pitchers.count)
            #expect(mapping.substitutions.count == max(game.incomings.count, game.replaced.count))
            #expect(mapping.validation.processingMayContinueReadOnly || mapping.validation.futureWriteMustStop)
            #expect(mapping == LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: fixtureName))
        }
    }

    @Test func brokenGameFixturesRemainUnresolvedContradictoryOrRejectedWithoutRepair() throws {
        let fixtureNames = [
            "DuplicateAtbatID.ScoreKeep_Games",
            "BrokenAtbatRelationship.ScoreKeep_Games",
            "BrokenLineupRelationship.ScoreKeep_Games",
            "BrokenPitcherRelationship.ScoreKeep_Games",
            "ConflictingTeamIdentity.ScoreKeep_Games",
            "UnsupportedScoreValue.ScoreKeep_Games"
        ]

        for fixtureName in fixtureNames {
            let before = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: fixtureName)
            let game = try JSONDecoder().decode(ShareGame.self, from: before)
            let mapping = LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: fixtureName)
            let after = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: fixtureName)

            #expect(before == after)
            #expect(mapping.game.canonicalValue != nil)
            #expect(mapping.validation.disposition != .valid || mapping.validation.findings.isEmpty == false)
            #expect(mapping.validation.futureWriteMustStop || mapping.validation.processingMayContinueReadOnly)
            #expect(mapping.players.allSatisfy { $0.sourceIdentity.validIdentifier != nil })
            #expect(mapping == LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: fixtureName))
        }
    }

    @Test func duplicateConflictAndUnsupportedCompatibilityValuesRemainPreservedForComparison() throws {
        let duplicate = try CanonicalTeamMeaningTestSupport.decodeGameFixture("DuplicateConflict.ScoreKeep_Games")
        let duplicateMapping = LegacyCanonicalVerificationMapper.mapGame(duplicate, sourceLocation: "DuplicateConflict.ScoreKeep_Games")
        let unsupportedData = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "UnsupportedScoreValue.ScoreKeep_Games")
        let unsupported = try JSONDecoder().decode(ShareGame.self, from: unsupportedData)
        let unsupportedMapping = LegacyCanonicalVerificationMapper.mapGame(unsupported, sourceLocation: "UnsupportedScoreValue.ScoreKeep_Games")
        let unsupportedRawValues = unsupportedMapping.scoringEvents.flatMap(\.unsupportedRawEvidence)
        let syntheticUnsupported = LegacyCanonicalVerificationMapper.mapScoringEvent(
            LegacyAtbatEvidenceSnapshot(
                identity: .valid(StableIdentityAndOrderingTestSupport.eventA),
                gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
                teamIdentity: .valid(StableIdentityAndOrderingTestSupport.teamA),
                player: LegacyPlayerEvidenceSnapshot(identity: .valid(StableIdentityAndOrderingTestSupport.playerA), name: "Casey"),
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
            ),
            source: .compatibilityTransport
        )

        #expect(duplicateMapping.validation.disposition == .contradictory || duplicateMapping.validation.disposition == .validWithWarnings || duplicateMapping.validation.processingMayContinueReadOnly)
        #expect(unsupportedMapping.validation.processingMayContinueReadOnly || unsupportedMapping.validation.futureWriteMustStop)
        #expect(unsupportedRawValues.allSatisfy { $0.isEmpty == false })
        #expect(syntheticUnsupported.validation.containsUnsupportedEvidence)
        #expect(syntheticUnsupported.unsupportedRawEvidence.contains("result=Balkish"))
        #expect(unsupportedMapping.scoringEvents.allSatisfy { $0.preservedRawEvidence["result"] != nil })
    }

    @Test func swiftDataStyleSnapshotsMapWithoutAccessingAStoreOrFabricatingIdentity() {
        let team = Team(ident: StableIdentityAndOrderingTestSupport.teamA, name: "Tigers", coach: "Coach", details: "Details")
        let player = Player(identifier: StableIdentityAndOrderingTestSupport.playerA, name: "Casey", number: "8", position: "SS", batDir: "R", batOrder: 1, team: team)
        team.players = [player]
        let game = Game(ident: StableIdentityAndOrderingTestSupport.gameA, date: "2026-07-15", location: "Field", highLights: "", hscore: 1, vscore: 0, everyOneHits: false, numInnings: 7, vteam: Team(ident: StableIdentityAndOrderingTestSupport.teamB, name: "Hawks", coach: "", details: ""), hteam: team, players: [player])
        let lineup = Lineup(ident: StableIdentityAndOrderingTestSupport.fixedUUID("41000000-0000-0000-0000-000000000010"), everyoneHits: false, game: game, team: team, inning: 1, players: [player])
        let atbat = Atbat(ident: StableIdentityAndOrderingTestSupport.eventA, game: game, team: team, player: player, result: "Single", maxbase: "First", batOrder: 1, outAt: "", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        let pitcher = Pitcher(ident: StableIdentityAndOrderingTestSupport.fixedUUID("50000000-0000-0000-0000-000000000010"), player: player, team: team, game: game, startInn: 1, sOuts: 0, sBats: 0)

        let teamMapping = LegacyCanonicalVerificationMapper.mapTeam(LegacyTeamEvidenceSnapshot(team: team))
        let playerMapping = LegacyCanonicalVerificationMapper.mapPlayer(LegacyPlayerEvidenceSnapshot(player: player))
        let membershipMapping = LegacyCanonicalVerificationMapper.mapRosterMembership(LegacyPlayerEvidenceSnapshot(player: player))
        let gameSnapshot = LegacyGameEvidenceSnapshot(game: game)
        let gameMapping = LegacyCanonicalVerificationMapper.mapGameIdentity(gameSnapshot)
        let homeSide = GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .home, resolution: .reusableTeam(teamMapping.canonicalValue!))
        let visitingSide = GameSideTeamParticipation(gameIdentity: .valid(game.ident), role: .visiting, resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid(StableIdentityAndOrderingTestSupport.teamB))))
        let lineupMapping = LegacyCanonicalVerificationMapper.mapLineup(LegacyLineupEvidenceSnapshot(lineup: lineup), homeSide: homeSide, visitingSide: visitingSide)
        let eventMapping = LegacyCanonicalVerificationMapper.mapScoringEvent(LegacyAtbatEvidenceSnapshot(atbat: atbat))
        let pitcherMapping = LegacyCanonicalVerificationMapper.mapPitcherAppearance(LegacyPitcherEvidenceSnapshot(pitcher: pitcher), homeSide: homeSide, visitingSide: visitingSide)

        #expect(teamMapping.sourceIdentity == .valid(team.ident))
        #expect(playerMapping.sourceIdentity == .valid(player.identifier))
        #expect(membershipMapping.sourceIdentity == .valid(player.identifier))
        #expect(gameMapping.sourceIdentity == .valid(game.ident))
        #expect(lineupMapping.sourceIdentity == .valid(lineup.ident))
        #expect(eventMapping.sourceIdentity == .valid(atbat.ident))
        #expect(pitcherMapping.sourceIdentity == .valid(pitcher.ident))
        #expect([teamMapping.validation, playerMapping.validation, membershipMapping.validation, gameMapping.validation, lineupMapping.validation, eventMapping.validation, pitcherMapping.validation].allSatisfy { $0.processingMayContinueReadOnly })
        #expect(player.identifier == StableIdentityAndOrderingTestSupport.playerA)
        #expect(game.atbats.isEmpty)
    }

    @Test func missingSnapshotIdentityStaysMissingRatherThanGenerated() {
        let snapshot = LegacyPlayerEvidenceSnapshot(identity: .missing, name: "No ID", number: "12", position: "CF", battingDirection: "L", battingOrder: 1)
        let mapping = LegacyCanonicalVerificationMapper.mapPlayer(snapshot)

        #expect(mapping.sourceIdentity == .missing)
        #expect(mapping.canonicalValue?.identity == .missing)
        #expect(mapping.validation.disposition == .incomplete)
        #expect(mapping.futureWriteOrImportMustStop == false)
    }
}
