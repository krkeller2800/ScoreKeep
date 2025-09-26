//
//  ReplacementView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/10/25.
//

import SwiftUI
import SwiftData



struct ReplacementView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var navigationPath: NavigationPath = NavigationPath()
    @State private var selectPlayers: [Player] = []
    @State private var atbats: [Atbat] = []
    @State private var showingAlert: Bool = false
    @State private var doSubstitution: Bool = false
    @State private var team: Team
    @State private var game: Game
    @State private var alertMessage = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var replacedIdx: Int = 0
    @State private var incomingIdx: Int = 0
    @State private var rplPlayers: [Player] = []
    @State private var incPlayers: [Player] = []
    @State private var searchText = ""
    @State private var isSearching = false

    @Query var players: [Player]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    Spacer()
                    Picker("Replaced", selection: $replacedIdx) {
                        Text("Playing Players").tag(0)
                        ForEach(Array(rplPlayers.enumerated()), id: \.1) { index, rplPlayer in
                            Text(rplPlayer.name).tag(index+1)
                        }
                    }
                    .frame(maxWidth: 200,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    Text("  Replaced by ").font(.title)
                    Picker("incoming", selection: $incomingIdx) {
                        Text("Incoming Players").tag(0)
                        ForEach(Array(incPlayers.enumerated()), id: \.1) { index, incPlayer in
                            Text(incPlayer.name).tag(index+1)
                        }
                    }
                    .frame(maxWidth: 200,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    Spacer()
                    Button("Do it!") {
                        doSubstitution.toggle()
                    }
                    .frame(maxWidth: 100,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 0)
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    .onChange(of: doSubstitution ) {
                        if replacedIdx > 0 && incomingIdx > 0 {
                            doSubs()
                            dismiss()
                        } else {
                            alertMessage = "Please select a player to replace and an incoming player."
                            showingAlert.toggle()
                        }
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    PlayersOnTeamView(team: team, searchString: searchText, sortOrder: sortOrder)
                        .navigationDestination(for: Player.self) { player in
                            EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
                        }
                    Spacer()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onAppear() {
                    incPlayers = []
                    rplPlayers = []
                    let startAtbats = game.atbats.filter { $0.col == 1 && $0.batOrder < 50 && $0.team.id == team.id}
                    var foundRPL = false
                    for player in players {
                        player.batOrder = 99
                        for atbat in startAtbats {
                            if player.id == atbat.player.id {
                                player.batOrder = atbat.batOrder
                                rplPlayers.append(player)
                                foundRPL = true
                            }
                        }
                        if !foundRPL {
                            incPlayers.append(player)
                        }
                        foundRPL = false
                    }
                }
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Player Substitutions").font(.title2)
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
                            Text("Team then Order (1-99)")
                                .tag([SortDescriptor(\Player.team?.name),SortDescriptor(\Player.batOrder)])
                        }
                    }
                    Button("Add Player", systemImage: "plus", action: addPlayers)
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
            .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
            .onAppear {
                if UIDevice.type == "iPhone" {
                    isSearching = false
                } else {
                    isSearching = true
                }
            }
        }
    }
    init (game:Game, team:Team) {
        self.team = team
        self.game = game
        let tname = team.name
        
        _players = Query(filter: #Predicate { player in
            player.team?.name == tname
        },  sort: sortOrder)
    }
    func getPlayers () {
        
        let teamName = team.name
        
        if !teamName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder)])
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
            
            do {
                selectPlayers = try self.modelContext.fetch(fetchDescriptor)
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
        }
    }
    func addPlayers() {

        let  player = Player(name: "", number: "", position: "", batDir: "", batOrder: 99, team: team)
        modelContext.insert(player)
        navigationPath.append(player)
        try? modelContext.save()
        }
    func doSubs() {
        
        var newseq = Array(repeating: 999, count: 20)
        var fixBatorder = false
        var newPlayer:Player = Player(name: "", number: "", position: "", batDir: "", batOrder: 0)
        
        for player in players {
            if player.name == rplPlayers[replacedIdx-1].name {
                incPlayers[incomingIdx-1].batOrder = player.batOrder+1
                fixBatorder = true
                game.replaced.append(player)
            }
            if player.name == incPlayers[incomingIdx-1].name {
                newPlayer = incPlayers[incomingIdx-1]
                game.incomings.append(newPlayer)
                print("new Player:\(newPlayer.name) Colume: 1 batorder: \(newPlayer.batOrder) Seq: \(newseq)")
            }
            if player.batOrder >= incPlayers[incomingIdx-1].batOrder && fixBatorder && player.name != incPlayers[incomingIdx-1].name {
                if player.batOrder < 99 {
                    player.batOrder += 1
                }
            }
        }
        getAtbats()
        for atbat in atbats {
            atbat.batOrder = atbat.player.batOrder
            if atbat.player.name == rplPlayers[replacedIdx-1].name {
                newseq[atbat.col] = atbat.seq + 1
            }
        }
        for atbat in atbats {
            if atbat.seq >= newseq[atbat.col] {
                atbat.seq += 1
            }
            print("Atbats = Name:\(atbat.player.name) Column:\(atbat.col) batOrder:\(atbat.batOrder) Seq:\(atbat.seq)")
            if atbat.player.name == rplPlayers[replacedIdx-1].name {
                let newatbat = Atbat(game: game, team: team, player: newPlayer, result: "Pitch Hitter", maxbase: "No Bases", batOrder: newPlayer.batOrder, outAt: "Safe",
                                      inning: atbat.inning, seq: newseq[atbat.col], col: atbat.col, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
                modelContext.insert(newatbat)
                game.atbats.append(newatbat)
                if atbat.col == 1 {
                    game.players.append(newPlayer)
                }
                try? modelContext.save()
                print("newatbat = Name:\(newatbat.player.name) Column:\(newatbat.col) batOrder:\(newatbat.batOrder) Seq:\(newatbat.seq)")
             }
        }
        do {
            try self.modelContext.save()
        }
        catch {
            print("Error saving new atbat: \(error)")
        }
    }
    func getAtbats () {
        
        let gloc = game.location
        let gdate = game.date
        let tname = team.name

        
        var fetchDescriptor = FetchDescriptor<Atbat>(sortBy: [SortDescriptor(\.col), SortDescriptor(\.seq)])
        
        fetchDescriptor.predicate = #Predicate { $0.game.location == gloc && $0.game.date == gdate && $0.team.name == tname }
        
        do {
            atbats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            print("SwiftData Error fetching atbats: \(error)")
        }
    }
}

