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
    @State private var alertMessage = ""
    @State private var showingAlert = false

    @State private var players:[String] = []
    @State private var playerComponents:[String] = []
    @State private var number:[String] = []
    @State private var firstName:[String] = []
    @State private var lastName:[String] = []
    @State private var batsDirection:[String] = []
    @State private var position:[String] = []
    @State private var batOrder:[String] = []
    @State private var navigationPath = NavigationPath()
    @State private var team:Team?
    @State private var selectedColor = 0
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var selectPlayers:[Player] = []
    @State private var dels:[String] = ["","Tab","A Space","Comma","Type in"]
    @State private var tgs:[String] = ["","\t"," ",",","Type in"]

    @Query var teams: [Team]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing:0) {
                HStack {
                    Button("Add team", action: addTeam)
                        .foregroundColor(.blue).frame(width:150, alignment: .center).buttonStyle(.bordered)
                    Spacer()
                    if team != nil && selectPlayers.count > 0 {
                        Text("Found \(selectPlayers.count) players on the \(selectPlayers[0].team?.name ?? "(team name not found)"). Pasted players will update or add to these players")
                            .foregroundColor(.red).frame(maxWidth: 500,alignment: .center)
                    }
                    Spacer()
                    Spacer()
                }
                HStack {
                    Picker("Team", selection: $team) {
                        Text("Select Team").tag(Optional<Team>.none)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams) { team in
                                if team.name != "" {
                                    Text(team.name).tag(Optional(team))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 140,maxHeight: 40, alignment:.center).background(.blue)
                    .border(.gray).cornerRadius(10).padding().accentColor(.white)
                    .onChange(of: team) { checkForPlayers() }
                    Spacer()
                    PasteButton(payloadType: String.self) { strings in
                        let replaced = strings[0].replacingOccurrences(of: " Jr.", with: "_Jr.")
                        pastedText = replaced
                        cleanPaste()
                    }
                    Spacer()
                    Picker("delimeter", selection: $delimeter) {
                        Text("Delimeter").tag("Delimeter")
                        ForEach(Array(dels.enumerated()), id: \.1) { index, del in
                            if !del.isEmpty {
                                Text(del).tag(tgs[index])
                            }
                        }
                    }
                    .onChange(of: delimeter) {
                        if delimeter == "Type in" {
                            delimeter = ""
                            addDelimeter = true
                        }
                    }
                    .frame(maxWidth: 140,maxHeight: 40, alignment:.center).background(.blue)
                    .border(.gray).cornerRadius(10).padding(.leading, 15).padding().accentColor(.white)
                    .alert("Enter your Delimeter", isPresented: $addDelimeter) {
                        TextField("", text: $delimeter).disableAutocorrection(true).autocapitalization(.none)
                        Button("OK") {
                            dels.insert(delimeter, at: dels.count-1)
                            tgs.insert(delimeter, at: tgs.count-1)
                            writeFile(fileName: "dels.txt", file: dels)
                            writeFile(fileName: "tgs.txt", file: tgs)
                        }
                    }
                    message: {
                        Text("Enter the character(s) that separates your fields.")
                    }
                    .onAppear {
                        let thedels = readFile(fileName: "dels.txt")
                        let thetgs = readFile(fileName: "tgs.txt")
                        if !thedels.isEmpty && !thetgs.isEmpty && thedels.count == thetgs.count {
                            dels = thedels
                            tgs = thetgs
                        }
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Picker("Number", selection: $numberIdx) {
                        let fnames = playerComponents
                        Text("Number").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Leave Blank").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: numberIdx) {
                        if numberIdx != playerComponents.count+1 {
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
                        Text("First Name").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Leave Blank").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: firstNameIdx) {
                        if firstNameIdx != playerComponents.count+1 {
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
                        Text("Last Name").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Leave Blank").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: lastNameIdx) {
                        if lastNameIdx != playerComponents.count+1 {
                            var x = 0
                            for player in players {
                                lastName.insert(player.components(separatedBy: delimeter)[lastNameIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                    Spacer()
                    Picker("Bat Order", selection: $batOrderIdx) {
                        let fnames = playerComponents
                        Text("Batting Order").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Paste order").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 190,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: batOrderIdx) {
                        var x = 0
                        for player in players {
                            if batOrderIdx != playerComponents.count+1 {
                                batOrder.insert(player.components(separatedBy: delimeter)[batOrderIdx-1], at: x)
                            } else {
                                batOrder.insert(String(x+1), at: x)
                            }
                            x += 1
                        }
                    }
                    Spacer()

                    Picker("Bat Dir", selection: $batsDirIdx) {
                        let fnames = playerComponents
                        Text("Bat Direction").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Leave Blank").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: batsDirIdx) {
                        if batsDirIdx != playerComponents.count+1 {
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
                        Text("Position").tag(0)
                        ForEach(0 ..< fnames.count, id: \.self) {
                            if fnames[$0] != "" {
                                Text(fnames[$0])
                            }
                        }
                        Text("Leave Blank").tag(fnames.count+1)
                    }
                    .frame(maxWidth: 140,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                    .onChange(of: positionIdx) {
                        if positionIdx != playerComponents.count+1 {
                            var x = 0
                            for player in players {
                                position.insert(player.components(separatedBy: delimeter)[positionIdx-1], at: x)
                                x += 1
                            }
                        }
                    }
                    Spacer()
                }
            }
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing:0) {
                    if players.count > 0 {
                        ForEach (players, id: \.self) { player in
                            Text(player).frame(maxWidth: 250, alignment: .leading).lineLimit(1).padding(.leading, 10)
                        }
                    }
                    Spacer()
                }
                Spacer()
                if team != nil {
                    PlayersOnTeamView(teamName: team!.name, searchString: "", sortOrder: sortOrder)
                        .navigationDestination(for: Player.self) { player in
                            EditPlayerView( player: player, team: team!, navigationPath: $navigationPath)
                        }
                }
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $navigationPath, team: team)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("< Back")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Import Lineup")
                        .font(.title2).bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        importPlayers()
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
        if team != nil {
            if numberIdx == 0 || lastNameIdx == 0 || firstNameIdx == 0 || positionIdx == 0 || batsDirIdx == 0 || batOrderIdx == 0 {
                alertMessage = "Please finish filling out the header row"
                showingAlert = true
            } else if delimeter == "Delimeter" {
                alertMessage = "Please pick a Delimeter"
                showingAlert = true
            } else {
                var x = 0
                for _ in players {
                    let bOrder:Int = Int(batOrder[x]) ?? 99
                    if bOrder < 20 {
                        for splayer in selectPlayers.filter({$0.batOrder == bOrder}) {
                            splayer.batOrder = 99
                        }
                    }
                    let num = numberIdx == playerComponents.count + 1 ? "" : number[x]
                    let pos = positionIdx == playerComponents.count + 1 ? "" : position[x]
                    var Name = firstNameIdx == playerComponents.count + 1 ? lastName[x]: firstName[x]
                        Name = lastNameIdx == playerComponents.count + 1 ? Name :  firstNameIdx == playerComponents.count + 1 ? lastName[x] : String("\(firstName[x]) \(lastName[x])")
                    let batdir = batsDirIdx == playerComponents.count + 1 ? "" : batsDirection[x]
                    if let pidx = selectPlayers.firstIndex(where: { $0.name == Name }) {
                        selectPlayers[pidx].batOrder = bOrder
                        selectPlayers[pidx].position = pos == "" ? selectPlayers[pidx].position : pos
                        selectPlayers[pidx].number = num == "" ? selectPlayers[pidx].number : num
                        selectPlayers[pidx].batDir = batdir == "" ? selectPlayers[pidx].batDir : batdir
                    } else {
                        let player = Player(name: Name ,number: num, position: pos, batDir: batdir, batOrder: bOrder, team: team)
                        modelContext.insert(player)
                    }
                    x += 1
                }
                try? modelContext.save()
            }
        } else {
            alertMessage = "Please select a team"
            showingAlert = true
        }
        selectPlayers.removeAll()
    }
    func addTeam() {
        let team = Team(name: "", coach: "", details: "")
        modelContext.insert(team)
        navigationPath.append(team)
    }
    init() {
        
        _teams = Query(filter: #Predicate { team in
                true
        })
    }
    func checkForPlayers () {
        
        let teamName = team?.name ?? ""
        
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
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
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
            
            if players[0].components(separatedBy: delimeter).count > 3 {
                playerComponents = players[0].components(separatedBy: delimeter)
                players.removeAll {
                    $0.components(separatedBy: delimeter).count < 3
                }
            } else {
                alertMessage = "could not parse header row"
                showingAlert.toggle()
            }
            playerComponents.insert("", at: 0)
        }
    }
    func readFile(fileName:String) -> [String] {
        var arrayOfStrings: [String]?
        let filename = URL.documentsDirectory.appending(path: fileName)


           do {
               let data = try String(contentsOfFile:filename.relativePath, encoding: String.Encoding.utf8)
               arrayOfStrings = data.components(separatedBy: "\n")
           } catch let err as NSError {
               print(err)
           }
        return arrayOfStrings ?? []
    }
    func writeFile(fileName:String, file:[String]) {
        let thefile = file
        let joined = thefile.joined(separator: "\n")
        let filename = URL.documentsDirectory.appending(path: fileName)

        do {
            try joined.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch let err as NSError {
            print(err)
        }
    }

}

