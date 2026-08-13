import Foundation
import SwiftData
import SwiftUI
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

    @Test("manual create warning finds exact same-team name without requiring number")
    func manualCreateWarningFindsExactNameWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Bo Bichette", number: "", position: "SS", batDir: "R", batOrder: 4, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Bo Bichette",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning matches Jr punctuation variant without number")
    func manualCreateWarningMatchesJrPunctuationVariantWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir Guerrero Jr",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning matches leading-space name variant without number")
    func manualCreateWarningMatchesLeadingSpaceNameVariantWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: " Vladimir Guerrero Jr.",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning matches trailing-space name variant without number")
    func manualCreateWarningMatchesTrailingSpaceNameVariantWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir Guerrero Jr. ",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning matches repeated internal-space name variant without number")
    func manualCreateWarningMatchesRepeatedInternalSpaceNameVariantWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir  Guerrero   Jr.",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning surfaces suffix-added variant even without number")
    func manualCreateWarningSurfacesSuffixAddedVariantWithoutNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir Guerrero Jr.",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning surfaces suffix-removed variant even with conflicting number")
    func manualCreateWarningSurfacesSuffixRemovedVariantWithConflictingNumber() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir Guerrero",
            number: "99",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning surfaces diacritic-only variant without number")
    func manualCreateWarningSurfacesDiacriticOnlyVariantWithoutNumber() throws {
        let team = Team(name: "Guardians", coach: "", details: "")
        let existingPlayer = Player(name: "Jose Ramirez", number: "", position: "3B", batDir: "S", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "José Ramírez",
            number: "",
            in: [existingPlayer]
        )

        #expect(matchedPlayer === existingPlayer)
    }

    @Test("manual create warning excludes the player currently being edited")
    func manualCreateWarningExcludesCurrentEditedPlayer() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let editedPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let matchedPlayer = RosterImportReconciler.likelyMatchingPlayer(
            name: "Vladimir Guerrero Jr.",
            number: "27",
            in: [editedPlayer],
            excluding: editedPlayer
        )

        #expect(matchedPlayer == nil)
    }

    @Test("manual use-existing decision does not mutate matched player")
    func manualUseExistingDecisionDoesNotMutateMatchedPlayer() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .useExistingPlayer,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero",
            number: "99",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: false
        )

        #expect(result.shouldUseExistingPlayer)
        #expect(result.shouldCreateNewPlayer == false)
        #expect(result.didUpdateExistingPlayer == false)
        #expect(existingPlayer.name == "Vladimir Guerrero Jr.")
        #expect(existingPlayer.number == "27")
        #expect(existingPlayer.position == "1B")
        #expect(existingPlayer.batDir == "R")
    }

    @Test("manual update-existing decision applies nonblank entered fields")
    func manualUpdateExistingDecisionAppliesNonblankEnteredFields() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero Jr. ",
            number: "",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: false
        )

        #expect(result.shouldUseExistingPlayer)
        #expect(result.shouldCreateNewPlayer == false)
        #expect(result.didUpdateExistingPlayer)
        #expect(result.skippedUpdateForHistoricalReferences == false)
        #expect(existingPlayer.name == "Vladimir Guerrero Jr.")
        #expect(existingPlayer.number == "27")
        #expect(existingPlayer.position == "DH")
        #expect(existingPlayer.batDir == "L")
    }

    @Test("manual create-new-anyway decision leaves matched player unchanged")
    func manualCreateNewAnywayDecisionLeavesMatchedPlayerUnchanged() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .createNewPlayerAnyway,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero",
            number: "99",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: false
        )

        #expect(result.shouldUseExistingPlayer == false)
        #expect(result.shouldCreateNewPlayer)
        #expect(result.didUpdateExistingPlayer == false)
        #expect(existingPlayer.name == "Vladimir Guerrero Jr.")
        #expect(existingPlayer.number == "27")
        #expect(existingPlayer.position == "1B")
        #expect(existingPlayer.batDir == "R")
    }

    @Test("manual cancel decision leaves matched player unchanged")
    func manualCancelDecisionLeavesMatchedPlayerUnchanged() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero Jr.", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .cancel,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero",
            number: "99",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: false
        )

        #expect(result.shouldUseExistingPlayer == false)
        #expect(result.shouldCreateNewPlayer == false)
        #expect(result.didUpdateExistingPlayer == false)
        #expect(existingPlayer.name == "Vladimir Guerrero Jr.")
        #expect(existingPlayer.number == "27")
        #expect(existingPlayer.position == "1B")
        #expect(existingPlayer.batDir == "R")
    }

    @Test("manual update-existing applies fields even when historical references exist")
    func manualUpdateExistingAppliesFieldsWhenHistoricalReferencesExist() throws {
        let team = Team(name: "Blue Jays", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero Jr.",
            number: "99",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: true
        )

        #expect(result.shouldUseExistingPlayer)
        #expect(result.shouldCreateNewPlayer == false)
        #expect(result.didUpdateExistingPlayer)
        #expect(result.skippedUpdateForHistoricalReferences == false)
        #expect(existingPlayer.name == "Vladimir Guerrero Jr.")
        #expect(existingPlayer.number == "99")
        #expect(existingPlayer.position == "DH")
        #expect(existingPlayer.batDir == "L")
    }

    @Test("PlayerView update-existing persists matched player identity")
    func playerViewUpdateExistingPersistsMatchedPlayerIdentity() throws {
        try assertManualUpdateExistingPersists(entryPath: "PlayerView")
    }

    @Test("PlayersOnTeamView update-existing persists matched player identity")
    func playersOnTeamViewUpdateExistingPersistsMatchedPlayerIdentity() throws {
        try assertManualUpdateExistingPersists(entryPath: "PlayersOnTeamView")
    }

    @Test("StartingLineupView update-existing persists matched player identity")
    func startingLineupViewUpdateExistingPersistsMatchedPlayerIdentity() throws {
        try assertManualUpdateExistingPersists(entryPath: "StartingLineupView")
    }

    @Test("EditPlayerView update-existing persists matched player identity")
    func editPlayerViewUpdateExistingPersistsMatchedPlayerIdentity() throws {
        try assertManualUpdateExistingPersists(entryPath: "EditPlayerView")
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

    @Test("filtered imported-player delete maps visible row to original temporary source index")
    func filteredImportedPlayerDeleteMapsVisibleRowToOriginalSourceIndex() throws {
        let sharePlayers = [
            sharePlayer(name: "Alpha One", number: "1", position: "CF", batDir: "R", batOrder: 1),
            sharePlayer(name: "Target First", number: "12", position: "SS", batDir: "L", batOrder: 2),
            sharePlayer(name: "Beta Two", number: "2", position: "RF", batDir: "R", batOrder: 3),
            sharePlayer(name: "Target Second", number: "34", position: "1B", batDir: "L", batOrder: 4)
        ]

        let visiblePlayers = ImportedPlayerDisplayFiltering.visiblePlayers(from: sharePlayers, searchText: "Target")
        let sourceOffsets = ImportedPlayerDisplayFiltering.sourceOffsets(for: IndexSet(integer: 1), in: visiblePlayers)

        #expect(visiblePlayers.map(\.sourceIndex) == [1, 3])
        #expect(sourceOffsets == IndexSet(integer: 3))
    }

    @Test("game import preserves legacy pitcher boundary evidence while aggregate report counts at-bat outs")
    func gameImportPreservesLegacyPitcherBoundaryEvidenceWhileAggregateReportCountsAtbatOuts() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let visitors = ShareTeam(name: "Marlins", players: [
            sharePlayer(name: "Visitor Batter", number: "1", position: "CF", batDir: "R", batOrder: 1)
        ])
        let home = ShareTeam(name: "Tigers", players: [
            sharePlayer(name: "Drew Anderson", number: "38", position: "RP", batDir: "R", batOrder: 99)
        ])
        let pitcherPlayer = sharePlayer(name: "Drew Anderson", number: "38", position: "RP", batDir: "R", batOrder: 99)
        let shareGame = ShareGame(
            date: "2026-04-11T16:50:46Z",
            location: "Comerica",
            highLights: "",
            hscore: 6,
            vscore: 1,
            everyOneHits: false,
            numInnings: 9,
            vteam: visitors,
            hteam: home,
            players: [],
            atbats: [
                shareAtbat(team: visitors, inning: 1.1, seq: 1, col: 1, outs: 1, result: "Ground Out"),
                shareAtbat(team: visitors, inning: 1.2, seq: 2, col: 1, outs: 2, result: "Fly Out"),
                shareAtbat(team: visitors, inning: 1.3, seq: 3, col: 1, outs: 3, result: "Strikeout", endOfInning: true)
            ],
            lineups: [],
            pitchers: [
                SharePitcher(
                    player: pitcherPlayer,
                    team: home,
                    startInn: 1,
                    sOuts: 0,
                    sBats: 0,
                    endInn: 10,
                    eOuts: 0,
                    eBats: 0,
                    strikeOuts: 0,
                    walks: 0,
                    hits: 0,
                    runs: 0,
                    won: false
                )
            ],
            replaced: [],
            incomings: []
        )

        try ImportService(modelContext: environment.context).importShareGames([shareGame])
        let importedPitcher = try #require(try environment.fetch(FetchDescriptor<Pitcher>()).first)
        let importedGame = try #require(try environment.fetch(FetchDescriptor<Game>()).first)
        let reportAtbats = importedGame.atbats.filter { $0.team.name == "Marlins" }
        let reportInnings = pitcherRptViewInningsUsingCurrentFormula(atbats: reportAtbats, pitcher: importedPitcher)
        let scorecardBoundaryOuts = ((importedPitcher.endInn - importedPitcher.startInn) * 3) + (importedPitcher.eOuts - importedPitcher.sOuts)

        #expect(importedGame.atbats.count == 3)
        #expect(reportAtbats.count == 3)
        #expect(importedPitcher.team.name == "Tigers")
        #expect(importedPitcher.startInn == 1)
        #expect(importedPitcher.endInn == 10)
        #expect(scorecardBoundaryOuts == 27)
        #expect(reportInnings == 1)
    }

    @Test("passive historical refresh preserves imported pitcher boundaries")
    func passiveHistoricalRefreshPreservesImportedPitcherBoundaries() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let marlins = Team(name: "Marlins", coach: "", details: "")
        let tigers = Team(name: "Tigers", coach: "", details: "")
        let game = Game(
            date: "2026-04-11T16:50:46Z",
            location: "Comerica",
            highLights: "",
            hscore: 6,
            vscore: 1,
            numInnings: 9,
            vteam: marlins,
            hteam: tigers
        )
        let mize = pitcher(name: "Casey Mize", team: tigers, game: game, startInn: 1, sOuts: 0, sBats: 0, endInn: 6, eOuts: 2, eBats: 4)
        let anderson = pitcher(name: "Drew Anderson", team: tigers, game: game, startInn: 6, sOuts: 2, sBats: 4, endInn: 10, eOuts: 0, eBats: 0)
        let hurter = pitcher(name: "Brant Hurter", team: tigers, game: game, startInn: 10, sOuts: 0, sBats: 0, endInn: 10, eOuts: 0, eBats: 0)
        let historicalAtbats = [
            modelAtbat(game: game, team: marlins, batterName: "Visitor One", batOrder: 1, result: "Ground Out", inning: 9, seq: 1, col: 9, outs: 1),
            modelAtbat(game: game, team: marlins, batterName: "Visitor Two", batOrder: 2, result: "Fly Out", inning: 9, seq: 2, col: 9, outs: 2),
            modelAtbat(game: game, team: marlins, batterName: "Visitor Three", batOrder: 3, result: "Strikeout", inning: 9, seq: 3, col: 9, outs: 3, endOfInning: true)
        ]
        game.atbats = historicalAtbats
        game.pitchers = [anderson, hurter, mize]
        [marlins, tigers].forEach(environment.context.insert)
        environment.context.insert(game)
        [mize, anderson, hurter].forEach(environment.context.insert)
        historicalAtbats.forEach(environment.context.insert)
        try environment.save()

        let coordinator = LiveScoringWorkflowCoordinator()
        let prepared = coordinator.prepareLiveGameState(
            game: game,
            battingTeam: marlins,
            displayedAtbats: historicalAtbats,
            pitchers: game.pitchers
        )
        let result = coordinator.refreshProjections(
            displayedAtbats: historicalAtbats,
            pitchers: game.pitchers,
            game: game,
            maintainPitcherMarkers: prepared.canScore && prepared.currentOrPendingLegacyAtbat != nil,
            save: { try environment.save() }
        )

        #expect(prepared.currentOrPendingLegacyAtbat == nil)
        #expect(result.disposition == .success)
        #expect(mize.startInn == 1)
        #expect(mize.sOuts == 0)
        #expect(mize.sBats == 0)
        #expect(mize.endInn == 6)
        #expect(mize.eOuts == 2)
        #expect(mize.eBats == 4)

        let reloadContext = ModelContext(environment.container)
        let reloadedMize = try #require(try reloadContext.fetch(FetchDescriptor<Pitcher>()).first { $0.player.name == "Casey Mize" })
        #expect(reloadedMize.startInn == 1)
        #expect(reloadedMize.sOuts == 0)
        #expect(reloadedMize.sBats == 0)
        #expect(reloadedMize.endInn == 6)
        #expect(reloadedMize.eOuts == 2)
        #expect(reloadedMize.eBats == 4)
    }

    @Test("live refresh still closes previous pitcher and maintains current pitcher")
    func liveRefreshStillClosesPreviousPitcherAndMaintainsCurrentPitcher() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let dodgers = Team(name: "Dodgers", coach: "", details: "")
        let blueJays = Team(name: "Blue Jays", coach: "", details: "")
        let game = Game(
            date: "2025-11-01T22:00:00Z",
            location: "Rogers Stadium",
            highLights: "",
            hscore: 0,
            vscore: 0,
            numInnings: 9,
            vteam: dodgers,
            hteam: blueJays
        )
        let scherzer = pitcher(name: "Max Scherzer", team: blueJays, game: game, startInn: 1, sOuts: 0, sBats: 0, endInn: 2, eOuts: 0, eBats: 0)
        let green = pitcher(name: "Chad Green", team: blueJays, game: game, startInn: 2, sOuts: 0, sBats: 0, endInn: 0, eOuts: 0, eBats: 0)
        let hoffman = pitcher(name: "Jeff Hoffman", team: blueJays, game: game, startInn: 2, sOuts: 1, sBats: 1, endInn: 0, eOuts: 0, eBats: 0)
        let batterOne = Player(name: "Batter One", number: "", position: "", batDir: "R", batOrder: 1, team: dodgers)
        let batterTwo = Player(name: "Batter Two", number: "", position: "", batDir: "R", batOrder: 2, team: dodgers)
        let batterThree = Player(name: "Batter Three", number: "", position: "", batDir: "R", batOrder: 3, team: dodgers)
        dodgers.players.append(contentsOf: [batterOne, batterTwo, batterThree])
        let liveAtbats = [
            modelAtbat(game: game, team: dodgers, player: batterOne, result: "Strikeout", inning: 1, seq: 1, col: 1, outs: 1),
            modelAtbat(game: game, team: dodgers, player: batterTwo, result: "Fly Out", inning: 1, seq: 2, col: 1, outs: 2),
            modelAtbat(game: game, team: dodgers, player: batterThree, result: "Ground Out", inning: 1, seq: 3, col: 1, outs: 3, endOfInning: true),
            modelAtbat(game: game, team: dodgers, player: batterTwo, result: "Strikeout", inning: 4, seq: 4, col: 4, outs: 2),
            modelAtbat(game: game, team: dodgers, player: batterThree, result: "Result", inning: 4, seq: 5, col: 4, outs: 2)
        ]
        game.atbats = liveAtbats
        game.pitchers = [scherzer, green, hoffman]
        [dodgers, blueJays].forEach(environment.context.insert)
        [batterOne, batterTwo, batterThree].forEach(environment.context.insert)
        environment.context.insert(game)
        [scherzer, green, hoffman].forEach(environment.context.insert)
        liveAtbats.forEach(environment.context.insert)
        try environment.save()

        let coordinator = LiveScoringWorkflowCoordinator()
        let livePitcherOrder = [scherzer, green, hoffman]
        let prepared = coordinator.prepareLiveGameState(
            game: game,
            battingTeam: dodgers,
            displayedAtbats: liveAtbats,
            pitchers: livePitcherOrder
        )
        let result = coordinator.refreshProjections(
            displayedAtbats: liveAtbats,
            pitchers: livePitcherOrder,
            game: game,
            maintainPitcherMarkers: prepared.canScore && prepared.currentOrPendingLegacyAtbat != nil,
            save: { try environment.save() }
        )

        #expect(prepared.currentOrPendingLegacyAtbat != nil)
        #expect(result.disposition == .success)
        #expect(scherzer.endInn == 2)
        #expect(scherzer.eOuts == 0)
        #expect(scherzer.eBats == 0)
        #expect(green.endInn == hoffman.startInn)
        #expect(green.eOuts == hoffman.sOuts)
        #expect(green.eBats == hoffman.sBats)
        #expect(hoffman.startInn == 2)
        #expect(hoffman.sOuts == 1)
        #expect(hoffman.sBats == 1)
        #expect(hoffman.endInn == 2)
        #expect(hoffman.eOuts == 1)
        #expect(hoffman.eBats == 1)

        let reloadContext = ModelContext(environment.container)
        let reloadedPitchers = try reloadContext.fetch(FetchDescriptor<Pitcher>())
        let reloadedGreen = try #require(reloadedPitchers.first { $0.player.name == "Chad Green" })
        let reloadedHoffman = try #require(reloadedPitchers.first { $0.player.name == "Jeff Hoffman" })
        #expect(reloadedGreen.endInn == reloadedHoffman.startInn)
        #expect(reloadedGreen.eOuts == reloadedHoffman.sOuts)
        #expect(reloadedGreen.eBats == reloadedHoffman.sBats)
        #expect(reloadedHoffman.endInn == 2)
        #expect(reloadedHoffman.eOuts == 1)
        #expect(reloadedHoffman.eBats == 1)
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

    private func shareAtbat(
        team: ShareTeam,
        inning: CGFloat,
        seq: Int,
        col: Int,
        outs: Int,
        result: String,
        endOfInning: Bool = false
    ) -> ShareAtbat {
        ShareAtbat(
            game: nil,
            team: team,
            player: team.players[0],
            result: result,
            maxbase: "No Bases",
            batOrder: 1,
            outAt: "Safe",
            inning: inning,
            seq: seq,
            col: col,
            rbis: 0,
            outs: outs,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0,
            earnedRun: true,
            playRec: "",
            endOfInning: endOfInning
        )
    }

    private func pitcherRptViewInningsUsingCurrentFormula(atbats: [Atbat], pitcher: Pitcher) -> Int {
        guard atbats.isEmpty == false else { return 0 }

        let common = Common()
        let endInning = pitcher.endInn > 0 ? pitcher.endInn : Int(atbats[atbats.count - 1].inning) + 1
        let outCount = atbats.filter {
            common.outresults.contains($0.result) &&
            (10 * Int($0.inning + 1)) + $0.outs >= (10 * pitcher.startInn) + pitcher.sOuts &&
            (
                (10 * Int($0.inning + 1)) + $0.outs <= (10 * endInning) + pitcher.eOuts ||
                (Int($0.inning) == endInning - 1 && $0.outs == 3)
            )
        }.count

        return Int(CGFloat(outCount) / 3)
    }

    private func fetchPlayers(_ environment: IsolatedPersistenceEnvironment, teamName: String) throws -> [Player] {
        var descriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder), SortDescriptor(\.name)])
        descriptor.predicate = #Predicate { $0.team?.name == teamName }
        return try environment.fetch(descriptor)
    }

    private func pitcher(
        name: String,
        team: Team,
        game: Game,
        startInn: Int,
        sOuts: Int,
        sBats: Int,
        endInn: Int,
        eOuts: Int,
        eBats: Int
    ) -> Pitcher {
        let player = Player(name: name, number: "", position: "P", batDir: "R", batOrder: 99, team: team)
        team.players.append(player)
        return Pitcher(
            player: player,
            team: team,
            game: game,
            startInn: startInn,
            sOuts: sOuts,
            sBats: sBats,
            endInn: endInn,
            eOuts: eOuts,
            eBats: eBats,
            strikeOuts: 0,
            walks: 0,
            hits: 0,
            runs: 0,
            won: false
        )
    }

    private func modelAtbat(
        game: Game,
        team: Team,
        batterName: String,
        batOrder: Int,
        result: String,
        inning: CGFloat,
        seq: Int,
        col: Int,
        outs: Int,
        endOfInning: Bool = false
    ) -> Atbat {
        let player = Player(name: batterName, number: "", position: "", batDir: "R", batOrder: batOrder, team: team)
        team.players.append(player)
        return Atbat(
            game: game,
            team: team,
            player: player,
            result: result,
            maxbase: "No Bases",
            batOrder: batOrder,
            outAt: "Safe",
            inning: inning,
            seq: seq,
            col: col,
            rbis: 0,
            outs: outs,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0,
            endOfInning: endOfInning
        )
    }

    private func modelAtbat(
        game: Game,
        team: Team,
        player: Player,
        result: String,
        inning: CGFloat,
        seq: Int,
        col: Int,
        outs: Int,
        endOfInning: Bool = false
    ) -> Atbat {
        Atbat(
            game: game,
            team: team,
            player: player,
            result: result,
            maxbase: "No Bases",
            batOrder: player.batOrder,
            outAt: "Safe",
            inning: inning,
            seq: seq,
            col: col,
            rbis: 0,
            outs: outs,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0,
            endOfInning: endOfInning
        )
    }

    private func assertManualUpdateExistingPersists(entryPath: String) throws {
        let environment = try IsolatedPersistenceEnvironment()
        let team = Team(name: "\(entryPath) Team", coach: "", details: "")
        let existingPlayer = Player(name: "Vladimir Guerrero", number: "27", position: "1B", batDir: "R", batOrder: 3, team: team)
        environment.context.insert(team)
        environment.context.insert(existingPlayer)
        try environment.save()

        let result = RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: existingPlayer,
            name: "Vladimir Guerrero Jr.",
            number: "99",
            position: "DH",
            batDir: "L",
            preserveHistoricalEvidence: true
        )
        try environment.save()

        let players = try fetchPlayers(environment, teamName: team.name)
        let fetchedPlayer = try #require(players.first)
        #expect(players.count == 1)
        #expect(fetchedPlayer.identifier == existingPlayer.identifier)
        #expect(fetchedPlayer.name == "Vladimir Guerrero Jr.")
        #expect(fetchedPlayer.number == "99")
        #expect(fetchedPlayer.position == "DH")
        #expect(fetchedPlayer.batDir == "L")
        #expect(result.shouldUseExistingPlayer)
        #expect(result.shouldCreateNewPlayer == false)
        #expect(result.didUpdateExistingPlayer)
        #expect(result.skippedUpdateForHistoricalReferences == false)
    }

    private func activeSlotCounts(_ players: [Player]) -> [Int: Int] {
        players.reduce(into: [:]) { counts, player in
            guard let slot = RosterImportReconciler.activeSlot(player.batOrder) else { return }
            counts[slot, default: 0] += 1
        }
    }
}
