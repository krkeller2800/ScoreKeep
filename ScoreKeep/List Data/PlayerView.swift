//
//  PlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var navigationPath: NavigationPath
    @State var pName: String = ""
    @State var pNum: String = ""
    @State var pPos: String = ""
    @State var pDir: String = ""
    @State var pOrder: Int = 0
    @State var pTeam: Team?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var playerName = ""
    @State private var prevPName = ""
    @State private var dups = false
    @State private var checkForDups = true
    
    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]

    @Query var players: [Player]
    
    var body: some View {
        GeometryReader { geometry in
            Form {
                let nameWidth = geometry.size.width/4
                let smallWidth = geometry.size.width/15
                let mediumWidth = geometry.size.width/10
                Section {
                    //            Text("Select a Player to Edit or Swipe to Delete").frame(maxWidth:.infinity, alignment: .center).font(.title)
                    HStack {
                        Text("Name")
                            .frame(width: nameWidth).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Text("Num")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Pos")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Dir")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Order")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Team")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("").frame(width:45)
                    }
                    HStack {
                        TextField("Player", text: $pName, onEditingChanged: { (editingChanged) in
                            if !editingChanged {
                                checkForDup(pname:pName)
                            }})
                        .background(Color.white).frame(width: nameWidth)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        .focused($focusedField, equals: .field)
                        //                        .onAppear {self.focusedField = .field}
                        .autocapitalization(.words)
                        .textContentType(.name)
                        TextField("(00)", text: $pNum).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        TextField("(1B)", text: $pPos).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .autocapitalization(.none)
                            .textContentType(.none)
                        TextField("(L)", text: $pDir).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .autocapitalization(.none)
                            .textContentType(.none)
                        Picker("Bat Order", selection: $pOrder) {
                            let orders = ["Pick","1st","2nd","3rd","4th",
                                          "5th","6th","7th","8th","9th",
                                          "10th","11th","12th","13th","14th",
                                          "15th","16th","17th","18th","19th"]
                            ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                                Text(order).tag(index)
                            }
                            Text("Not Hitting").tag(99)
                        }
                        .frame(width:mediumWidth).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                        Picker("Player Team", selection: $pTeam) {
                            Text("Pick").tag(Optional<Team>.none)
                            if teams.isEmpty == false {
                                Divider()
                                ForEach(teams) { nteam in
                                    if nteam.name != "" {
                                        Text(nteam.name).tag(Optional(nteam))
                                    }
                                }
                            }
                        }
                        .frame(width: mediumWidth, alignment: .center)
                        .labelsHidden().pickerStyle(.menu).accentColor(.blue)
                        HStack {
                            Image(systemName: "plus.square")
                            Text("Add").onTapGesture {
                                if !dups && pTeam != nil && !pName.isEmpty {
                                    let thisPlayer = Player(name: pName, number: pNum,  position: pPos, batDir: pDir, batOrder: pOrder == 0 ? 99 : pOrder, team:pTeam)
                                    modelContext.insert(thisPlayer)
                                    try? self.modelContext.save()
                                    pName = ""; pOrder = 0; pNum = ""; pDir = ""; pPos = "";pTeam = nil
                                } else if dups {
                                    alertMessage = "Player named \(pName) already exists on \(pTeam!.name)"
                                    showingAlert = true
                                } else {
                                    alertMessage = "Be sure to input a name and select a team for the new player."
                                    showingAlert = true
                                }
                            }
                        }
                        .frame(width: 75, alignment:.center).accentColor(.black).background(.blue.opacity(0.2)).cornerRadius(10)
                        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    }
                    ForEach(players) { player in
                        NavigationLink(value: player) {
                            HStack {
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                                                Text(player.number).frame(width: smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing)
                                                Text(player.position).frame(width: smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing)
                                                Text(player.batDir).frame(width: smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing)
                                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0))
                                    .frame(width: mediumWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing)
                                                Text(player.team?.name ?? "").frame(width: mediumWidth).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing)
                                Text("")
                                    .frame(width:25)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
                header: {
                    if players.count > 0 {
                        Text("Select a Player to edit or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title2).foregroundColor(.black).bold()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Players")
                        .font(.title2)
                }
            }
        }
    }
    
    init(searchString: String = "", sortOrder: [SortDescriptor<Player>] = [],navigationPath:Binding<NavigationPath>) {
        
        _navigationPath = navigationPath
        _players = Query(filter: #Predicate { player in
            if searchString.isEmpty {
                true
            } else {
                player.name.localizedStandardContains(searchString)
                || player.number.localizedStandardContains(searchString)
            }
        },  sort: sortOrder)
    }
    
    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = players[offset]
            if playedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) is associated with game(s). Cannot delete."
            } else if pitchedInGame(player:player) {
                showingAlert = true
                alertMessage = "\(player.name) has pitched in a game. Cannot delete."
            } else {
                modelContext.delete(player)
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
    func checkForDup(pname:String) {
        
        if prevPName == pname {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let teamName = pTeam?.name ?? ""
        let playName = pname
        prevPName = playName
        
        if !teamName.isEmpty && !playName.isEmpty && checkForDups{
            
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName && $0.name == playName}
            
            do {
                let existPlayers = try self.modelContext.fetch(fetchDescriptor)
                
                if existPlayers.first != nil {
                    dups = true
                    showingAlert = true
                    alertMessage = "\(pname) is already on the team."
                } else {
                    dups = false
                }
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            if teamName.isEmpty && !playName.isEmpty {
                showingAlert = true
                alertMessage = "Please select a team so we can check if \(playName) is on already on it."
            }
        }
    }

}


