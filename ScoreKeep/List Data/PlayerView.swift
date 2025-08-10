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
    @Environment(\.dismiss) var dismiss
    @Binding var navigationPath: NavigationPath
    @State var pName: String = ""
    @State var pNum: String = ""
    @State var pPos: String = ""
    @State var pDir: String = ""
    @State var pOrder: Int = 0
    @State var pTeam: Team
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var playerName = ""
    @State private var prevPName = ""
    @State private var dups = false
    @State private var checkForDups = true
    @State private var isSearching = false
    @Binding private var searchText:String
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    
    @AppStorage("selectedPlayerTCriteria") var selectedPlayerPCriteria: SortCriteria = .orderAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPlayerPCriteria {
        case .nameAsc:
            return [SortDescriptor(\Player.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Player.name, order: .reverse)]
        case .orderAsc:
            return [SortDescriptor(\Player.batOrder, order: .forward)]
        case .numAsc:
            return [SortDescriptor(\Player.number, order: .forward)]
        }
    }

    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]

    @Query var players: [Player]
//    @State var players: [Player] = []

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Form {
                    let nameWidth = geometry.size.width/4
                    let smallWidth = geometry.size.width/13
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
                            TextField("(R)", text: $pDir).background(Color.white).frame(width:smallWidth)
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
                            HStack {
                                Spacer(minLength: 75)
                                Image(systemName: "plus")
                                .onTapGesture {
                                    if !dups && !pName.isEmpty {
                                        let thisPlayer = Player(name: pName, number: pNum,  position: pPos, batDir: pDir, batOrder: pOrder == 0 ? 99 : pOrder, team:pTeam)
                                        modelContext.insert(thisPlayer)
                                        try? self.modelContext.save()
                                        pName = ""; pOrder = 0; pNum = ""; pDir = ""; pPos = "";
                                    } else if dups {
                                        alertMessage = "Player named \(pName) already exists on \(pTeam.name)"
                                        showingAlert = true
                                    } else {
                                        alertMessage = "Be sure to input a name and select a team for the new player."
                                        showingAlert = true
                                    }
                                }
                            }
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
                                    Text("")
                                        .frame(width:25)
                                }
                            }
                        }
                        .onDelete(perform: deletePlayer)
                    }
                    header: {
                        if players.count > 0 {
                            Text("Select a Player to edit").frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPhone" ? .callout : .title3).foregroundColor(.black).bold()
                        }
                    }

                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $selectedPlayerPCriteria) {
                                ForEach(SortCriteria.allCases) { criteria in
                                    if criteria == .nameAsc {
                                        Text("Name (A-Z)").tag(criteria)
                                    } else if criteria == .nameDec {
                                        Text("Name (Z-A)").tag(criteria)
                                    } else if criteria == .numAsc {
                                        Text("Number (A-Z)").tag(criteria)
                                    } else if criteria == .orderAsc {
                                        Text("order (A-Z)").tag(criteria)
                                    }
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("\(pTeam.name) Players")
                            .font(.title2)
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
                .onChange(of: isSearching) {
                    if isSearching == false {
                        searchText = "" // Clear the search text when the search field is dismissed
                    }
                }
                .onChange(of: sortDescriptor) {
                    sortOrder = sortDescriptor
                }
                .navigationDestination(for: Player.self) { player in
                    EditPlayerView( player: player, team: pTeam, navigationPath: $navigationPath)
                }
            }
        }
    }
    
    init(team: Team, navigationPath:Binding<NavigationPath>, searchString: Binding<String>, sortOrder: [SortDescriptor<Player>] = []) {
        
        _navigationPath = navigationPath
        self.pTeam = team
        _searchText = searchString
        let teamName = team.name
          _players = Query(filter: #Predicate { player in
              if searchText.isEmpty {
                  player.team?.name == teamName
              } else {
                  player.team?.name == teamName &&
                  (player.name.localizedStandardContains(searchText)
                  || player.number.localizedStandardContains(searchText))
              }
          },  sort: self.sortDescriptor)
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
        let teamName = pTeam.name
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


