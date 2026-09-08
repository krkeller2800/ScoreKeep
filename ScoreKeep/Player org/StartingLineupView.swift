//
//  StartingLineupView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 6/4/25.
//

import SwiftUI
import SwiftData

struct StartingLineupView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var team: Team
    @State var game: Game
    @State var lineup: Lineup
    @Binding var showingDetail: Bool
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State private var showingUpdate = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State var searchText:String = ""
    @State private var isSearching = false
    @State private var showingAddPlayerDraft = false
    @State var navigationPath: NavigationPath = NavigationPath()


    @Query var atbats: [Atbat]
    @Query var lineups: [Lineup]
    @Query var players: [Player]

    var body: some View {
        GeometryReader { geometry in
            NavigationStack(path: $navigationPath) {
                List {
                    let nameWidth = geometry.size.width/4
                    let smallWidth = geometry.size.width/11
//                    let mediumWidth = geometry.size.width/10
                    Text("Hold and drag Players to change the batting order or add a new Player if needed. Select a Player to make changes. Swipe left to delete a Player.")
                        .frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPad" ? .title3 : .callout).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    HStack () {
                        scorebookHeaderCell("Order")
                            .frame(width:smallWidth)
                        scorebookHeaderCell("Name")
                            .frame(width: nameWidth)
                        scorebookHeaderCell("Num")
                            .frame(width:smallWidth)
                        scorebookHeaderCell("Pos")
                            .frame(width:smallWidth)
                        scorebookHeaderCell("Dir")
                            .frame(width:smallWidth)
                       Text("").frame(width:45)
                    }
                    ForEach(linePlayers) { player in
                        NavigationLink(destination: EditPlayerView( player: player, team: team, navigationPath: $navigationPath)) { // Navigate to a DetailView
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold().lineLimit(1).minimumScaleFactor(0.5)
                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).padding(.leading, 0)
                                Text(player.number).frame(width:smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text("").frame(width:25)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayer)
                    .onMove(perform: { indices, newOffset in
                        linePlayers = linePlayers.sorted(by: { $0.batOrder < $1.batOrder })
                        linePlayers.move(fromOffsets: indices, toOffset: newOffset)
                        for (index, player) in linePlayers.enumerated() {
                            if index+1 <= numOfHitters || lineup.everyoneHits {
                                player.batOrder = index+1
                            } else if !lineup.everyoneHits {
                                player.batOrder = 99
                            }
                        }
                    })
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onChange(of: sortOrder) {
                    getPlayers()
                }
                .onChange(of: searchText) {
                    getPlayers()
                }
                .onChange(of: players) {
                    syncNewRosterPlayersIntoLineup()
                }
                .onAppear {
                    if let prevLineup = lineups.first(where: { $0.team == team && $0.game == game }) {
                        updDateLineup = true
                        lineup = prevLineup
                        linePlayers = Self.resolvedLineupPlayers(
                            savedLineup: prevLineup,
                            atbats: atbats,
                            fallbackPlayers: players,
                            team: team,
                            game: game
                        )
                    } else {
                        linePlayers = Self.resolvedLineupPlayers(
                            savedLineup: nil,
                            atbats: atbats,
                            fallbackPlayers: players,
                            team: team,
                            game: game
                        )
                        updDateLineup = false
                    }
                    lineup.everyoneHits = game.everyOneHits
                    if lineup.everyoneHits {
                        numOfHitters = 99
                    } else {
                        numOfHitters = 9
                    }
                    for (index, player) in linePlayers.enumerated() {
                        if index+1 <= numOfHitters || lineup.everyoneHits {
                            player.batOrder = index+1
                        } else if !lineup.everyoneHits {
                            player.batOrder = 99
                        }
                    }
                }
                .alert(isPresented:$showingUpdate) {
                    Alert(
                        title: Text("Updating the Lineup"),
                        message: Text("If the Lineup is updated, any at bats already recorded will be deleted and removed from the game. Take a picture or a screen shot of the game if you need to re-enter it after the update."),
                        primaryButton: .destructive(Text("Update")) {
                            for atbat in game.atbats {
                                if atbat.team == team {
                                    modelContext.delete(atbat)
                                    game.atbats.removeAll() {$0 == atbat}
                                    game.replaced.removeAll {$0 == atbat.player}
                                    game.incomings.removeAll {$0 == atbat.player}
                                }
                            }
                            doLineup()
                            dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("\(team.name) Lineup").font(.title2).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name (A-Z)")
                                    .tag([SortDescriptor(\Player.name)])
                                Text("Name (Z-A)")
                                    .tag([SortDescriptor(\Player.name, order: .reverse)])
                                Text("Order (1-99)")
                                    .tag([SortDescriptor(\Player.batOrder)])
                                Text("Number (1-99)")
                                    .tag([SortDescriptor(\Player.number)])
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(updDateLineup ? "Upd Lineup" :"Save Lineup") {
                            if updDateLineup {
                                showingUpdate = true
                            } else {
                                updDateLineup = true
                                doLineup()
                                dismiss()
                            }
                        }
                        .frame(maxWidth: 135,maxHeight: 30, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                        .border(ScoreKeepVisualStyle.separator).cornerRadius(10).accentColor(ScoreKeepVisualStyle.primaryText).padding(.horizontal, 10)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
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
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if UIDevice.type != "iPhone" {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Player name or number", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .frame(width: 260)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Player name or number")
                        }

                        Button("Add Player", systemImage: "plus", action: addPlayers)
                            .accessibilityLabel("Add player")
                    }
                }
                .searchable(if: UIDevice.type == "iPhone" && isSearching, text: $searchText, placement: .automatic, prompt: "Player name or number")
                .sheet(isPresented: $showingAddPlayerDraft) {
                    NavigationStack {
                        AddPlayerDraftView(team: team)
                    }
                    .standardAddPlayerPresentation()
                }
                .onAppear {
                    if UIDevice.type == "iPhone" {
                       isSearching = false
                    } else {
                        isSearching = false
                    }
                }
                Spacer()
            }
        }
    }

    static func resolvedLineupPlayers(savedLineup: Lineup?, atbats: [Atbat], fallbackPlayers: [Player], team: Team, game: Game) -> [Player] {
        if let savedPlayers = savedLineup?.players.sorted(by: { $0.batOrder < $1.batOrder }), !savedPlayers.isEmpty {
            return savedPlayers
        }
        let atbatPlayers = atbats
            .filter { $0.team == team && $0.game == game && $0.inning <= 1 && $0.col == 1 && $0.batOrder != 99 }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.seq < $1.seq
                }
                return $0.batOrder < $1.batOrder
            }
            .map { $0.player }
        if !atbatPlayers.isEmpty {
            return atbatPlayers
        }
        return fallbackPlayers.sorted(by: { $0.batOrder < $1.batOrder })
    }

    func doLineup() {
        if let oldlineup = lineups.first(where: { $0.team == team && $0.game == game}) {
            lineup = oldlineup
        } else {
            lineup = Lineup(everyoneHits: false, game: game, team: team, inning: 1)
            modelContext.insert(lineup)
            game.lineups.append(lineup)
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error saving lineup: \(error)")
            }
        }
        lineup.players = linePlayers
        var seq = 0
        for (player) in linePlayers {
            seq += 1
            if let atbat = atbats.first(where: { $0.team == team && $0.inning <= 1 && $0.game == game && $0.player == player}) {
                atbat.batOrder = player.batOrder
                atbat.seq = seq
            } else {
                if player.batOrder != 99 {
                    let atbat = Atbat(game: game, team: team, player: player, result: "Result", maxbase: "No Bases", batOrder: player.batOrder, outAt: "Safe", inning: 1, seq:seq, col:1, rbis:0, outs:0, sacFly: 0,sacBunt: 0,stolenBases: 0)
                    modelContext.insert(atbat)
                    game.atbats.append(atbat)
                    game.players.append(player)
                    try? modelContext.save()
                }
            }
        }
        do {
            try self.modelContext.save()
        }
        catch {
            print("Error saving atbat: \(error)")
        }
    }

    func addPlayers() {
        showingAddPlayerDraft = true
    }

    init(showingDetail: Binding<Bool>, passedGame: Game, passedTeam: Team, theTeam: String = "", searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        team = passedTeam
        game = passedGame


        lineup = Lineup(everyoneHits: false, game: passedGame, team: passedTeam, inning: 1)

        _showingDetail = showingDetail
        _players = Query(filter: #Predicate { player in
            if searchText.isEmpty {
                player.team?.name == theTeam
            } else {
                player.team?.name == theTeam &&
                (player.name.localizedStandardContains(searchText)
                 || player.number.localizedStandardContains(searchText))
            }
        },  sort: self.sortOrder)
    }
    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = linePlayers[offset]
            if playedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) is associated with game(s). Cannot delete."
            } else if pitchedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) has pitched in a game. Cannot delete."
            } else {
                linePlayers.removeAll { $0.name == player.name }
                modelContext.delete(player)
                for (index, player) in linePlayers.enumerated() {
                    if index+1 <= numOfHitters || lineup.everyoneHits {
                        player.batOrder =  index+1
                    } else if !lineup.everyoneHits {
                        player.batOrder = 99
                    }
                }
                do {
                    try self.modelContext.save()
                }
                catch {
                    print("Error saving new atbats: \(error)")
                }
            }
        }
    }
    func playedInGame(player:Player)->Bool {


        var exist = false
        let pName = player.name

        if !pName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Atbat>()

            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existAtbats = try self.modelContext.fetch(fetchDescriptor)
                if existAtbats.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Atbats: \(error)")
            }
        }
        return exist
    }

    func pitchedInGame(player:Player)->Bool {

        var exist = false
        let pName = player.name

        if !pName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Pitcher>()

            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existPitcher = try self.modelContext.fetch(fetchDescriptor)
                if existPitcher.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Games: \(error)")
            }
        }
        return exist
    }
    func getPlayers () {

        let teamName = team.name

        if !teamName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Player>(sortBy: sortOrder)
            if searchText.isEmpty {
                fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
            } else {
                fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName &&
                                                        ($0.name.localizedStandardContains(searchText) ||
                                                         $0.number.localizedStandardContains(searchText))
                }
            }

            do {
                linePlayers = try self.modelContext.fetch(fetchDescriptor)
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
        }
    }

    func syncNewRosterPlayersIntoLineup() {
        let missingPlayers = players.filter { player in
            player.team?.ident == team.ident && !linePlayers.contains(where: { $0 === player })
        }

        guard !missingPlayers.isEmpty else { return }

        linePlayers.append(contentsOf: missingPlayers)
        linePlayers = linePlayers.sorted(by: { $0.batOrder < $1.batOrder })
        for (index, player) in linePlayers.enumerated() {
            if index+1 <= numOfHitters || lineup.everyoneHits {
                player.batOrder = index+1
            } else if !lineup.everyoneHits {
                player.batOrder = 99
            }
        }
    }
}
