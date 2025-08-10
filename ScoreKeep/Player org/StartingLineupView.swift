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
    @State var addPlayer = false
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State var thisPlayer = Player(name: "", number: "", position: "", batDir: "", batOrder: 99)
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State var pName = ""
    @State var pNumber = ""
    @State var pPosition = ""
    @State var pBatDir = ""
    @State var pBatOrder = 0
    @State private var showingUpdate = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State var searchText:String = ""
    @State private var isSearching = false
    @State private var playerName = ""
    @State private var prevPName = ""
    @State private var dups = false
    @State private var checkForDups = true
    @State var navigationPath: NavigationPath = NavigationPath()

    enum FocusField: Hashable {case field1, field2, field3, field4}
    
    @FocusState private var focusedField: FocusField?
    
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
                        .frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPad" ? .title3 : .callout).foregroundColor(.black)
                    HStack () {
                        Text("Order")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Name")
                            .frame(width: nameWidth).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Text("Num")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Pos")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                        Text("Dir")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                       Text("").frame(width:45)
                    }
                    HStack {
                        Picker("Bat Order", selection: $pBatOrder) {
                            let orders = ["Pick","1st","2nd","3rd","4th",
                                          "5th","6th","7th","8th","9th",
                                          "10th","11th","12th","13th","14th",
                                          "15th","16th","17th","18th","19th"]
                            ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                                Text(order).tag(index)
                            }
                            Text("Not Hitting").tag(99)
                        }
                        .frame(width:smallWidth).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                        TextField("Name", text: $pName)
                            .background(Color.white).frame(width:nameWidth).textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .focused($focusedField, equals: .field1)
                            .onSubmit {
                                focusedField = .field2 // Move focus to the next field
                            }
//                            .onChange(of: focusedField) { checkForDup(pname: pName)}
//                            .onAppear {self.focusedField = .field1}
                            .autocapitalization(.words)
                            .textContentType(.none)
                            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                        TextField("00", text: $pNumber).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .focused($focusedField, equals: .field2)
                            .onSubmit {
                                focusedField = .field3 // Move focus to the next field
                            }
                        TextField("1B", text: $pPosition).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .focused($focusedField, equals: .field3)
                            .onSubmit {
                                focusedField = .field4 // Move focus to the next field
                            }
                        TextField("(L)", text: $pBatDir).background(Color.white).frame(width:smallWidth)
                            .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                            .focused($focusedField, equals: .field4)
                        Spacer(minLength: 75)
                        Image(systemName: "plus")
                            .onTapGesture {
                            checkForDup(pname: pName)
                            if !dups {
                                thisPlayer = Player(name: pName, number: pNumber, position: pPosition, batDir: pBatDir, batOrder: pBatOrder, team: team)
                                modelContext.insert(thisPlayer)
                                pName = ""; pNumber = ""; pPosition = ""; pBatDir = ""; pBatOrder = 0
                                linePlayers = players.sorted(by: { $0.batOrder < $1.batOrder })
                                for (index, player) in linePlayers.enumerated() {
                                    if index+1 <= numOfHitters || lineup.everyoneHits {
                                        player.batOrder = index+1
                                    } else if !lineup.everyoneHits {
                                        player.batOrder = 99
                                    }
                                }
                                try? self.modelContext.save()
                            }
                        }
                        .border(.gray).cornerRadius(10).accentColor(.black).background(.blue.opacity(0.2))
                    }
                    ForEach(linePlayers) { player in
                        NavigationLink(destination: EditPlayerView( player: player, team: team, navigationPath: $navigationPath)) { // Navigate to a DetailView
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundColor(.black).bold().lineLimit(1).minimumScaleFactor(0.5)
                                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 0)
                                Text(player.number).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
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
                .onAppear {
                    if let prevLineup = lineups.first(where: { $0.team == team && $0.game == game }) {
                        updDateLineup = true
                        lineup = prevLineup
                        linePlayers = lineup.players.sorted(by: { $0.batOrder < $1.batOrder })
                    } else {
                        linePlayers = players.sorted(by: { $0.batOrder < $1.batOrder })
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
                        Text("\(team.name) Lineup").font(.title2)
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
                        .frame(maxWidth: 135,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.horizontal, 10)
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
                }
                .searchable(if: isSearching, text: $searchText, placement: .automatic, prompt: "Player name or number")
                .onAppear {
                    if UIDevice.type == "iPhone" {
                       isSearching = false
                    } else {
                        isSearching = true
                    }
                }
                Spacer()
            }
        }
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
    func checkForDup(pname:String) {
        
        if prevPName == pname {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let teamName = team.name
        let playName = pname
        prevPName = playName
        dups = false
        
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
                alertMessage = "Please select a team so we can check if \(pname) is already on it."
                dups = true
            } else  if playName.isEmpty {
                showingAlert = true
                alertMessage = "Please input at least a Player name."
                dups = true
            }
        }
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
}


