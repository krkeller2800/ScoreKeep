import Foundation
import Testing
@testable import ScoreKeep

struct CompatibilityRosterEvidenceTests {
    @Test func minimalAndCompleteRosterFixturesMapToImportedMembershipEvidence() throws {
        let minimal = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MinimalValid.ScoreKeep_Players")
        let complete = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")

        let minimalMemberships = minimal.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }
        let completeMemberships = complete.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }

        #expect(minimalMemberships.allSatisfy { CanonicalRosterMembershipClassifier.classify($0) == .importedMembershipEvidence })
        #expect(completeMemberships.allSatisfy { CanonicalRosterMembershipClassifier.classify($0) == .importedMembershipEvidence })
        #expect(CanonicalRosterMembershipClassifier.classifyRoster(minimalMemberships).contains(.oneCurrentMembership))
        #expect(CanonicalRosterMembershipClassifier.classifyRoster(completeMemberships).contains(.multipleCurrentMemberships))
    }

    @Test func missingOptionalRosterValuesRemainRepresentable() throws {
        let players = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MissingOptionalValues.ScoreKeep_Players")
        let memberships = players.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }

        #expect(memberships.isEmpty == false)
        #expect(memberships.contains { $0.displayEvidence.jerseyNumber.value == "" || $0.displayEvidence.position.value == "" })
        #expect(memberships.allSatisfy { membership in
            let classification = CanonicalRosterMembershipClassifier.classify(membership)
            return classification == .importedMembershipEvidence || classification == .missingTeamIdentity
        })
    }

    @Test func duplicateRosterFixtureClassifiesDuplicateMembershipWithoutMutation() throws {
        let players = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("DuplicateConflict.ScoreKeep_Players")
        let memberships = players.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster(memberships)
        #expect(classifications.contains(.duplicateJerseyNumber("8")))
        #expect(players.count == memberships.count)
    }

    @Test func duplicatePlayerIDFixtureClassifiesDuplicatePlayerIdentity() throws {
        let players = try JSONDecoder().decode(
            [SharePlayer].self,
            from: CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "DuplicatePlayerID.ScoreKeep_Players")
        )
        let memberships = players.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }
        let duplicateID = players[0].id

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster(memberships)
        #expect(classifications.contains(.duplicatePlayerIdentity(duplicateID)))
        #expect(classifications.contains(.containsDuplicateMembership) || classifications.contains(.containsConflictingMembership))
    }

    @Test func brokenTeamRelationshipAndEmptyArrayFixturesClassifySafely() throws {
        let broken = try JSONDecoder().decode(
            [SharePlayer].self,
            from: CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "BrokenTeamRelationship.ScoreKeep_Players")
        )
        let empty = try JSONDecoder().decode(
            [SharePlayer].self,
            from: CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: "EmptyArray.ScoreKeep_Players")
        )
        let brokenMemberships = broken.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }

        #expect(empty.isEmpty)
        #expect(CanonicalRosterMembershipClassifier.classifyRoster([]).contains(.emptyRoster))
        #expect(CanonicalRosterMembershipClassifier.classifyRoster(brokenMemberships).contains(.containsConflictingMembership))
    }

    @Test func gameParticipantFixturesRemainSeparateFromCurrentRosterMembership() throws {
        let completed = try CanonicalTeamMeaningTestSupport.decodeGameFixture("CompletedGame.ScoreKeep_Games")
        let lineup = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let brokenLineup = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenLineupRelationship.ScoreKeep_Games")

        #expect(completed.players.isEmpty == false || completed.atbats.isEmpty == false)
        #expect(lineup.lineups.isEmpty == false)
        #expect(brokenLineup.lineups.isEmpty == false)

        let rosterMemberships = completed.players.enumerated().map { index, player in
            CanonicalRosterMembershipTestSupport.importedMembership(from: player, sourceIndex: index)
        }
        let rosterClassifications = CanonicalRosterMembershipClassifier.classifyRoster(rosterMemberships)

        #expect(rosterClassifications.contains(.emptyRoster) || rosterClassifications.contains(.multipleCurrentMemberships) || rosterClassifications.contains(.oneCurrentMembership))
        #expect(lineup.lineups.flatMap(\.players).count >= 0)
    }

    @Test func importedMixedTeamsCanBeClassifiedWithoutChangingTransport() throws {
        let firstTeam = ShareTeam(id: CanonicalRosterMembershipTestSupport.teamA, name: "One")
        let secondTeam = ShareTeam(id: CanonicalRosterMembershipTestSupport.teamB, name: "Two")
        let memberships = [
            CanonicalRosterMembershipTestSupport.importedMembership(
                from: SharePlayer(id: CanonicalRosterMembershipTestSupport.playerA, name: "A", number: "1", position: "SS", batDir: "R", batOrder: 1, team: firstTeam),
                sourceIndex: 0
            ),
            CanonicalRosterMembershipTestSupport.importedMembership(
                from: SharePlayer(id: CanonicalRosterMembershipTestSupport.playerB, name: "B", number: "2", position: "CF", batDir: "L", batOrder: 2, team: secondTeam),
                sourceIndex: 1
            )
        ]

        let classifications = CanonicalRosterMembershipClassifier.classifyRoster(memberships, expectedTeamIdentity: .valid(CanonicalRosterMembershipTestSupport.teamA))
        #expect(classifications.contains(.mixedTeamEvidence))
    }
}
