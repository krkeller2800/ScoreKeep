import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct CompatibilityIdentityEvidenceTests {
    @Test("imported roster UUIDs are preserved as identity evidence")
    func importedRosterUUIDsArePreservedAsEvidence() throws {
        let fixtureURL = StableIdentityAndOrderingTestSupport.sourceFixtureURL(
            directory: "ScoreKeep_Players",
            filename: "CompleteRoster.ScoreKeep_Players"
        )
        let players = try JSONDecoder().decode([SharePlayer].self, from: Data(contentsOf: fixtureURL))
        let firstPlayer = try #require(players.first)
        let evidence = StableIdentityEvidence(
            concept: .player,
            importedIdentifier: .valid(firstPlayer.id),
            displayEvidence: [
                .init("name", firstPlayer.name),
                .init("number", firstPlayer.number)
            ]
        )
        let environment = try IsolatedPersistenceEnvironment()

        #expect(evidence.importedIdentifier == .valid(firstPlayer.id))
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    @Test("same-name roster records with different identifiers remain distinct")
    func sameNameRosterRecordsWithDifferentIdentifiersRemainDistinct() throws {
        let first = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Same Name",
            number: "5"
        )
        let second = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerB,
            name: "Fixture Same Name",
            number: "5"
        )

        #expect(StableIdentityClassifier.compare(first, second) == .differentIdentifiersMatchingDisplay)
    }

    @Test("duplicate roster player identifiers can be classified without merging")
    func duplicateRosterPlayerIdentifiersCanBeClassifiedWithoutMerging() throws {
        let fixtureURL = StableIdentityAndOrderingTestSupport.sourceFixtureURL(
            directory: "MalformedAndUnsupported",
            filename: "DuplicatePlayerID.ScoreKeep_Players"
        )
        let players = try JSONDecoder().decode([SharePlayer].self, from: Data(contentsOf: fixtureURL))
        let evidence = players.map {
            StableIdentityEvidence(
                concept: .player,
                importedIdentifier: .valid($0.id),
                displayEvidence: [
                    .init("name", $0.name),
                    .init("number", $0.number)
                ]
            )
        }
        let classifications = StableIdentityClassifier.classifyDuplicates(evidence)
        let environment = try IsolatedPersistenceEnvironment()

        #expect(classifications.contains(.duplicateIdentifierConflictingContent(["name", "number"])))
        #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    @Test("game files with duplicate child identifiers can be classified")
    func gameFilesWithDuplicateChildIdentifiersCanBeClassified() throws {
        let fixtureURL = StableIdentityAndOrderingTestSupport.sourceFixtureURL(
            directory: "MalformedAndUnsupported",
            filename: "DuplicateAtbatID.ScoreKeep_Games"
        )
        let game = try JSONDecoder().decode(ShareGame.self, from: Data(contentsOf: fixtureURL))
        let eventEvidence = game.atbats.map {
            StableIdentityEvidence(
                concept: .scoringEvent,
                importedIdentifier: .valid($0.id),
                displayEvidence: [
                    .init("result", $0.result),
                    .init("sequence", String($0.seq))
                ]
            )
        }
        let classifications = StableIdentityClassifier.classifyDuplicates(eventEvidence)
        let environment = try IsolatedPersistenceEnvironment()

        #expect(classifications.contains(.duplicateIdentifierConflictingContent(["result", "sequence"])))
        #expect(try environment.fetch(FetchDescriptor<Atbat>()).isEmpty)
    }

    @Test("missing identity remains unresolved rather than automatically merged")
    func missingIdentityRemainsUnresolved() {
        let first = StableIdentityEvidence(
            concept: .player,
            importedIdentifier: .missing,
            displayEvidence: [.init("name", "Fixture Unknown")]
        )
        let second = StableIdentityEvidence(
            concept: .player,
            importedIdentifier: .missing,
            displayEvidence: [.init("name", "Fixture Unknown")]
        )

        #expect(StableIdentityClassifier.compare(first, second) == .bothMissingIdentifier)
    }

    @Test("conflicting team identity fixture classifies same identifier with different side names")
    func conflictingTeamIdentityFixtureClassifiesConflict() throws {
        let fixtureURL = StableIdentityAndOrderingTestSupport.sourceFixtureURL(
            directory: "MalformedAndUnsupported",
            filename: "ConflictingTeamIdentity.ScoreKeep_Games"
        )
        let game = try JSONDecoder().decode(ShareGame.self, from: Data(contentsOf: fixtureURL))
        let visiting = StableIdentityEvidence(
            concept: .team,
            importedIdentifier: .valid(game.vteam.id),
            displayEvidence: [.init("name", game.vteam.name)]
        )
        let home = StableIdentityEvidence(
            concept: .team,
            importedIdentifier: .valid(game.hteam.id),
            displayEvidence: [.init("name", game.hteam.name)]
        )

        #expect(StableIdentityClassifier.compare(visiting, home) == .sameIdentifierConflictingEvidence(["name"]))
    }
}
