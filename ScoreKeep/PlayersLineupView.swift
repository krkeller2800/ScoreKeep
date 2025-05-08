//
//  PlayersLineupView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/29/25.
//

import SwiftUI
import SwiftData

struct PlayersLineupView: View {
    @Environment(\.modelContext) var modelContext
    @State var team: Team
    @State var game: Game
    @State var lineup: Lineup
    @Binding var showingDetail: Bool
    @State var addPlayer = false
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State var thisPlayer = Player(name: "", number: "", position: "", batOrder: 99)
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []

    @Query var atbats: [Atbat]
    @Query var lineups: [Lineup]
    @Query var players: [Player]

    var body: some View {
        ZStack {
            Text("").frame(height: 10)
            HStack {
                Button("< Back") {
                    showingDetail = false
                }
                .frame(width: 75, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                Spacer()
                Button("Add Pitch Hit") {
                        numOfHitters += 1
                }
                .frame(width: 105, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                Spacer()
                Button(lineup.everyoneHits ? "All Hit" : "9 Hitters") {
                    lineup.everyoneHits.toggle()
                    if lineup.everyoneHits {
                        numOfHitters = 99
                    } else {
                        numOfHitters = 9
                    }
                    for (index, player) in linePlayers.enumerated() {
                        if index+1 <= numOfHitters {
                            player.batOrder = CGFloat(index+1)
                        } else if !lineup.everyoneHits {
                            player.batOrder = 99
                        }
                    }
                }
                .frame(width: 75, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                .disabled(updDateLineup)
                Spacer()
                Button(updDateLineup ? "Upd" :"Save") {
                    updDateLineup = true
                    doLineup()
                }
                .frame(width: 75, height: 30,alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                Spacer()
                Button("Add Player") {
                    self.addPlayer.toggle()
                    thisPlayer = Player(name: "", number: "", position: "", batOrder: 99, team: team)
                    modelContext.insert(thisPlayer)
                    for (index, player) in linePlayers.enumerated() {
                        if index+1 <= numOfHitters || lineup.everyoneHits {
                            player.batOrder = CGFloat(index+1)
                        } else if !lineup.everyoneHits {
                            player.batOrder = 99
                        }
                    }
                    try? self.modelContext.save()
                }
                .frame(width: 100, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .sheet(isPresented: $addPlayer) {
                    EditLineupView(player: thisPlayer, team: team, addPlayer: $addPlayer)
                    }
                .padding(.trailing, 20)
            }
 
        }
        .onAppear {
            if let prevLineup = lineups.first(where: { $0.team == team && $0.game == game }) {
                updDateLineup = true
                lineup = prevLineup
                linePlayers = lineup.players.sorted(by: { $0.batOrder < $1.batOrder })
            } else {
                linePlayers = players.sorted(by: { $0.batOrder < $1.batOrder })
                updDateLineup = false
            }
        }
        .frame(maxWidth:.infinity, maxHeight:40,alignment:.bottomLeading)
        List {
            Section {
                HStack (spacing:0) {
                    Text("Name")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Number")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Position")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Order")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Team")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                }
                ForEach(linePlayers) { player in
                        HStack {
                            Text(player.name).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                            Spacer()
                            Text(player.number).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                            Spacer()
                            Text(player.position).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                            Spacer()
                            Text(String(format:"%.0f", player.batOrder)).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(player.team?.name ?? "").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                            Spacer()
                        }
                }
                .onDelete(perform: deletePlayer)
                .onMove(perform: { indices, newOffset in
                    linePlayers = linePlayers.sorted(by: { $0.batOrder < $1.batOrder })
                    linePlayers.move(fromOffsets: indices, toOffset: newOffset)
                    for (index, player) in linePlayers.enumerated() {
                        if index+1 <= numOfHitters || lineup.everyoneHits {
                            player.batOrder = CGFloat(index+1)
                        } else if !lineup.everyoneHits {
                            player.batOrder = 99.0
                        }
                    }
//                    do {
//                        try self.modelContext.save()
//                    }
//                    catch {
//                        print("Error saving new atbats: \(error)")
//                    }
//                    doLineup()
                 })
                .onAppear {
                    for (index, player) in linePlayers.enumerated() {
                        if index+1 <= numOfHitters || lineup.everyoneHits {
                            player.batOrder = CGFloat(index+1)
                        } else if !lineup.everyoneHits {
                            player.batOrder = 99.0
                        }
                    }
//                    do {
//                        try self.modelContext.save()
//                    }
//                    catch {
//                        print("Error saving new atbats: \(error)")
//                    }
                }
                Spacer()
            }
            header: {
                Text("Hold & Drag Players to change Batting Order").frame(maxWidth:.infinity, alignment:.leading).font(.title3).foregroundColor(.black).bold()
                }
        }
//        .environment(\.editMode, $editMode)
        .background(Color.gray.opacity(0.1))
        
    }
    func doLineup() {
        if let oldlineup = lineups.first(where: { $0.team == team && $0.game == game}) {
            lineup = oldlineup
        } else {
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
                let atbat = Atbat(game: game, team: team, player: player, result: "Result", maxbase: "No Bases", batOrder: player.batOrder, outAt: "Safe", inning: 1, seq:seq, col:1, rbis:0, outs:0, sacFly: 0,sacBunt: 0,stolenBases: 0)
                if player.batOrder != 99 {
                    modelContext.insert(atbat)
                    game.atbats.append(atbat)
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
    
    init(showingDetail: Binding<Bool>, passedGame: Game, passedTeam: Team, theTeam: String, searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        team = passedTeam
        game = passedGame
        lineup = Lineup(everyoneHits: false, game: passedGame, team: passedTeam, inning: 1)

        _showingDetail = showingDetail
        _players = Query(filter: #Predicate { player in
            if searchString.isEmpty {
                player.team?.name == theTeam
            } else {
                player.team?.name == theTeam &&
                (player.name.localizedStandardContains(searchString)
                 || player.number.localizedStandardContains(searchString))
            }
        },  sort: sortOrder)
    }
    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = players[offset]
            modelContext.delete(player)
            for (index, player) in linePlayers.enumerated() {
                if index+1 <= numOfHitters || lineup.everyoneHits {
                    player.batOrder =  CGFloat(index+1)
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

#Preview {
    do {
        let previewer = try Previewer()
        return PlayerView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
