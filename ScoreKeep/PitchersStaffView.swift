//
//  PitchersStaffView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/26/25.
//

import SwiftUI
import SwiftData

struct PitchersStaffView: View {
    @Environment(\.modelContext) var modelContext
    @State var team: Team
    @State var game: Game
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State var thisPlayer = Player(name: "", number: "", position: "", batOrder: 99)
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State private var selection: Player?
    @State private var path = NavigationPath()
    @Binding private var addPitcher: Bool
    @State private var editPitcher: Bool = false
    @Query var atbats: [Atbat]
    @Query var lineups: [Lineup]
    @Query var players: [Player]
    

    var body: some View {
        ZStack {
            Text("").frame(height: 10)
            HStack {
                Button("< Back") {
                    addPitcher = false
                }
                .frame(width: 75, height: 30, alignment:.center).background(.yellow.opacity(0.4)).border(.gray).cornerRadius(10)
                .padding(.leading, 20)
                Spacer()
            }
        }
        .onAppear {

        }
        .frame(maxWidth:.infinity, maxHeight:40,alignment:.bottomLeading)
        Section {
            VStack(spacing: 0) {
                HStack (spacing:0) {
                    Text("Name")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Number")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Team")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Strt  Bat In")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("End   Bat In")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer(minLength: 25)
                }
                .padding(.horizontal,10)
                List(players, id: \.self, selection: $selection) { player in
                    HStack {
                        Text(player.name).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                        Spacer()
                        Text(player.number).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                        Spacer()
                        Text(player.team?.name ?? "").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                        Spacer()
                        let pitch = Pitcher(player: player, team: team, game: game, startinn: 0, sBatIn: 0, endinn: 0, eBatIn: 0, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
                        let pitcher = game.pitchers.first(where: { $0.player.id == player.id }) ?? pitch
                        Text("  \(pitcher.startinn)          \(pitcher.sBatIn)")
                            .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,5)
                        Spacer()
                        Text("  \(pitcher.endinn)          \(pitcher.eBatIn)")
                            .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                   }
                }
                .environment(\.defaultMinListHeaderHeight, 5)
                .scrollContentBackground(.hidden)
                .onChange(of: selection, {
                    if let selection {
                        if game.pitchers.first(where: { $0.player.id == selection.id }) != nil {
                            self.editPitcher.toggle()
                        } else {
                            let pitcher = Pitcher(player: selection, team: team, game: game, startinn: 0, sBatIn: 0, endinn: 0, eBatIn: 0, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
                            modelContext.insert(pitcher)
                            game.pitchers.append(pitcher)
                            self.editPitcher.toggle()
                        }
                    }
                })
                .sheet(isPresented: $editPitcher) {
                     if let pitcher = game.pitchers.first(where: { $0.player == selection }) {
                         EditPitcherView(pitcher: pitcher, team: team, editPitcher: $editPitcher, addPitcher: $addPitcher, navigationPath: $path)
                    }
                }
            }
          }
            header: {
                Text("Select who is pitching now").frame(maxWidth:.infinity, alignment:.center).font(.title3).foregroundColor(.black).bold()
                }
            Spacer()
    }

    
    init(showDetails: Binding<Bool>, passedGame: Game, passedTeam: Team, theTeam: String, searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        team = passedTeam
        game = passedGame
        _addPitcher = showDetails
        
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
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error saving new atbats: \(error)")
            }
        }
    }
    
}
