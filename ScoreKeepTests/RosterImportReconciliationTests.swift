import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Roster import reconciliation")
struct RosterImportReconciliationTests {
    @Test("suffix-normalized name with matching number identifies same player")
    func suffixNormalizedNameWithMatchingNumberMatches() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)
        let importedPlayer = sharePlayer(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3)

        let matchedPlayer = RosterImportReconciler.matchingPlayer(for: importedPlayer, in: [existingPlayer])

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("suffix punctuation and roman numeral variants normalize when number matches")
    func suffixPunctuationAndRomanNumeralVariantsMatch() throws {
        let team = Team(name: "Braves", coach: "", details: "")
        let existingJr = Player(name: "Ronald Acuna Jr", number: "13", position: "RF", batDir: "R", batOrder: 1, team: team)
        let existingRoman = Player(name: "Michael Harris", number: "23", position: "CF", batDir: "L", batOrder: 2, team: team)

        let matchedJr = RosterImportReconciler.matchingPlayer(
            for: sharePlayer(name: "Ronald Acuña Jr.", number: "13", position: "RF", batDir: "R", batOrder: 1),
            in: [existingJr]
        )
        let matchedRoman = RosterImportReconciler.matchingPlayer(
            for: sharePlayer(name: "Michael Harris II", number: "23", position: "CF", batDir: "L", batOrder: 2),
            in: [existingRoman]
        )

        #expect(matchedJr === existingJr)
        #expect(matchedRoman === existingRoman)
    }

    @Test("diacritic-only name variant matches when number corroborates identity")
    func diacriticOnlyNameVariantMatchesWithNumber() throws {
        let team = Team(name: "Guardians", coach: "", details: "")
        let existingPlayer = Player(name: "Jose Ramirez", number: "11", position: "3B", batDir: "S", batOrder: 3, team: team)
        let importedPlayer = sharePlayer(name: "José Ramírez", number: "11", position: "3B", batDir: "S", batOrder: 3)

        let matchedPlayer = RosterImportReconciler.matchingPlayer(for: importedPlayer, in: [existingPlayer])

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("conflicting uniform number blocks suffix-normalized automatic match")
    func conflictingNumberBlocksSuffixNormalizedMatch() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)
        let importedPlayer = sharePlayer(name: "Vladimir Guerrero Jr.", number: "99", position: "1B", batDir: "R", batOrder: 3)

        let matchedPlayer = RosterImportReconciler.matchingPlayer(for: importedPlayer, in: [existingPlayer])

        #expect(matchedPlayer == nil)
    }

    @Test("same surname with different first name does not match")
    func sameSurnameDifferentFirstNameDoesNotMatch() throws {
        let team = Team(name: "Dodgers", coach: "", details: "")
        let existingPlayer = Player(name: "Will Smith", number: "16", position: "C", batDir: "R", batOrder: 5, team: team)
        let importedPlayer = sharePlayer(name: "John Smith", number: "16", position: "P", batDir: "R", batOrder: 99)

        let matchedPlayer = RosterImportReconciler.matchingPlayer(for: importedPlayer, in: [existingPlayer])

        #expect(matchedPlayer == nil)
    }

    @Test("similar typo name does not fuzzy match")
    func similarTypoNameDoesNotMatch() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Dalton Varsho", number: "5", position: "CF", batDir: "L", batOrder: 7, team: team)
        let importedPlayer = sharePlayer(name: "Daulton Varsho", number: "23", position: "CF", batDir: "L", batOrder: 7)

        let matchedPlayer = RosterImportReconciler.matchingPlayer(for: importedPlayer, in: [existingPlayer])

        #expect(matchedPlayer == nil)
    }

    @Test("imported boss demotes old-only players displaced by imported active slots")
    func importedBossDemotesOldOnlyConflicts() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let seedStarter = Player(name: "Bo Bichette", number: "11", position: "SS", batDir: "R", batOrder: 4, team: team)
        let oldOnlyStarter = Player(name: "Old Third Baseman", number: "47", position: "3B", batDir: "L", batOrder: 5, team: team)
        environment.context.insert(team)
        environment.context.insert(seedStarter)
        environment.context.insert(oldOnlyStarter)
        try environment.save()

        try ImportService(modelContext: environment.context).importPlayers(
            [
                sharePlayer(name: "Bo Bichette", number: "7", position: "SS", batDir: "R", batOrder: 4),
                sharePlayer(name: "New Fifth Hitter", number: "36", position: "RF", batDir: "L", batOrder: 5)
            ],
            teamName: "Blue Jays",
            strategy: .imported
        )

        let players = try fetchPlayers(environment, teamName: "Blue Jays")
        #expect(players.first { $0.name == "Bo Bichette" }?.number == "7")
        #expect(players.first { $0.name == "Bo Bichette" }?.batOrder == 4)
        #expect(players.first { $0.name == "New Fifth Hitter" }?.batOrder == 5)
        #expect(players.first { $0.name == "Old Third Baseman" }?.batOrder == 99)
        #expect(activeSlotCounts(players).values.allSatisfy { $0 == 1 })
    }

    @Test("current boss imports occupied active unmatched player as not hitting")
    func currentBossDemotesUnmatchedIncomingOccupiedSlot() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let savedStarter = Player(name: "Saved Starter", number: "4", position: "RF", batDir: "R", batOrder: 1, team: team)
        environment.context.insert(team)
        environment.context.insert(savedStarter)
        try environment.save()

        try ImportService(modelContext: environment.context).importPlayers(
            [sharePlayer(name: "Incoming Leadoff", number: "7", position: "DH", batDir: "R", batOrder: 1)],
            teamName: "Blue Jays",
            strategy: .current
        )

        let players = try fetchPlayers(environment, teamName: "Blue Jays")
        #expect(players.first { $0.name == "Saved Starter" }?.batOrder == 1)
        #expect(players.first { $0.name == "Incoming Leadoff" }?.batOrder == 99)
        #expect(activeSlotCounts(players)[1] == 1)
    }

    @Test("current boss allows unmatched incoming player to keep vacant active slot")
    func currentBossKeepsUnmatchedIncomingVacantSlot() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let savedStarter = Player(name: "Saved Starter", number: "4", position: "RF", batDir: "R", batOrder: 1, team: team)
        environment.context.insert(team)
        environment.context.insert(savedStarter)
        try environment.save()

        try ImportService(modelContext: environment.context).importPlayers(
            [sharePlayer(name: "Incoming Second", number: "38", position: "CF", batDir: "L", batOrder: 2)],
            teamName: "Blue Jays",
            strategy: .current
        )

        let players = try fetchPlayers(environment, teamName: "Blue Jays")
        #expect(players.first { $0.name == "Saved Starter" }?.batOrder == 1)
        #expect(players.first { $0.name == "Incoming Second" }?.batOrder == 2)
        #expect(activeSlotCounts(players)[1] == 1)
        #expect(activeSlotCounts(players)[2] == 1)
    }

    @Test("blue jays seed plus later imported boss roster keeps active slots unique")
    func blueJaysSeedPlusLaterImportKeepsActiveSlotsUnique() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let seedPlayers = [
            Player(name: "George Springer", number: "4", position: "RF", batDir: "R", batOrder: 1, team: team),
            Player(name: "Nathan Lukes", number: "38", position: "CF", batDir: "L", batOrder: 2, team: team),
            Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team),
            Player(name: "Bo Bichette", number: "11", position: "SS", batDir: "R", batOrder: 4, team: team),
            Player(name: "Addison Barger", number: "47", position: "3B", batDir: "L", batOrder: 5, team: team),
            Player(name: "Alejandro Kirk", number: "30", position: "C", batDir: "R", batOrder: 6, team: team),
            Player(name: "Dalton Varsho", number: "5", position: "CF", batDir: "L", batOrder: 7, team: team),
            Player(name: "Ernie Clement", number: "22", position: "2B", batDir: "R", batOrder: 8, team: team),
            Player(name: "Andra Gimenez", number: "0", position: "SS", batDir: "L", batOrder: 9, team: team)
        ]
        environment.context.insert(team)
        seedPlayers.forEach { environment.context.insert($0) }
        try environment.save()

        try ImportService(modelContext: environment.context).importPlayers(
            [
                sharePlayer(name: "George Springer", number: "7", position: "DH", batDir: "R", batOrder: 1),
                sharePlayer(name: "Yohendrick Pinango", number: "24", position: "LF", batDir: "L", batOrder: 2),
                sharePlayer(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3),
                sharePlayer(name: "Kazuma Okamoto", number: "7", position: "3B", batDir: "R", batOrder: 4),
                sharePlayer(name: "Addison Barger", number: "36", position: "RF", batDir: "L", batOrder: 5),
                sharePlayer(name: "Jesus Sanchez", number: "12", position: "RF", batDir: "L", batOrder: 6),
                sharePlayer(name: "Lenya Sosa", number: "50", position: "2B", batDir: "R", batOrder: 7),
                sharePlayer(name: "Brandon Valenzuela", number: "59", position: "C", batDir: "S", batOrder: 8),
                sharePlayer(name: "Tyler Heineman", number: "55", position: "C", batDir: "S", batOrder: 9)
            ],
            teamName: "Blue Jays",
            strategy: .imported
        )

        let players = try fetchPlayers(environment, teamName: "Blue Jays")
        let counts = activeSlotCounts(players)
        #expect(counts.values.allSatisfy { $0 == 1 })
        #expect(players.first { $0.name == "Nathan Lukes" }?.batOrder == 99)
        #expect(players.first { $0.name == "Bo Bichette" }?.batOrder == 99)
        #expect(players.first { $0.name == "Alejandro Kirk" }?.batOrder == 99)
        #expect(players.first { $0.name == "Ernie Clement" }?.batOrder == 99)
        #expect(players.first { $0.name == "Yohendrick Pinango" }?.batOrder == 2)
        #expect(players.first { $0.name == "Kazuma Okamoto" }?.batOrder == 4)
        #expect(players.first { $0.name == "Jesus Sanchez" }?.batOrder == 6)
        #expect(players.first { $0.name == "Brandon Valenzuela" }?.batOrder == 8)
        #expect(players.first { $0.name == "Tyler Heineman" }?.batOrder == 9)
        #expect(players.contains { $0.name == "Vladimir Guerrero Jr." } == false)
        #expect(players.first { $0.name == "Vladimir Guerrero" }?.batOrder == 3)
    }

    private func sharePlayer(
        name: String,
        number: String,
        position: String,
        batDir: String,
        batOrder: Int
    ) -> SharePlayer {
        SharePlayer(name: name, number: number, position: position, batDir: batDir, batOrder: batOrder)
    }

    private func fetchPlayers(_ environment: IsolatedPersistenceEnvironment, teamName: String) throws -> [Player] {
        var descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder), SortDescriptor(\.name)])
        descriptor.predicate = #Predicate { $0.team?.name == teamName }
        return try environment.fetch(descriptor)
    }

    private func activeSlotCounts(_ players: [Player]) -> [Int: Int] {
        players.reduce(into: [:]) { counts, player in
            guard let slot = RosterImportReconciler.activeSlot(player.batOrder) else { return }
            counts[slot, default: 0] += 1
        }
    }
}
