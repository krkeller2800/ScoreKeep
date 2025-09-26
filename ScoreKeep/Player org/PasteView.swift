//
//  PasteView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/8/25.
//

import SwiftUI
import SwiftData

struct PasteView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var delimeter: String = "Delimeter"
    @State private var delim: String = ""
    @State private var del: String = ""
    @State private var pastedText: String = ""
    @State private var usePasteOrder = false
    @State private var leaveNumBlank = false
    @State private var addDelimeter = false
    @State private var lastNameIdx = 0
    @State private var firstNameIdx = 0
    @State private var numberIdx = 0
    @State private var batsDirIdx = 0
    @State private var positionIdx = 0
    @State private var batOrderIdx = 0
    @State private var pickId = 0
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showPlayers = false

    @State private var players:[String] = []
    @State private var playerComponents:[String] = []
    @State private var number:[String] = []
    @State private var firstName:[String] = []
    @State private var lastName:[String] = []
    @State private var batsDirection:[String] = []
    @State private var position:[String] = []
    @State private var batOrder:[String] = []
    @State private var navigationPath = NavigationPath()
    @State private var team = Team(name: "" ,coach: "",details: "")
    @State private var selectedColor = 0
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var selectPlayers:[Player] = []
    @State private var dels:[String] = ["","Tab","A Space","Comma","Type in"]
    @State private var tgs:[String] = ["","\t"," ",",","Type in"]
    @AppStorage("delimeters") var delimeters: String = "\n\nTab\nA Space\nComma\nType in\nReset"
    @AppStorage("theTags") var theTags: String = "\n\n\t\n \n,\nType in\nReset"

    @Query var teams: [Team]
    
    var body: some View {
        let com = Common()
        NavigationStack(path: $navigationPath) {
            VStack(spacing:0) {
                HStack {
                    Button {
                        addTeam()
                    } label: {
                        Label("Add Team", systemImage: "plus.square")
                    }
                        .foregroundColor(.blue).frame(width:150, alignment: .center).buttonStyle(.bordered)
                    Spacer()
                    if !team.name.isEmpty && selectPlayers.count > 0 {
                        Text("Found \(selectPlayers.count) players on the \(selectPlayers[0].team?.name ?? "(team name not found)"). Pasted players will update or add to these players")
                            .foregroundColor(.red).frame(maxWidth: 500,alignment: .center)
                    }
                    Spacer()
                    Button {
                        showPlayers = false
                        players.removeAll()
                        team = Team(name: "" ,coach: "",details: "")
                        lastNameIdx = 0
                        firstNameIdx = 0
                        numberIdx = 0
                        batsDirIdx = 0
                        positionIdx = 0
                        batOrderIdx = 0
                        delimeter = "Delimeter"
                        pastedText = ""
                        playerComponents.removeAll()
                        number.removeAll()
                        firstName.removeAll()
                        lastName.removeAll()
                        batsDirection.removeAll()
                        position.removeAll()
                        batOrder.removeAll()
                        selectPlayers.removeAll()
                    } label: {
                        Label("Reset", systemImage: "arrow.clockwise")
                    }
                    .foregroundColor(.blue).frame(width:150, alignment: .center).buttonStyle(.bordered)
                }
                HStack {
                    Picker("Team", selection: $team) {
                        Text("Select Team").tag(Team(name: "" ,coach: "",details: ""))
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams, id: \.self) { team in
                                if team.name != "" {
                                    Text(team.name).tag(team)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue)
                    .border(.gray).cornerRadius(10).padding().accentColor(.white)
                    .onChange(of: team) {
                        if !team.name.isEmpty {
                            checkForPlayers()
                            showPlayers = true
                        }
                    }
                    Spacer()
                    Button {
                        let pasteboard = UIPasteboard.general
                        if let string = pasteboard.string {
                            pastedText = string.replacingOccurrences(of: " Jr.", with: "")
                            cleanPaste()
                        } else {
                            alertMessage = "No Text found on clipboard"
                            showingAlert = true
                        }
                    } label: {
                               Label("Paste", systemImage: "doc.on.doc")
                    }
                    .foregroundColor(.white).bold().padding().frame(maxHeight: 35)
                    .background(Color.blue).cornerRadius(20)
                    Spacer()
                    Picker("delimeter", selection: $delimeter) {
                        Text("Delimeter").tag("Delimeter")
                        ForEach(0 ..< dels.count, id: \.self) {
                            if dels[$0] != "" {
                                Text(dels[$0]).tag(tgs[$0])
                            }
                        }
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue)
                    .border(.gray).cornerRadius(10).padding(.leading, 15).padding().accentColor(.white)
                    .alert("Enter your Delimeter", isPresented: $addDelimeter) {
                        TextField("", text: $delim).disableAutocorrection(true).autocapitalization(.none)
                        Button("OK") {
                            if dels.last != "Reset" {
                                dels.append("Reset")
                                tgs.append("Reset")
                            }
                            del = delim
                            if let xx = com.keySym.firstIndex(where: { $0 == delim }) {
                                del = com.keyWord[xx]
                            }
                            dels.insert(del, at: dels.count-2)
                            tgs.insert(delim, at: tgs.count-2)
                            delimeters = dels.joined(separator: "\n")
                            theTags = tgs.joined(separator: "\n")
                            delimeter = delim
                            delim = ""
                        }
                    }
                    message: {
                        Text("Enter the character(s) that separates your fields.")
                    }
                    .onAppear {
                        dels = delimeters.components(separatedBy: "\n")
                        tgs = theTags.components(separatedBy: "\n")
                    }
                }
                Divider()
                HStack {
                    Text("Number").frame(maxWidth: 140,alignment: .center).bold().padding(.leading, 5)
                    Spacer()
                    Text("First").frame(maxWidth: 140,alignment: .center).bold()
                    Spacer()
                    Text("Last").frame(maxWidth: 140,alignment: .center).bold()
                    Spacer()
                    Text("Order").frame(maxWidth: 140,alignment: .center).bold()
                    Spacer()
                    Text("Direction").frame(maxWidth: 140,alignment: .center).bold()
                    Spacer()
                    Text("Position").frame(maxWidth: 140,alignment: .center).bold().padding(.trailing, 5)
                }
                HStack {
                    Picker("Number", selection: $numberIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                    }
                    .frame(width: 130, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 5)
                    .onChange(of: numberIdx) {
                        if numberIdx != 0 {
                            var x = 0
                            for player in players {
                                number.insert(player.components(separatedBy:  delimeter)[numberIdx-1], at: x)
                                x += 1
                            }
                        } else {
                            leaveNumBlank = true
                        }
                    }
                    Spacer()
                    Picker("First Name", selection: $firstNameIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                    }
                    .frame(maxWidth: 140, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black)
                    .onChange(of: firstNameIdx) {
                        if firstNameIdx != 0 {
                            var x = 0
                            for player in players {
                                firstName.insert(player.components(separatedBy: delimeter)[firstNameIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                    Spacer()
                    Picker("Last Name", selection: $lastNameIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                    }
                    .frame(maxWidth: 140, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black)
                    .onChange(of: lastNameIdx) {
                        if lastNameIdx != 0 {
                            var x = 0
                            for player in players {
                                lastName.insert(player.components(separatedBy: delimeter)[lastNameIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                    Spacer()
                    Picker("Order", selection: $batOrderIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Paste order").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black)
                    .onChange(of: batOrderIdx) {
                        var x = 0
                        for player in players {
                            if batOrderIdx != 0 && batOrderIdx != player.components(separatedBy: delimeter).count+2 {
                                batOrder.insert(player.components(separatedBy: delimeter)[batOrderIdx-1], at: x)
                            } else if batOrderIdx != 0 {
                                batOrder.insert(String(x+1), at: x)
                            } else {
                                batOrder.insert("99", at: x)
                            }
                            x += 1
                        }
                    }
                    Spacer()
                    Picker("Batting Dir", selection: $batsDirIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                    }
                    .frame(maxWidth: 140, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black)
                    .onChange(of: batsDirIdx) {
                        if batsDirIdx != 0 {
                            var x = 0
                            for player in players {
                                batsDirection.insert(player.components(separatedBy: delimeter)[batsDirIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                    Spacer()
                    Picker("Position", selection: $positionIdx) {
                        let fnames = playerComponents
                        Text("Void").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                    }
                    .frame(maxWidth: 140, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.trailing, 5)
                    .onChange(of: positionIdx) {
                        if positionIdx != 0 {
                            var x = 0
                            for player in players {
                                position.insert(player.components(separatedBy: delimeter)[positionIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                }
            }
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing:0) {
                    if players.count > 0 {
                        ForEach(Array(players.enumerated()), id: \.1) { index, player in
                            if index < (UIDevice.type == "iPhone" ? 4 : 20) {
                                Text(player).frame(maxWidth: 170, alignment: .leading).lineLimit(1).padding(.leading, 10)
                            }
                        }
                    }
                    Spacer()
                }
                Spacer()
                if !team.name.isEmpty && showPlayers {
                    PlayersOnTeamView(team: team, searchString: "", sortOrder: sortOrder)
                }
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $navigationPath, team: team)
            }
            .navigationDestination(for: Player.self) { player in
                EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
            }
            .onChange(of: delimeter) {
                if delimeter == "Type in" {
                    addDelimeter = true
                } else  if delimeter == "Reset" {
                    delimeter = "Delimeter"
                    delimeters = ["","Tab","A Space","Comma","Type in"].joined(separator: "\n")
                    theTags = ["","\t"," ",",","Type in"].joined(separator: "\n")
                    dels = delimeters.components(separatedBy: "\n")
                    tgs = theTags.components(separatedBy: "\n")
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Paste Lineup")
                        .font(.title2).bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        importPlayers()
                        UIPasteboard.general.items = []
                        players.removeAll()
                    }) {
                        Text("Add or update Players")
                    }
                    .alert(alertMessage, isPresented: $showingAlert) {
                               Button("OK", role: .cancel) { }
                           }
                }
            }
        }
    }
    func importPlayers() {
        if !team.name.isEmpty {
            if numberIdx == 0 && positionIdx == 0 && firstNameIdx == 0 && lastNameIdx == 0 && batsDirIdx == 0 && batOrderIdx == 0 {
                alertMessage = "Please indicate where the fields are in the column headers"
                showingAlert = true
            } else if delimeter == "Delimeter" {
                alertMessage = "Please pick a Delimeter"
                showingAlert = true
            } else {
                var x = 0
                for _ in players {
                    let num = numberIdx == 0 ? "" : number[x]
                    let pos = positionIdx == 0 ? "" : position[x]
                    var Name = firstNameIdx == 0 ? lastName[x]: ""
                        Name = lastNameIdx == 0 ? Name :  firstNameIdx == 0 ? lastName[x] : String("\(firstName[x]) \(lastName[x])")
                        Name = Name.removeAccents()
                        Name = Name.split(separator: " ").count > 2 ? String(Name.split(separator: " ").first! + " " + Name.split(separator: " ").last!) : Name
                    let batdir = batsDirIdx == 0 ? "" : batsDirection[x]
                    let bOrder:Int = batOrder.count > 0 ? Int(batOrder[x]) ?? 99 : 99
                    if bOrder < 20 {
                        for splayer in selectPlayers.filter({$0.batOrder == bOrder}) {
                            splayer.batOrder = 99
                        }
                    }
                    if let pidx = selectPlayers.firstIndex(where: { ($0.name.removeAccents().split(separator: " ").last == Name.split(separator: " ").last &&
                                                                    ((Name.split(separator: " ").first?.count == 1 || $0.name.split(separator: " ").first?.count == 1) ||
                                                                    (Name.split(separator: " ").first?.count == 2 || $0.name.split(separator: " ").first?.count == 2))) ||
                                                                    $0.name.removeAccents() == Name}) {
                        selectPlayers[pidx].batOrder = bOrder == 99 ? selectPlayers[pidx].batOrder : bOrder
                        selectPlayers[pidx].position = pos == "" ? selectPlayers[pidx].position : pos
                        selectPlayers[pidx].number = num == "" ? selectPlayers[pidx].number : num
                        selectPlayers[pidx].batDir = batdir == "" ? selectPlayers[pidx].batDir : batdir
                    } else {
                        let player = Player(name: Name ,number: num, position: pos, batDir: batdir, batOrder: bOrder, team: team)
                        modelContext.insert(player)
                        try? modelContext.save()
                    }
                    x += 1
                }
                try? modelContext.save()
                selectPlayers.removeAll()
            }
        } else {
            alertMessage = "Please select a team"
            showingAlert = true
        }
    }
    func addTeam() {
        let team = Team(name: "", coach: "", details: "")
        modelContext.insert(team)
        try? modelContext.save()
        self.team = team
        navigationPath.append(team)
    }
    init() {
        
        _teams = Query(filter: #Predicate { team in
                true
        })
    }
    func checkForPlayers () {
        
        let teamName = team.name
        
        if !teamName.isEmpty {
            if delimeter == "Delimeter" {
                alertMessage = "Please pick a Delimeter"
                showingAlert = true
            } else {
                
                var fetchDescriptor = FetchDescriptor<Player>()
                
                fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
                
                do {
                    selectPlayers = try self.modelContext.fetch(fetchDescriptor)
                } catch {
                    print("SwiftData Error: \(error)")
                }
            }
        }
    }
    func cleanPaste() {
        if delimeter == "Delimeter" {
            alertMessage = "Please pick a Delimeter"
            showingAlert = true
        } else {
            players = pastedText.components(separatedBy: "\n")
            players.removeAll {
                $0.components(separatedBy: delimeter).count <= 1
            }
            players.removeAll {
                $0.contains("PLAYER") || $0.contains("Player")
            }
            var nArray = players
            for (index, player) in nArray.enumerated() {
                nArray[index] = player.trimmingCharacters(in: .whitespaces)
            }
            players = nArray
            
            if players.count > 0 {
                if players[0].components(separatedBy: delimeter).count > 3 {
                    playerComponents = players[0].components(separatedBy: delimeter)
                    players.removeAll {
                        $0.components(separatedBy: delimeter).count < 3
                    }
                    let componentNum: Int = players[0].components(separatedBy: delimeter).count
                    for player in players {
                        if !(player.components(separatedBy: delimeter).count == componentNum) {
                            alertMessage = "Removed \(player) Due to inonsistant number of fields"
                            showingAlert.toggle()
                            players.removeAll() { $0 == player }
                        }
                    }
                } else {
                    alertMessage = "could not parse header row"
                    showingAlert.toggle()
                }
            } else {
                alertMessage = "No Text found on clipboard"
                showingAlert.toggle()
            }
            playerComponents.insert("", at: 0)
        }
    }
}

