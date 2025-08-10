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
    @State var pNum = ""
    @State var pPos = ""
    @State var startInn = 0
    @State var endInn = 0
    @State var sOuts = 0
    @State var eOuts = 0
    @State var sBats = 0
    @State var eBats = 0
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

//    @Query var pitchers: [Pitcher]
    @Query var players: [Player]
    
    var body: some View {
        VStack() {
            List(selection: $selection) {
                HStack (spacing:0) {
                    Text("Num")
                        .frame(width: 50,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Name")
                        .frame(width: 190,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Pos")
                        .frame(width: 45,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Start\nInning")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Start\nOuts")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Num\nBats")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("End\nInning")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("End\nOuts")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Num\nBats")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer(minLength: 50)
             }
                HStack (spacing:0) {
                    Text(pNum).frame(width:50, alignment: .center).foregroundColor(.black).minimumScaleFactor(0.5).lineLimit(1)
                        .overlay(Divider().background(.black), alignment: .trailing)
                    Text(pName).frame(width:190, alignment: .leading).foregroundColor(.black).minimumScaleFactor(0.5).lineLimit(1)
                        .overlay(Divider().background(.black), alignment: .trailing)
                    Text(pPos).frame(width:45, alignment: .center).foregroundColor(.black).minimumScaleFactor(0.5).lineLimit(1)
                        .overlay(Divider().background(.black), alignment: .trailing)
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
                    Picker("Starts Outs", selection: $sOuts) {
                        let outs = ["0","1 Out","2 Out","3 Out"]
                        ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                            Text(out).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                    Picker("Starts Bats", selection: $sBats) {
                        let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                        ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                            Text(out).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
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
                    Picker("End Outs", selection: $eOuts) {
                        let outs = ["0","1","2","3"]
                        ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                            Text(out).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                    Picker("End Bats", selection: $eBats) {
                        let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                        ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                            Text(out).tag(index)
                        }
                    }
                    .frame(maxWidth:.infinity, maxHeight: 35).overlay(Divider().background(.black), alignment: .trailing).labelsHidden()
                    Button("Delete") {
                        deleteStats()
                    }
                    .padding([.leading, .top, .bottom],2)
                    .foregroundColor(.white)
                    .buttonStyle(.borderless)
                    .background(Color.red, in: Capsule())
                }
                .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                .onChange(of: [startInn, sOuts, sBats, endInn, eOuts, eBats]) {
                    if let pitch = game.pitchers.first(where: { $0.player.name == pName }) {
                        pitch.startInn = startInn
                        pitch.sOuts = sOuts
                        pitch.sBats = sBats
                        pitch.endInn = endInn
                        pitch.eOuts = eOuts
                        pitch.eBats = eBats
                    } else {
                        for player in players {
                            if pName == player.name {
                                thisPlayer = player
                            }
                        }
                        if !thisPlayer.name.isEmpty {
                            let pitcher = Pitcher(player: thisPlayer, team: team, game: game, startInn: startInn, sOuts: sOuts, sBats: sBats, endInn: endInn,
                                                  eOuts: eOuts, eBats: eBats, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
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
                Text("Select which player will pitch!").font(UIDevice.type == "iPad" ? .title3 : .caption).italic().frame(height: 30, alignment: .bottomLeading)
                HStack (spacing:0) {
                    Text("Num")
                        .frame(width: 50,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Name")
                        .frame(width: 190,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Pos")
                        .frame(width: 45,height: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Start\nInning")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Start\nOuts")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Num\nBats")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("End\nInning")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("End\nOuts")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("Num\nBats")
                        .frame(maxWidth:.infinity,maxHeight: 55).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer(minLength: 50)
             }
                ForEach(players, id: \.self) { player in
                    HStack(spacing: 0) {
                        Text(player.number).frame(width: 50, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(player.name).frame(width: 190, alignment: .leading).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(player.position).frame(width: 45, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        let pitch = game.pitchers.first(where: { $0.player.id == player.id })
                        Text(String(pitch?.startInn ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.sOuts ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.sBats ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.endInn ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.eOuts ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.eBats ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black)
                            .overlay(Divider().background(.black), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Spacer(minLength: 50)
                    }
                }
                .listStyle(.plain)
                .contentMargins(.top, 0)
                .onChange(of: selection, {
                    cleanupPitchers()
                    if let selection {
                        self.updDatePitcher = true
                        if let pitch = game.pitchers.first(where: { $0.player.id == selection.id }) {
                            pName = pitch.player.name
                            pNum = pitch.player.number
                            pPos = pitch.player.position
                            startInn = pitch.startInn
                            sOuts = pitch.sOuts
                            sBats = pitch.sBats
                            endInn = pitch.endInn
                            eOuts = pitch.eOuts
                            eBats = pitch.eBats
                        } else {
                            pName = selection.name
                            pNum = selection.number
                            pPos = selection.position
                            startInn = 0
                            sOuts = 0
                            sBats = 0
                            endInn = 0
                            eOuts = 0
                            eBats = 0
                        }
                    }
                })
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .onDisappear {
            if game.pitchers.first(where: { $0.player.name == pName }) == nil {
                for player in players {
                    if pName == player.name {
                        thisPlayer = player
                    }
                }
                if pName != "" && pName != "Not Selected Yet" {
                    let pitcher = Pitcher(player: thisPlayer, team: team, game: game, startInn: startInn, sOuts: sOuts, sBats: sBats, endInn: endInn, eOuts: eOuts,
                                          eBats: eBats, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
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
            cleanupPitchers()
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
            pNum = ""
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
                game.pitchers.removeAll {
                    $0 == pitcher }
                modelContext.delete(pitcher)
            }
        }
        try? modelContext.save()
    }
}
