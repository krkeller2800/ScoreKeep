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
    @State var updDatePitcher = false
    @State var pName = "Not Selected Yet"
    @State var startInn = 0
    @State var endInn = 0
    @State var sOuts = 0
    @State var eOuts = 0
    @State var thisPlayer = Player(name: "", number: "", position: "", batDir: "", batOrder: 99)
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State private var selection: Player?
    @State private var path = NavigationPath()
    @State private var editPitcher: Bool = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
   
    enum FocusField: Hashable {case field}
    @FocusState private var focusedField: FocusField?

    @Query var pitchers: [Pitcher]
    @Query var players: [Player]
    

    var body: some View {
        Section {
            VStack() {
                Form {
                    HStack (spacing:0) {
                        Text("Name")
                            .frame(width: 160).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Start Inn")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Start Outs")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("End Inn")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("End Outs")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer(minLength: 5)
                    }
                    HStack {
                        Text(pName).background(Color.white).frame(maxWidth:160)
                            .foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).padding(.trailing,0)
                        Spacer()
                        Picker("Start Inning", selection: $startInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Spacer()
                        Picker("Starts Outs", selection: $sOuts) {
                            let outs = ["0","1 Out","2 Out","3 Out"]
                            ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                       Spacer()
                        Picker("End Inning", selection: $endInn) {
                            let innings = ["0","1st","2nd","3rd","4th",
                                           "5th","6th","7th","8th","9th",
                                           "10th","11th","12th","13th","14th",
                                           "15","15th","17th","18th","19th"]
                            ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                                Text(inning).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Spacer()
                        Picker("End Outs", selection: $eOuts) {
                            let outs = ["0","1","2","3"]
                            ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                                Text(out).tag(index)
                            }
                        }
                        .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                        Spacer()
                    }
                    let pitchLastName = pName == "Not Selected Yet" ? "Pitcher" : pName.split(separator: " ").last ?? "Pitcher"
                    Button("Delete \(pitchLastName) Stats") {
                        deleteStats()
                    }
                    .foregroundColor(.blue).buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .center)
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }

                    HStack (spacing:0) {
                        Text("Name")
                            .frame(width: 160).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Num")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Pos")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Team")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Start Inn")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("Start Outs")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("End Inn")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer()
                        Text("End Outs")
                            .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Spacer(minLength: 5)
                    }
                    .onChange(of: [startInn, sOuts, endInn, eOuts]) {
                        if let pitch = game.pitchers.first(where: { $0.player.name == pName }) {
                            pitch.startInn = startInn
                            pitch.sOuts = sOuts
                            pitch.endInn = endInn
                            pitch.eOuts = eOuts
                        } else {
                            for player in players {
                                if pName == player.name {
                                    thisPlayer = player
                                }
                            }
                            if !thisPlayer.name.isEmpty {
                                let pitcher = Pitcher(player: thisPlayer, team: team, game: game, startInn: startInn, sOuts: sOuts, endInn: endInn, eOuts: eOuts,
                                                      strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
                                modelContext.insert(pitcher)
                                game.pitchers.append(pitcher)
                                
                                do {
                                    try self.modelContext.save()
                                }
                                catch {
                                    print("Error saving new pitcher: \(error)")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity,maxHeight: 200,alignment:.leading)
                List(players, id: \.self, selection: $selection) { player in
                    HStack {
                        Text(player.name).frame(width: 160, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.leading,5)
                        Spacer()
                        Text(player.number).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Spacer()
                        Text(player.position).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Spacer()
                        Text(player.team?.name ?? "").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Spacer()
                        let pitch = game.pitchers.first(where: { $0.player.id == player.id })
                        Text(String(pitch?.startInn ?? 0)).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                              .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Text(String(pitch?.sOuts ?? 0)).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Text(String(pitch?.endInn ?? 0)).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Text(String(pitch?.eOuts ?? 0)).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.2).padding(.trailing,0)
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .padding(.horizontal,10)
                }
                .listStyle(.plain)
                .contentMargins(.top, 0)
//                .scrollContentBackground(.hidden)
                .onChange(of: selection, {
                    cleanupPitchers()
                    if let selection {
                        self.updDatePitcher = true
                        if let pitch = game.pitchers.first(where: { $0.player.id == selection.id }) {
                            pName = pitch.player.name
                            startInn = pitch.startInn
                            sOuts = pitch.sOuts
                            endInn = pitch.endInn
                            eOuts = pitch.eOuts
                        } else {
                            pName = selection.name
                            startInn = 0
                            sOuts = 0
                            endInn = 0
                            eOuts = 0
                        }
                    }
                })
            }
        }
        .onDisappear {
            if game.pitchers.first(where: { $0.player.name == pName }) == nil {
                for player in players {
                    if pName == player.name {
                        thisPlayer = player
                    }
                }
                if pName != "" {
                    let pitcher = Pitcher(player: thisPlayer, team: team, game: game, startInn: startInn, sOuts: sOuts, endInn: endInn, eOuts: eOuts,
                                          strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
                    modelContext.insert(pitcher)
                    game.pitchers.append(pitcher)
                    
                    do {
                        try self.modelContext.save()
                    }
                    catch {
                        print("Error saving new pitcher: \(error)")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Select who will pitch")
                    .font(.title2)
            }

        }
        Spacer()
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Player>] = [], passedGame: Game, passedTeam: Team, theTeam: String) {
        team = passedTeam
        game = passedGame

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
    func deleteStats() {
        if let pitch = game.pitchers.first(where: { $0.player.name == pName }) {
            game.pitchers.removeAll { $0.player.name == pName }
            modelContext.delete(pitch)
            pName = "Not Selected Yet"
            startInn = 0
            sOuts = 0
            endInn = 0
            eOuts = 0
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error deleting pitcher: \(error)")
            }
        } else {
            alertMessage = "No pitcher selected"
            showingAlert = true
        }
    }
    func cleanupPitchers() {
        for pitcher in game.pitchers {
            if pitcher.player.name.isEmpty {
                game.pitchers.removeAll { value in
                  return value == pitcher
                }
                modelContext.delete(pitcher)
            }
        }
    }
}
