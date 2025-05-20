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

    @Query var players: [Player]


    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    Spacer()
                    Spacer()
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
                        } else {
                            alertMessage = "Please select a player to replace and an incoming player."
                            showingAlert.toggle()
                        }
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    PlayersOnTeamView(teamName: team.name, searchString: "", sortOrder: sortOrder)
                        .navigationDestination(for: Player.self) { player in
                            EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
                        }
                    Spacer()
                }
                .onAppear() {
                    rplPlayers = players.filter { $0.batOrder < 99 }
                    incPlayers = players.filter { $0.batOrder >= 99 }
                }
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Pinch Hitters and Player Substitutions").font(.title2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Player", action: addPlayers)
                }
                ToolbarItem(placement: .topBarLeading) {
                     Button("< Back") {
                         dismiss()
                     }
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

//        getPlayers()
    }
    func getPlayers () {
        
        let teamName = team.name
        
        if !teamName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Player>()
            
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
    
//        try? modelContext.save()
    }
    func doSubs() {
        
        var newseq = 999
        var fixBatorder = false
        var newPlayer:Player = Player(name: "", number: "", position: "", batDir: "", batOrder: 0)
        
        for player in players {
            if player.name == rplPlayers[replacedIdx-1].name {
                incPlayers[incomingIdx-1].batOrder = player.batOrder+1
                fixBatorder = true
                game.replaced.append(player)
            }
            if player.name == incPlayers[incomingIdx-1].name {
                newPlayer = player
                game.incomings.append(player)

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
                newseq = atbat.seq + 1
            } else if atbat.seq >= newseq {
                atbat.seq += 1
            }
        }
        let newatbat = Atbat(game: game, team: team, player: newPlayer, result: "Result", maxbase: "No Bases", batOrder: newPlayer.batOrder, outAt: "Safe",
                             inning: 1, seq: newseq, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        modelContext.insert(newatbat)
    }
    func getAtbats () {
        
        let gloc = game.location
        let gdate = game.date
        let tname = team.name

        
        var fetchDescriptor = FetchDescriptor<Atbat>()
        
        fetchDescriptor.predicate = #Predicate { $0.game.location == gloc && $0.game.date == gdate && $0.team.name == tname }
        
        do {
            atbats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            print("SwiftData Error: \(error)")
        }
    }
}

