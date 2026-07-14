import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct CompatibilityPlayerEvidenceTests {
    @Test("roster fixtures map to reusable player evidence without persistence writes")
    func rosterFixturesMapToReusablePlayerEvidenceWithoutPersistenceWrites() throws {
        let complete = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let minimal = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MinimalValid.ScoreKeep_Players")
        let media = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MediaRoster.ScoreKeep_Players")
        let first = try #require(complete.first)
        let firstPlayer = CanonicalPlayerMeaningTestSupport.reusablePlayer(from: first, source: .importedRoster)
        let mediaPlayer = try #require(media.first.map { CanonicalPlayerMeaningTestSupport.reusablePlayer(from: $0, source: .importedRoster) })
        let environment = try IsolatedPersistenceEnvironment()

        #expect(firstPlayer.identity == .valid(first.id))
        #expect(firstPlayer.display.name == .present(first.name))
        #expect(firstPlayer.display.jerseyNumber == .present(first.number))
        #expect(firstPlayer.display.position == .present(first.position))
        #expect(firstPlayer.display.battingDirection == .present(first.batDir))
        #expect(minimal.isEmpty == false)
        #expect(mediaPlayer.display.photo != .missing)
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Team>()).isEmpty)
    }

    @Test("duplicate and conflicting roster player evidence remains classified")
    func duplicateAndConflictingRosterPlayerEvidenceRemainsClassified() throws {
        let duplicateConflict = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("DuplicateConflict.ScoreKeep_Players")
        let duplicateIDData = try CanonicalTeamMeaningTestSupport.fixtureData(
            directory: "MalformedAndUnsupported",
            filename: "DuplicatePlayerID.ScoreKeep_Players"
        )
        let duplicateIDPlayers = try JSONDecoder().decode([SharePlayer].self, from: duplicateIDData)
        let conflictPlayers = duplicateConflict.map { CanonicalPlayerMeaningTestSupport.reusablePlayer(from: $0, source: .importedRoster) }
        let duplicatePlayers = duplicateIDPlayers.map { CanonicalPlayerMeaningTestSupport.reusablePlayer(from: $0, source: .importedRoster) }
        let classifications = CanonicalPlayerMeaningClassifier.classifyDuplicates(conflictPlayers + duplicatePlayers)

        #expect(classifications.contains(.duplicateIdentifierConflictingDisplay(["battingDirection", "jerseyNumber", "name", "position"])))
    }

    @Test("missing optional and invalid media player evidence remains representable")
    func missingOptionalAndInvalidMediaPlayerEvidenceRemainsRepresentable() throws {
        let missingOptional = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MissingOptionalValues.ScoreKeep_Players")
        let first = try #require(missingOptional.first)
        let missingPlayer = CanonicalPlayerMeaningTestSupport.reusablePlayer(from: first, source: .importedRoster)
        let invalidPhotoData = try CanonicalTeamMeaningTestSupport.fixtureData(
            directory: "MalformedAndUnsupported",
            filename: "InvalidBase64Photo.ScoreKeep_Players"
        )
        let invalidPhotoDecodes = (try? JSONDecoder().decode([SharePlayer].self, from: invalidPhotoData)) != nil
        let invalidMedia = PlayerDisplayEvidence(
            name: .present("Fixture Media Player"),
            jerseyNumber: .present("9"),
            position: .present("P"),
            battingDirection: .present("R"),
            photo: .invalid("invalid or unreadable imported media")
        )

        #expect(missingPlayer.identity.validIdentifier != nil)
        #expect(missingPlayer.display.name.value != nil)
        #expect(invalidPhotoDecodes == false)
        #expect(invalidMedia.photo == .invalid("invalid or unreadable imported media"))
    }

    @Test("game fixtures map player participation roles without mutating records")
    func gameFixturesMapPlayerParticipationRolesWithoutMutatingRecords() throws {
        let completed = try CanonicalTeamMeaningTestSupport.decodeGameFixture("CompletedGame.ScoreKeep_Games")
        let multipleAtbats = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MultipleAtbats.ScoreKeep_Games")
        let lineupGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let pitcherGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("PitcherGame.ScoreKeep_Games")
        let batter = try #require(multipleAtbats.atbats.first?.player)
        let pitcher = try #require(pitcherGame.pitchers.first?.player)
        let lineupPlayer = try #require(lineupGame.lineups.first?.players.first)
        let batterParticipant = participant(from: batter, game: multipleAtbats, roles: [.batter])
        let pitcherParticipant = participant(from: pitcher, game: pitcherGame, roles: [.pitcher])
        let lineupParticipant = participant(from: lineupPlayer, game: lineupGame, roles: [.lineupParticipant])
        let environment = try IsolatedPersistenceEnvironment()

        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(batterParticipant) == .resolvedParticipant)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(pitcherParticipant) == .resolvedParticipant)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(lineupParticipant) == .resolvedParticipant)
        #expect(batterParticipant.roles == [.batter])
        #expect(pitcherParticipant.roles == [.pitcher])
        #expect(lineupParticipant.roles == [.lineupParticipant])
        #expect(completed.replaced.isEmpty)
        #expect(completed.incomings.isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Game>()).isEmpty)
    }

    @Test("broken game child relationships become unresolved participant evidence")
    func brokenGameChildRelationshipsBecomeUnresolvedParticipantEvidence() throws {
        let brokenAtbat = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenAtbatRelationship.ScoreKeep_Games")
        let brokenLineup = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenLineupRelationship.ScoreKeep_Games")
        let brokenPitcher = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenPitcherRelationship.ScoreKeep_Games")
        let missingDisplay = PlayerDisplayEvidence(name: .missing, jerseyNumber: .missing, position: .missing, battingDirection: .missing, photo: .missing)
        let atbatParticipant = unresolvedParticipant(gameID: brokenAtbat.id, display: missingDisplay, role: .batter)
        let lineupParticipant = unresolvedParticipant(gameID: brokenLineup.id, display: missingDisplay, role: .lineupParticipant)
        let pitcherParticipant = unresolvedParticipant(gameID: brokenPitcher.id, display: missingDisplay, role: .pitcher)

        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(atbatParticipant) == .missingReusablePlayerIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(lineupParticipant) == .missingReusablePlayerIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(pitcherParticipant) == .missingReusablePlayerIdentity)
    }

    @Test("player interpretation is deterministic across order sort team and role changes")
    func playerInterpretationIsDeterministicAcrossOrderSortTeamAndRoleChanges() throws {
        let roster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let fileOrder = roster.map { CanonicalPlayerMeaningTestSupport.reusablePlayer(from: $0, source: .importedRoster) }
        let reverseOrder = roster.reversed().map { CanonicalPlayerMeaningTestSupport.reusablePlayer(from: $0, source: .importedRoster) }
        let jerseySorted = fileOrder.sorted { lhs, rhs in
            (lhs.display.jerseyNumber.value ?? "") < (rhs.display.jerseyNumber.value ?? "")
        }
        let displaySorted = fileOrder.sorted { lhs, rhs in
            (lhs.display.name.value ?? "") < (rhs.display.name.value ?? "")
        }
        let player = try #require(fileOrder.first)
        let currentTeamChanged = ReusableCanonicalPlayer(
            identity: player.identity,
            display: player.display,
            rosterEvidence: .currentRelationship(teamIdentity: .valid(CanonicalPlayerMeaningTestSupport.teamB)),
            source: .currentReusableRecord
        )
        let batter = CanonicalPlayerMeaningTestSupport.participant(player: player, roles: [.batter])
        let pitcher = CanonicalPlayerMeaningTestSupport.participant(player: player, roles: [.pitcher])

        #expect(Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(fileOrder)) == Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(reverseOrder)))
        #expect(Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(fileOrder)) == Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(jerseySorted)))
        #expect(Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(fileOrder)) == Set(CanonicalPlayerMeaningClassifier.classifyDuplicates(displaySorted)))
        #expect(player == currentTeamChanged)
        #expect(batter.reusablePlayerIdentity == pitcher.reusablePlayerIdentity)
        #expect(batter.roles != pitcher.roles)
    }

    private func participant(from sharePlayer: SharePlayer, game: ShareGame, roles: Set<PlayerParticipantRole>) -> GamePlayerParticipation {
        let reusable = CanonicalPlayerMeaningTestSupport.reusablePlayer(from: sharePlayer, source: .importedGame)
        return GamePlayerParticipation(
            participantIdentity: .valid(sharePlayer.id),
            gameIdentity: .valid(game.id),
            playerResolution: .reusablePlayer(reusable),
            teamEvidence: sharePlayer.team.map { team in
                .currentReusableTeam(ReusableCanonicalTeam(
                    identity: .valid(team.id),
                    display: TeamDisplayEvidence(name: .present(team.name), coach: .present(team.coach), details: .present(team.details), logo: team.logo.isEmpty ? .missing : .present(team.logo)),
                    source: .importedGame
                ))
            } ?? .missing,
            historicalDisplay: CanonicalPlayerMeaningTestSupport.display(from: sharePlayer),
            roles: roles,
            source: .importedGame
        )
    }

    private func unresolvedParticipant(gameID: UUID, display: PlayerDisplayEvidence, role: PlayerParticipantRole) -> GamePlayerParticipation {
        GamePlayerParticipation(
            gameIdentity: .valid(gameID),
            playerResolution: .missingIdentity(display),
            teamEvidence: .missing,
            historicalDisplay: display,
            roles: [role],
            source: .importedGame
        )
    }
}
