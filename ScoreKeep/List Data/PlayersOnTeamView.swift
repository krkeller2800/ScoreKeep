//
//  PlayersOnTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/22/25.
//
import SwiftUI
import SwiftData

struct PlayersOnTeamView: View {
    @Environment(\.modelContext) var modelContext
    
    @State var showHeader: Bool
    @State var pName: String = ""
    @State var pNum: String = ""
    @State var pPos: String = ""
    @State var pDir: String = ""
    @State var team: Team
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
    
    @Query var players: [Player]
    
    var body: some View {
        GeometryReader { geometry in
            List {
                let nameWidth =  geometry.size.width/4
//                let smallWidth =  geometry.size.width/12
                let mediumWidth =  geometry.size.width/9
                
                Section {
                    HStack {
                        Text("Order")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.6).padding(.leading,10)
                        Text("Name")
                            .frame(width:nameWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Num")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Pos")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Dir")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("")
                            .frame(width:20)
                    }
                    HStack {
                        Picker("Bat Order", selection: $pOrder) {
                            let orders = ["?","1st","2nd","3rd","4th",
                                          "5th","6th","7th","8th","9th",
                                          "10th","11th","12th","13th","14th",
                                          "15th","16th","17th","18th","19th"]
                            ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                                Text(order).tag(index)
                            }
                            Text("Not Hitting").tag(99)
                        }
                        .frame(width:mediumWidth).labelsHidden().pickerStyle(.menu).accentColor(.blue).lineLimit(1)
                            .minimumScaleFactor(0.5).padding(.leading,10)
                        TextField("Player", text: $pName, onEditingChanged: { (editingChanged) in
                            if !editingChanged {
                                checkForDup(pname:pName)
                            }})
                        .background(Color.white).frame(width: nameWidth)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue) 
                        .focused($focusedField, equals: .field)
                        //                        .onAppear {self.focusedField = .field}
                        .autocapitalization(.words)
                        .textContentType(.name)
                        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                        TextField("(00)", text: $pNum).background(Color.white).frame(width:mediumWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue)
                        TextField("(1B)", text: $pPos).background(Color.white).frame(width:mediumWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue)
                            .autocapitalization(.none)
                            .textContentType(.none)
                        TextField("(L)", text: $pDir).background(Color.white).frame(width:mediumWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue)
                            .autocapitalization(.none)
                            .textContentType(.none)
                        HStack {
                            Spacer(minLength: 10)
                            Image(systemName: "plus")
                                .onTapGesture {
                                if !dups && !pName.isEmpty {
                                    let thisPlayer = Player(name: pName, number: pNum,  position: pPos, batDir: pDir, batOrder: pOrder == 0 ? 99 : pOrder, team:team)
                                    modelContext.insert(thisPlayer)
                                    try? self.modelContext.save()
                                    renumOrder(players: players.sorted{($0.batOrder < $1.batOrder)}, player: thisPlayer, order: thisPlayer.batOrder)
                                    pName = ""; pOrder = 0; pNum = ""; pDir = ""; pPos = ""
                                } else if dups {
                                    alertMessage = "Player named \(pName) already exists on \(team.name)"
                                    showingAlert = true
                                } else {
                                    alertMessage = "Be sure to input a name for the new player."
                                    showingAlert = true
                                }
                            }
                        }
                        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    }
                    ForEach(players) { player in
                        NavigationLink(value: player) {
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.5)
                                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 0)
                                Text(player.number).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:mediumWidth, alignment: .center).foregroundColor(.black)
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Spacer(minLength: 5)
                            }
                            .padding(.vertical, 0)
                        }
                        .onChange(of: player.batOrder) {
                            renumOrder(players: players.sorted{($0.batOrder < $1.batOrder)}, player: player, order: player.batOrder)
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
                header: {
                    if players.count > 0 && showHeader {
                        Text("Select a Player to edit").frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPhone" ? .callout : .title3).foregroundColor(.black) 
                    }
                }
            }
            .listRowSpacing(0)
        }
    }
    
    init(showHeader: Bool = true, team: Team, searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        
        self.showHeader = showHeader
        self.team = team
        let teamName = team.name
          _players = Query(filter: #Predicate { player in
              if searchString.isEmpty {
                  player.team?.name == teamName
              } else {
                  player.team?.name == teamName &&
                  (player.name.localizedStandardContains(searchString)
                  || player.number.localizedStandardContains(searchString))
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
                team.players.removeAll(where: {$0 == player})
                modelContext.delete(player)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error deleting player: \(error.localizedDescription)"
            showingAlert = true
            print("Error deleting player: \(error.localizedDescription)")
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
        
        if !checkForDups {
            if !teamName.isEmpty && !playName.isEmpty {
                
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
    func renumOrder(players:[Player], player:Player,order:Int) {
        for (index, oldPlayer) in players.enumerated() {
            if index+1 == order && oldPlayer.batOrder < 99 {
                oldPlayer.batOrder = index+2
            } else if index+1 > order && oldPlayer.batOrder < 99 {
                oldPlayer.batOrder = index+1
            }
            if oldPlayer.name == player.name {
                oldPlayer.batOrder = order
            }
        }
    }
}

