//
//  ImportPlayersView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/18/25.
//

import SwiftUI
import SwiftData

struct ImportPlayersView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Binding var showingImport: Bool

    @State         var importURL:URL
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var navigationPath = NavigationPath()
    @Binding var columnVisibility:NavigationSplitViewVisibility
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var sharePlayers: [SharePlayer] = []
    @State private var shareGames: [ShareGame] = []
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var fileType = ""
    @State private var title = ""
    @State private var team: Team = Team(name: "", coach: "", details: "")

    @Query var teams: [Team]
    @Query var games: [Game]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    let dataType = (fileType.components(separatedBy: "_").last ?? "")
                    if dataType.localizedStandardContains("Players") {
                        Text("Which " + dataType + " shouldn't have non-blank fields overwritten?").italic().lineLimit(1).minimumScaleFactor(0.5)
                            .bold().italic()
                    }
                    Button(dataType.localizedStandardContains("Players") ? "Imported" : "Get Game") {
                        let teamName = importURL.lastPathComponent.count > 0 ? importURL.lastPathComponent.components(separatedBy: ".")[0].noNum() : "Unknown"
                        if fileType.localizedStandardContains("ScoreKeep_Players") {
                            sharedPlayersBoss(sharedPlayers: sharePlayers, teamName: teamName)
                        } else if fileType.localizedStandardContains("ScoreKeep_Games") {
                            sharedGamesBoss(shareGames: shareGames)
                        }
                        if !showingAlert {
                            alertMessage = "Import Complete"
                            showingAlert = true
                        }
                     
                    }
                    .foregroundColor(.blue).buttonStyle(.bordered)
                    if dataType.localizedStandardContains("Players") {
                        Text(" or ")
                        Button("Current") {
                            let teamName = importURL.lastPathComponent.count > 0 ? importURL.lastPathComponent.components(separatedBy: ".")[0].noNum() : "Unknown"
                            if fileType.localizedStandardContains("ScoreKeep_Players") {
                                currentPlayersBoss(sharedPlayers: sharePlayers, teamName: teamName)
                            }
                            if !showingAlert {
                                alertMessage = "Import Complete"
                                showingAlert = true
                            }
                            
                        }
                        .foregroundColor(.blue).buttonStyle(.bordered)
                    }
                }
                Text("")
                HStack {
                    let teamName = importURL.lastPathComponent.count > 0 ? importURL.lastPathComponent.components(separatedBy: ".")[0].noNum() : "Unknown"
                    let tm = teams.first(where: { $0.name == teamName }) ?? Team(name: teamName, coach: "", details: "")

                    VStack {
                        Text(fileType.localizedStandardContains("ScoreKeep_Players") ? "Imported \(teamName) Players" : "Imported Game") .bold().italic()
                        
                        if fileType.localizedStandardContains("ScoreKeep_Players") {
                            showSharedPlayers(sharePlayers: $sharePlayers, searchText: searchText)
                        } else {
                            if shareGames.count > 0 {
                                showSharedGame(shareGames: shareGames, searchText: searchText)
                            }
                        }
                        Spacer()
                    }
                    VStack {
                        if fileType.localizedStandardContains("ScoreKeep_Players") {
                            Text("Current \(teamName) Players").bold().italic()
                            PlayersOnTeamView(showHeader: true, team: tm, searchString: searchText, sortOrder: sortOrder)
                        } else if fileType.localizedStandardContains("ScoreKeep_Games") {
                            Text("Current Games").bold().italic()
                            GameView(searchString: searchText, title: $title, navigationPath: $navigationPath)
                                .navigationDestination(for: Game.self) { game in
                                    EditGameView(game: game, navigationPath: $navigationPath)
                            }
                        }
                        Spacer()
                    }
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView( player: player, team: tm, navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: Team.self) { team in
                        EditTeamView(navigationPath: $navigationPath, team: team)
                    }
                    .onAppear() {
                        columnVisibility = .detailOnly
                        fileType = importURL.lastPathComponent.components(separatedBy: ".").last ?? ""
                        if fileType.localizedStandardContains("ScoreKeep_Players") {
                            sharePlayers = decodePlayers()
                        } else if fileType.localizedStandardContains("ScoreKeep_Games")  {
                            shareGames = decodeGame()
                        } else {
                            alertMessage = "Could not identify the file coming in"
                            showingAlert = true
                        }
                   }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Import Players")
                                .font(.title2)
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            if UIDevice.type == "iPhone" {
                                Button(action: {
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if UIDevice.type == "iPhone" {
                                Button(action: {
                                    withAnimation {
                                        isSearching.toggle()
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                        }
                    }
                    .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: fileType.localizedStandardContains("ScoreKeep_Players") ? "Player name or number" : "Team name or game date")
                    .onAppear {
                        if UIDevice.type == "iPhone" {
                           isSearching = false
                        } else {
                            isSearching = true
                        }
                    }
                    .alert(alertMessage, isPresented: $showingAlert) {
                        Button("OK", role: .cancel) { }
                    }
                }
            }
        }
    }
    init(showingImport: Binding<Bool>, iURL: URL,   columnVisibility: Binding<NavigationSplitViewVisibility>) {
        _columnVisibility = columnVisibility
        _showingImport = showingImport
        self.importURL = iURL
    }
    func decodePlayers() -> [SharePlayer] {
        
        let needsAccess = importURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                importURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: importURL.absoluteURL)
        
            let decoder = JSONDecoder()
            
            guard let loadedFile = try? decoder.decode([SharePlayer].self, from: data) else {
                
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid user data"))
            }
            return loadedFile.sorted { $0.batOrder < $1.batOrder }
        }
        catch {
            alertMessage = "Error reading file: \(error.localizedDescription)"
            showingAlert = true
        }
        return []
    }
    func decodeGame() -> [ShareGame] {
        
        let needsAccess = importURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                importURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: importURL.absoluteURL)
        
            let decoder = JSONDecoder()
            
            guard let loadedFile = try? decoder.decode(ShareGame.self, from: data) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid user data"))
            }
            return [loadedFile]
        }
        catch {
            alertMessage = "Error reading file: \(error.localizedDescription)"
            showingAlert = true
        }
        return []
    }
    func sharedPlayersBoss (sharedPlayers: [SharePlayer],teamName: String) {
        let players = getCurrentPlayers(teamName: teamName)
        for sharePlayer in sharedPlayers {
            if let currPlayer = players.first(where: { $0.name == sharePlayer.name ||
                                                       $0.name.components(separatedBy: " ").last ==
                                                       sharePlayer.name.components(separatedBy: " ").last}) {
                currPlayer.number = !sharePlayer.number.isEmpty ? sharePlayer.number : currPlayer.number
                currPlayer.batOrder = sharePlayer.batOrder < 50 ? sharePlayer.batOrder : currPlayer.batOrder
                currPlayer.batDir = !sharePlayer.batDir.isEmpty ? sharePlayer.batDir : currPlayer.batDir
                currPlayer.position = !sharePlayer.position.isEmpty ? sharePlayer.position : currPlayer.position
                currPlayer.photo = !sharePlayer.photo.isEmpty ? sharePlayer.photo : currPlayer.photo
            }
            else {
                let newPlayer = Player(name: sharePlayer.name, number: sharePlayer.number, position: sharePlayer.position,
                                       batDir: sharePlayer.batDir, batOrder: sharePlayer.batOrder, team: team)
                modelContext.insert(newPlayer)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error saving data"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func currentPlayersBoss (sharedPlayers: [SharePlayer],teamName: String) {
        
        let players = getCurrentPlayers(teamName: teamName)
        for sharePlayer in sharedPlayers {
            if let currPlayer = players.first(where: { $0.name == sharePlayer.name ||
                                                       $0.name.components(separatedBy: " ").last ==
                                                       sharePlayer.name.components(separatedBy: " ").last}) {
                currPlayer.number = currPlayer.number.isEmpty ? sharePlayer.number : currPlayer.number
                currPlayer.batOrder = currPlayer.batOrder > 50 ? sharePlayer.batOrder : currPlayer.batOrder
                currPlayer.batDir = currPlayer.batDir.isEmpty ? sharePlayer.batDir : currPlayer.batDir
                currPlayer.position = currPlayer.position.isEmpty ? sharePlayer.position : currPlayer.position
                currPlayer.photo = (currPlayer.photo?.isEmpty ?? true) ? sharePlayer.photo : currPlayer.photo
            }
            else {
                let newPlayer = Player(name: sharePlayer.name, number: sharePlayer.number, position: sharePlayer.position,
                                       batDir: sharePlayer.batDir, batOrder: sharePlayer.batOrder, team: team)
                modelContext.insert(newPlayer)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error saving data: \(error.localizedDescription)"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func sharedGamesBoss (shareGames: [ShareGame]) {
        for shareGame in shareGames {
            sharedPlayersBoss(sharedPlayers: shareGame.vteam.players, teamName: shareGame.vteam.name)
            sharedPlayersBoss(sharedPlayers: shareGame.hteam.players, teamName: shareGame.hteam.name)
            let matchingGameCount = games.filter { $0.vteam?.name == shareGame.vteam.name &&
                                   $0.hteam?.name == shareGame.hteam.name &&
                                   $0.date == shareGame.date}.count
            if matchingGameCount > 0 {
                alertMessage = "Matching game already exists.  Delete it (swipe left) to import new data."
                showingAlert = true
            } else {
                let homeTeam = teams.first(where: {$0.name == shareGame.hteam.name} )
                let visitTeam = teams.first(where: {$0.name == shareGame.vteam.name} )
                let currentGame = Game(date: shareGame.date, location: shareGame.location, highLights: shareGame.highLights, hscore: shareGame.hscore, vscore: shareGame.vscore,
                                       everyOneHits: shareGame.everyOneHits, numInnings: shareGame.numInnings, vteam: visitTeam, hteam: homeTeam)
                doAtbats(shareAtbats:shareGame.atbats, currentGame: currentGame)
                doLineups(shareLineups: shareGame.lineups, currentGame: currentGame)
                doPitchers(sharePitchers:shareGame.pitchers, currentGame: currentGame)
                doReplaced(shareReplaced:shareGame.replaced, currentGame: currentGame)
                doIncomings(shareIncomings:shareGame.incomings, currentGame: currentGame)
            }
        }
    }
    func doAtbats (shareAtbats: [ShareAtbat],currentGame: Game) {
        for shareAtbat in shareAtbats {
            let team = teams.first(where: {$0.name == shareAtbat.team.name} )
            let player = team!.players.first(where: {$0.name == shareAtbat.player.name })
            let newAtbat = Atbat(game: currentGame, team: team!, player: player!, result: shareAtbat.result,
                                 maxbase: shareAtbat.maxbase, batOrder: shareAtbat.batOrder, outAt: shareAtbat.outAt, inning: shareAtbat.inning, seq:shareAtbat.seq, col: shareAtbat.col, rbis:shareAtbat.rbis, outs:shareAtbat.outs, sacFly: shareAtbat.sacFly,sacBunt: shareAtbat.sacBunt,stolenBases: shareAtbat.stolenBases, earnedRun: shareAtbat.earnedRun, playRec: shareAtbat.playRec, endOfInning: shareAtbat.endOfInning)
            if !(shareAtbat.col > 1 && shareAtbat.result == "Result") {
                modelContext.insert(newAtbat)
                currentGame.atbats.append(newAtbat)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error saving game data: \(error.localizedDescription)"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func doLineups (shareLineups: [ShareLineup],currentGame: Game) {
        for shareLineup in shareLineups {
            let team = teams.first(where: {$0.name == shareLineup.team.name} )
            var lineupPlayers: [Player] = []
            for player in shareLineup.players {
                if let player = team!.players.first(where: {$0.name == player.name} ) {
                    lineupPlayers.append(player)
                }
            }
            let lineup = Lineup(everyoneHits: shareLineup.everyoneHits, game: currentGame, team: team!, inning: shareLineup.inning, players: lineupPlayers)
            modelContext.insert(lineup)
            currentGame.lineups.append(lineup)
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error saving game data: \(error.localizedDescription)"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func doPitchers (sharePitchers: [SharePitcher],currentGame: Game) {
        for sharePitcher in sharePitchers {
            var team: Team!
            if let tm = teams.first(where: {$0.name == sharePitcher.team.name} ) {
                team = tm
            }
            else {
                team = Team(name: sharePitcher.team.name ,coach: sharePitcher.team.coach,details: sharePitcher.team.details, logo: sharePitcher.team.logo)
            }
            var player: Player!
            if let play = team!.players.first(where: {$0.name == sharePitcher.player.name }) {
                player = play
            } else {
                player = Player(name: sharePitcher.player.name, number: sharePitcher.player.number,  position: sharePitcher.player.position, batDir: sharePitcher.player.batDir, batOrder: sharePitcher.player.batOrder)
            }
            let pitcher = Pitcher(player: player, team: team, game: currentGame, startInn: sharePitcher.startInn, sOuts: sharePitcher.sOuts, sBats: sharePitcher.sBats, endInn: sharePitcher.endInn, eOuts: sharePitcher.eOuts, eBats: sharePitcher.eBats, strikeOuts: sharePitcher.strikeOuts, walks: sharePitcher.walks, hits: sharePitcher.hits, runs: sharePitcher.runs, won: sharePitcher.won)
            modelContext.insert(pitcher)
            currentGame.pitchers.append(pitcher)
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error saving game data: \(error.localizedDescription)"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func doReplaced (shareReplaced: [SharePlayer],currentGame: Game) {
        for player in shareReplaced {
            if let team = teams.first(where: {$0.name == player.team?.name} ) {
                if let rplayer = team.players.first(where: {$0.name == player.name} ) {
                    currentGame.replaced.append(rplayer)
                }
            }
        }
    }
    func doIncomings (shareIncomings: [SharePlayer],currentGame: Game) {
        for player in shareIncomings {
            if let team = teams.first(where: {$0.name == player.team?.name} ) {
                if let rplayer = team.players.first(where: {$0.name == player.name} ) {
                    currentGame.incomings.append(rplayer)
                }
            }
        }
    }
    func getCurrentPlayers(teamName: String) -> [Player] {
          
        if !teams.contains(where: { $0.name == teamName }) {
            let theTeam = Team(name: teamName, coach: "", details: "")
            modelContext.insert(theTeam)
            try? modelContext.save()
            team = theTeam
            do {
                try modelContext.save()
            }
            catch {
                alertMessage = DataError.savingData(dataType:"Players").localizedDescription
                showingAlert = true
                print(DataError.SwiftDataError(error: error).localizedDescription)
            }
        } else {
            team = teams.first(where: { $0.name == teamName })!
        }
        
        var fetchDescriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder)])
        fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
        
        do {
            let players = try self.modelContext.fetch(fetchDescriptor)
            return players
        }
        catch {
            print("SwiftData Error: \(error)")
            alertMessage = "Error reading data \(error.localizedDescription)"
            showingAlert = true
            return []
        }
    }
}

