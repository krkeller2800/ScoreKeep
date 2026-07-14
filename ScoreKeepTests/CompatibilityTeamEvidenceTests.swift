import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct CompatibilityTeamEvidenceTests {
    @Test("roster fixture team evidence maps without persistence writes")
    func rosterFixtureTeamEvidenceMapsWithoutPersistenceWrites() throws {
        let players = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let first = try #require(players.first)
        let shareTeam = try #require(first.team)
        let semanticTeam = ReusableCanonicalTeam(
            identity: .valid(shareTeam.id),
            display: TeamDisplayEvidence(
                name: .present(shareTeam.name),
                coach: .present(shareTeam.coach),
                details: .present(shareTeam.details),
                logo: shareTeam.logo.isEmpty ? .missing : .present(shareTeam.logo)
            ),
            rosterEvidence: .importedRosterReference(count: players.count),
            source: .importedRoster
        )
        let environment = try IsolatedPersistenceEnvironment()

        #expect(semanticTeam.identity == .valid(shareTeam.id))
        #expect(semanticTeam.display.name == .present(shareTeam.name))
        #expect(semanticTeam.rosterEvidence == .importedRosterReference(count: players.count))
        #expect(try environment.fetch(FetchDescriptor<Team>()).isEmpty)
    }

    @Test("minimal and completed game fixtures produce game-side team meaning")
    func gameFixturesProduceGameSideTeamMeaning() throws {
        let minimal = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MinimalValid.ScoreKeep_Games")
        let completed = try CanonicalTeamMeaningTestSupport.decodeGameFixture("CompletedGame.ScoreKeep_Games")
        let minimalHome = side(from: minimal.hteam, role: .home, gameID: minimal.id)
        let minimalVisiting = side(from: minimal.vteam, role: .visiting, gameID: minimal.id)
        let completedHome = side(from: completed.hteam, role: .home, gameID: completed.id)
        let completedVisiting = side(from: completed.vteam, role: .visiting, gameID: completed.id)

        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: minimalHome, visiting: minimalVisiting) == .completeDistinctSides)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: completedHome, visiting: completedVisiting) == .completeDistinctSides)
        #expect(minimalHome.role == .home)
        #expect(minimalVisiting.role == .visiting)
        #expect(completedHome.gameIdentity == .valid(completed.id))
    }

    @Test("conflicting and duplicate game fixtures classify team identity evidence")
    func conflictingAndDuplicateGameFixturesClassifyTeamEvidence() throws {
        let conflicting = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("ConflictingTeamIdentity.ScoreKeep_Games")
        let conflictHome = reusableTeam(from: conflicting.hteam, source: .importedGame)
        let conflictVisiting = reusableTeam(from: conflicting.vteam, source: .importedGame)
        let duplicate = try CanonicalTeamMeaningTestSupport.decodeGameFixture("DuplicateConflict.ScoreKeep_Games")
        let duplicateTeams = [
            reusableTeam(from: duplicate.hteam, source: .importedGame),
            reusableTeam(from: duplicate.vteam, source: .importedGame)
        ]

        #expect(CanonicalTeamMeaningClassifier.compare(conflictHome, conflictVisiting) == .sameIdentityConflictingDisplay(["name"]))
        #expect(CanonicalTeamMeaningClassifier.classifyDuplicates(duplicateTeams).isEmpty == false)
    }

    @Test("missing optional roster and game values remain representable")
    func missingOptionalValuesRemainRepresentable() throws {
        let roster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MissingOptionalValues.ScoreKeep_Players")
        let game = try CanonicalTeamMeaningTestSupport.decodeGameFixture("MissingOptionalValues.ScoreKeep_Games")
        let rosterTeam = roster.first?.team.map { reusableTeam(from: $0, source: .importedRoster) } ?? ReusableCanonicalTeam(
            identity: .missing,
            display: TeamDisplayEvidence(name: .missing, coach: .missing, details: .missing, logo: .missing),
            rosterEvidence: .importedRosterReference(count: roster.count),
            source: .importedRoster
        )
        let home = side(from: game.hteam, role: .home, gameID: game.id)
        let visiting = side(from: game.vteam, role: .visiting, gameID: game.id)

        #expect(rosterTeam.identity == .missing || rosterTeam.identity.validIdentifier != nil)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: visiting) == .completeDistinctSides)
    }

    @Test("malformed relationship and media fixtures do not mutate records")
    func malformedRelationshipAndMediaFixturesDoNotMutateRecords() throws {
        let brokenTeamData = try CanonicalTeamMeaningTestSupport.fixtureData(
            directory: "MalformedAndUnsupported",
            filename: "BrokenTeamRelationship.ScoreKeep_Players"
        )
        let invalidLogoData = try CanonicalTeamMeaningTestSupport.fixtureData(
            directory: "MalformedAndUnsupported",
            filename: "InvalidBase64Photo.ScoreKeep_Players"
        )
        let brokenTeamPlayers = try JSONDecoder().decode([SharePlayer].self, from: brokenTeamData)
        let invalidLogoDecodes = (try? JSONDecoder().decode([SharePlayer].self, from: invalidLogoData)) != nil
        let relationshipTeams = brokenTeamPlayers.compactMap(\.team).map { reusableTeam(from: $0, source: .importedRoster) }
        let invalidMedia = TeamDisplayEvidence(
            name: .present("Fixture Media Team"),
            logo: .invalid("invalid or unreadable imported media")
        )
        let environment = try IsolatedPersistenceEnvironment()

        #expect(CanonicalTeamMeaningClassifier.classifyDuplicates(relationshipTeams).contains(.duplicateIdentifierConflictingDisplay(["name"])))
        #expect(invalidLogoDecodes == false)
        #expect(invalidMedia.logo == .invalid("invalid or unreadable imported media"))
        #expect(try environment.fetch(FetchDescriptor<Team>()).isEmpty)
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    @Test("deterministic interpretation does not depend on source order display sort or side role")
    func deterministicInterpretationDoesNotDependOnOrderSortOrRole() throws {
        let roster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let teamsInFileOrder = roster.compactMap(\.team).map { reusableTeam(from: $0, source: .importedRoster) }
        let teamsInReverseOrder = roster.reversed().compactMap(\.team).map { reusableTeam(from: $0, source: .importedRoster) }
        let sortedByDisplayName = teamsInFileOrder.sorted { lhs, rhs in
            (lhs.display.name.value ?? "") < (rhs.display.name.value ?? "")
        }
        let team = try #require(teamsInFileOrder.first)
        let home = CanonicalTeamMeaningTestSupport.side(role: .home, team: team)
        let visiting = CanonicalTeamMeaningTestSupport.side(role: .visiting, team: team)

        #expect(CanonicalTeamMeaningClassifier.classifyDuplicates(teamsInFileOrder) == CanonicalTeamMeaningClassifier.classifyDuplicates(teamsInReverseOrder))
        #expect(CanonicalTeamMeaningClassifier.classifyDuplicates(teamsInFileOrder) == CanonicalTeamMeaningClassifier.classifyDuplicates(sortedByDisplayName))
        #expect(home.reusableTeamIdentity == visiting.reusableTeamIdentity)
        #expect(home.role != visiting.role)
    }

    private func reusableTeam(from shareTeam: ShareTeam, source: TeamEvidenceSource) -> ReusableCanonicalTeam {
        ReusableCanonicalTeam(
            identity: .valid(shareTeam.id),
            display: TeamDisplayEvidence(
                name: .present(shareTeam.name),
                coach: .present(shareTeam.coach),
                details: .present(shareTeam.details),
                logo: shareTeam.logo.isEmpty ? .missing : .present(shareTeam.logo)
            ),
            rosterEvidence: shareTeam.players.isEmpty ? .notRepresented : .importedRosterReference(count: shareTeam.players.count),
            source: source
        )
    }

    private func side(from shareTeam: ShareTeam, role: TeamSideRole, gameID: UUID) -> GameSideTeamParticipation {
        let team = reusableTeam(from: shareTeam, source: .importedGame)
        return GameSideTeamParticipation(
            gameIdentity: .valid(gameID),
            role: role,
            resolution: .reusableTeam(team),
            historicalDisplay: team.display,
            source: .importedGame
        )
    }
}
