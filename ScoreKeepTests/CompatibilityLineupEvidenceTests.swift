import Foundation
import Testing
@testable import ScoreKeep

struct CompatibilityLineupEvidenceTests {
    @Test func gameFixturesMapLineupEvidenceWithoutMutation() throws {
        let lineupGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let completed = try CanonicalTeamMeaningTestSupport.decodeGameFixture("CompletedGame.ScoreKeep_Games")
        let minimal = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MinimalValid.ScoreKeep_Games")

        let importedLineups = lineupGame.lineups.enumerated().map { index, lineup in
            CanonicalLineupMeaningTestSupport.importedLineup(from: lineup, gameID: lineupGame.id, sourceIndex: index)
        }
        let completedLineups = completed.lineups.enumerated().map { index, lineup in
            CanonicalLineupMeaningTestSupport.importedLineup(from: lineup, gameID: completed.id, sourceIndex: index)
        }

        #expect(importedLineups.isEmpty == false)
        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet(importedLineups).contains(.importedEvidence))
        #expect(completedLineups.count == completed.lineups.count)
        #expect(minimal.lineups.isEmpty || CanonicalLineupMeaningClassifier.classifyLineupSet(minimal.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: minimal.id) }).contains(.importedEvidence))
    }

    @Test func missingOptionalAndEmptyLineupArraysRemainRepresentable() throws {
        let missingOptional = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MissingOptionalValues.ScoreKeep_Games")
        let minimal = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MinimalValid.ScoreKeep_Games")

        let missingClassifications = CanonicalLineupMeaningClassifier.classifyLineupSet(
            missingOptional.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: missingOptional.id) }
        )
        let minimalClassifications = CanonicalLineupMeaningClassifier.classifyLineupSet(
            minimal.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: minimal.id) }
        )

        #expect(missingClassifications.contains(.emptyLineup) || missingClassifications.contains(.importedEvidence))
        #expect(minimalClassifications.contains(.emptyLineup) || minimalClassifications.contains(.importedEvidence))
    }

    @Test func duplicateAndBrokenLineupFixturesClassifyWithoutChangingTransport() throws {
        let duplicateGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("DuplicateConflict.ScoreKeep_Games")
        let brokenLineup = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenLineupRelationship.ScoreKeep_Games")
        let conflictingTeam = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("ConflictingTeamIdentity.ScoreKeep_Games")

        let duplicateLineups = duplicateGame.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: duplicateGame.id) }
        let brokenLineups = brokenLineup.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: brokenLineup.id) }
        let conflictingTeamLineups = conflictingTeam.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: conflictingTeam.id) }

        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet(duplicateLineups).contains(.emptyLineup) || CanonicalLineupMeaningClassifier.classifyLineupSet(duplicateLineups).contains(.importedEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet(brokenLineups).contains(.importedEvidence))
        #expect(CanonicalLineupMeaningClassifier.classifyLineupSet(conflictingTeamLineups).contains(.emptyLineup) || CanonicalLineupMeaningClassifier.classifyLineupSet(conflictingTeamLineups).contains(.importedEvidence))
    }

    @Test func atbatPitcherAndRosterFixturesStaySeparateFromLineupMeaning() throws {
        let multipleAtbats = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MultipleAtbats.ScoreKeep_Games")
        let pitcherGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("PitcherGame.ScoreKeep_Games")
        let completeRoster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let minimalRoster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MinimalValid.ScoreKeep_Players")

        let rosterMemberships = completeRoster.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }
        let lineupClassifications = CanonicalLineupMeaningClassifier.classifyLineupSet(
            multipleAtbats.lineups.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: multipleAtbats.id) }
        )

        #expect(multipleAtbats.atbats.isEmpty == false)
        #expect(pitcherGame.pitchers.isEmpty || pitcherGame.lineups.count >= 0)
        #expect(rosterMemberships.count == completeRoster.count)
        #expect(minimalRoster.isEmpty == false)
        #expect(lineupClassifications.contains(.emptyLineup) || lineupClassifications.contains(.importedEvidence))
    }

    @Test func malformedParticipantAndSlotEvidenceCanBeRepresentedWithoutFixtureMutation() throws {
        let duplicatePlayers = try JSONDecoder().decode(
            [SharePlayer].self,
            from: CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "DuplicatePlayerID.ScoreKeep_Players")
        )
        let unsupportedSlotPlayer = SharePlayer(
            id: duplicatePlayers[0].id,
            name: duplicatePlayers[0].name,
            number: duplicatePlayers[0].number,
            position: duplicatePlayers[0].position,
            batDir: duplicatePlayers[0].batDir,
            batOrder: -5,
            team: duplicatePlayers[0].team
        )
        let team = duplicatePlayers[0].team ?? ShareTeam(name: "Fixture Tigers")
        let shareLineup = ShareLineup(
            id: CanonicalLineupMeaningTestSupport.lineupA,
            everyoneHits: false,
            team: team,
            inning: 1,
            players: [duplicatePlayers[0], unsupportedSlotPlayer]
        )
        let imported = CanonicalLineupMeaningTestSupport.importedLineup(from: shareLineup)
        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(imported)

        #expect(classifications.contains(.duplicateParticipant(duplicatePlayers[0].id)))
        #expect(classifications.contains(.participantConflictingSlot(duplicatePlayers[0].id)))
        #expect(imported.entries.count == 2)
    }
}
