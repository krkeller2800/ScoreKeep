//
//  PasteView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/8/25.
//

import SwiftUI
import SwiftData

struct PasteLineupMappedRow: Equatable {
    let number: String?
    let firstName: String?
    let lastName: String?
    let batsDirection: String?
    let position: String?
    let batOrder: String?
}

enum PasteLineupHeaderRowPolicy {
    static func isHeaderRow(_ row: PasteLineupMappedRow) -> Bool {
        let mappedValues = [
            row.number.map { ($0, Field.number) },
            row.firstName.map { ($0, Field.firstName) },
            row.lastName.map { ($0, Field.lastName) },
            row.batsDirection.map { ($0, Field.batsDirection) },
            row.position.map { ($0, Field.position) },
            row.batOrder.map { ($0, Field.batOrder) }
        ].compactMap { $0 }

        guard mappedValues.count > 1 else { return false }
        return mappedValues.filter { fieldMatchesHeader(value: $0.0, field: $0.1) }.count >= 2
    }

    private enum Field {
        case number
        case firstName
        case lastName
        case batsDirection
        case position
        case batOrder
    }

    private static func fieldMatchesHeader(value: String, field: Field) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch field {
        case .number:
            return ["#", "no", "num", "number", "jersey", "jersey number"].contains(normalized)
        case .firstName:
            return ["first", "first name", "firstname", "given name", "name", "player", "player name"].contains(normalized)
        case .lastName:
            return ["last", "last name", "lastname", "surname", "name", "player", "player name"].contains(normalized)
        case .batsDirection:
            return ["b", "bat", "bats", "batting", "batting direction", "direction", "l/r", "lr", "hand", "throws"].contains(normalized)
        case .position:
            return ["pos", "position", "positions"].contains(normalized)
        case .batOrder:
            return ["bo", "order", "bat order", "batting order", "lineup", "lineup order", "slot"].contains(normalized)
        }
    }
}

enum PasteLineupBattingOrderPolicy {
    static func resolvedOrder(mappedValue: String, usesPasteOrder: Bool, importedPlayerIndex: Int) -> Int {
        let mappedOrder = usesPasteOrder ? importedPlayerIndex + 1 : Int(mappedValue.trimmingCharacters(in: .whitespaces))
        return PlayerRosterBattingOrder.normalizedRosterOrder(mappedOrder ?? PlayerRosterBattingOrder.notHitting)
    }
}

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
    @State private var showDeleteAlert = false
    @State private var deletePlayersCount = 0
    @State private var deleteAtbatsCount = 0
    @State private var deletePitchersCount = 0

    @State private var players:[String] = []
    @State private var playerComponents:[String] = []
    @State private var number:[String] = []
    @State private var firstName:[String] = []
    @State private var lastName:[String] = []
    @State private var batsDirection:[String] = []
    @State private var position:[String] = []
    @State private var batOrder:[String] = []
    @State private var navigationPath = NavigationPath()
    @State private var team: Team?
//    @State private var team = Team(name: "" ,coach: "",details: "")
    @State private var selectedColor = 0
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var selectPlayers:[Player] = []
    @State private var newTeam = false
    @State private var dels:[String] = ["","Tab","A Space","Comma","Type in"]
    @State private var tgs:[String] = ["","\t"," ",",","Type in"]
    @AppStorage("delimeters") var delimeters: String = "\n\nTab\nA Space\nComma\nType in\nReset"
    @AppStorage("theTags") var theTags: String = "\n\n\t\n \n,\nType in\nReset"

    @State private var previousTeam: Team?
    @State private var showingAddTeam = false

    @Query var teams: [Team]
    
    var body: some View {
        let com = Common()
        NavigationStack(path: $navigationPath) {
            VStack(spacing:0) {
                // Header row
                HStack(alignment: .center) {
                    Spacer()

                    if let team, !team.name.isEmpty && selectPlayers.count > 0 && !newTeam {
                        Text("Found \(selectPlayers.count) players on the \(selectPlayers[0].team?.name ?? "(team name not found)"). Pasted players will update or be added.")
                            .foregroundColor(.red)
                            .frame(maxWidth: 500,alignment: .center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else {
                        HStack {
                            // Inline tip with info icon
                            Label {
                                Text("Tip: Tab is usually the delimiter for spreadsheet clipboard copying.")
                                    .font(.footnote).foregroundColor(.red)
                            } icon: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(ScoreKeepVisualStyle.accent)
                            }
                            .frame(height: 34, alignment: .center)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                        }
                    }
                    Spacer()

                    Button {
                        showPlayers = false
                        players.removeAll()
                        team = nil
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
                            .frame(maxWidth: 150)
                    }
                    .tint(ScoreKeepVisualStyle.accent)
                    .buttonStyle(.bordered)
                    .frame(width:150, height: 44, alignment: .center)
                }

                // Controls row with consistent heights
                HStack(alignment: .center) {
                    Picker(selection: $team) {
                        Text("Select Team").tag(nil as Team?)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams, id: \.self) { t in
                                if t.name != "" {
                                    Text(t.name).tag(t as Team?)
                                }
                            }
                        }
                    } label: {
                        Text(team?.name ?? "Select Team")
                    }
                    
                    .frame(width: 140, height: 34, alignment:.center)
                    .background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10)
                    .padding()
                    .tint(ScoreKeepVisualStyle.primaryText)
                    .onChange(of: team) {
                        if let t = team, t.name.isEmpty {
                            team = previousTeam
                        } else {
                            previousTeam = team
                        }
                        if let team, !team.name.isEmpty {
                            checkForPlayers()
                            showPlayers = true
                            newTeam = false
                        } else {
                            showPlayers = false
                        }
                    }

                    Button("Create Team...") {
                        showingAddTeam = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Create Team")

                    Spacer()

                    Button {
                        let pasteboard = UIPasteboard.general
                        if let string = pasteboard.string {
                            pastedText = string.replacingOccurrences(of: " Jr.", with: "")
                            cleanPaste()
                            if lastNameIdx > 0 {
                                updNum()
                                updPos()
                                updFName()
                                updLName()
                                updBatDir()
                                updBatOrder()
                                updPos()
                            }
                        } else {
                            alertMessage = "No Text found on clipboard"
                            showingAlert = true
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.doc")
                            .frame(minWidth: 120)
                    }
                    .foregroundColor(.white)
                    .bold()
                    .frame(height: 34)
                    .padding(.horizontal)
                    .background(ScoreKeepVisualStyle.accent)
                    .cornerRadius(22)

                    Spacer()

                    Picker("delimeter", selection: $delimeter) {
                        Text("Delimeter").tag("Delimeter")
                        ForEach(0 ..< dels.count, id: \.self) {
                            if dels[$0] != "" {
                                Text(dels[$0]).tag(tgs[$0])
                            }
                        }
                    }
                    .frame(width: 140, height: 34, alignment:.center)
                    .background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10)
                    .padding(.leading, 15)
                    .padding()
                    .tint(ScoreKeepVisualStyle.primaryText)
                    .alert("Enter your Delimeter", isPresented: $addDelimeter) {
                        TextField("", text: $delim).disableAutocorrection(true).autocapitalization(.none)
                        Button("OK") {
                            if dels.last != "Reset" {
                                dels.append("Reset")
                                tgs.append("Reset")
                            }
                            var display = delim
                            if let xx = com.keySym.firstIndex(where: { $0 == delim }) {
                                display = com.keyWord[xx]
                            }
                            dels.insert(display, at: dels.count-2)
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
                    .frame(width: 130, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText).padding(.leading, 5)
                    .onChange(of: numberIdx) {
                        updNum()
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
                    .frame(maxWidth: 140, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText)
                    .onChange(of: firstNameIdx) {
                        updFName()
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
                    .frame(maxWidth: 140, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText)
                    .onChange(of: lastNameIdx) {
                        updLName()
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
                    .frame(maxWidth: 140, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText)
                    .onChange(of: batOrderIdx) {
                        updBatOrder()
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
                    .frame(maxWidth: 140, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText)
                    .onChange(of: batsDirIdx) {
                        updBatDir()
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
                    .frame(maxWidth: 140, alignment:.center).background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(10).tint(ScoreKeepVisualStyle.primaryText).padding(.trailing, 5)
                    .onChange(of: positionIdx) {
                        updPos()
                    }
                }
            }
            .onAppear {
                if let t = team, t.name.isEmpty {
                    team = previousTeam
                } else if let t = team, !t.name.isEmpty {
                    checkForPlayers()
                    showPlayers = true
                    newTeam = false
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
                if let team, !team.name.isEmpty && showPlayers {
                    PlayersOnTeamView(team: team, searchString: "", sortOrder: sortOrder)
                }
            }
            .navigationDestination(for: TeamNavigationDestination.self) { destination in
                TeamNavigationDestinationView(destination: destination, navigationPath: $navigationPath)
            }
            .navigationDestination(for: Player.self) { player in
                if let team {
                    EditPlayerView(player: player, team: team, navigationPath: $navigationPath)
                } else {
                    EditPlayerView(player: player, team: player.team ?? Team(name: "", coach: "", details: ""), navigationPath: $navigationPath)
                }
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
            .sheet(isPresented: $showingAddTeam) {
                NavigationStack {
                    AddTeamDraftView { createdTeam in
                        selectCreatedTeam(createdTeam)
                    }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if team == nil || (team?.name.isEmpty ?? true) {
                            alertMessage = "Please select a team"
                            showingAlert = true
                        } else {
                            let impact = countImpactsForSelectedTeam()
                            deletePlayersCount = impact.players
                            deleteAtbatsCount = impact.atbats
                            deletePitchersCount = impact.pitchers
                            showDeleteAlert = true
                        }
                    } label: {
                        Text("Delete Players")
//                      Label("Delete Players", systemImage: "trash")
//                            .frame(maxWidth: 200)
                    }
                    .foregroundColor(.red)
//                    .buttonStyle(.bordered)
//                    .frame(width:200, height: 44, alignment: .center)
                    .alert("Delete Team Players?", isPresented: $showDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            deleteAllPlayersOnSelectedTeam()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will delete \(deletePlayersCount) players on the \(team?.name ?? "") and also delete \(deleteAtbatsCount) at-bats and \(deletePitchersCount) pitcher entries linked to those players across all games. This cannot be undone.")
                    }
                }
            }
        }
    }
    func importPlayers() {
        if let team, !team.name.isEmpty {
            if numberIdx == 0 && positionIdx == 0 && firstNameIdx == 0 && lastNameIdx == 0 && batsDirIdx == 0 && batOrderIdx == 0 {
                alertMessage = "Please indicate where the fields are in the column headers"
                showingAlert = true
            } else if delimeter == "Delimeter" {
                alertMessage = "Please pick a Delimeter"
                showingAlert = true
            } else {
                var importedPlayerIndex = 0
                for (x, player) in players.enumerated() {
                    let num = numberIdx == 0 ? "" : number[x]
                    let pos = positionIdx == 0 ? "" : position[x]
                    let mappedFirstName = firstNameIdx == 0 ? "" : firstName[x]
                    let mappedLastName = lastNameIdx == 0 ? "" : lastName[x]
                    var Name = firstNameIdx == 0 ? lastName[x]: ""
                    Name = lastNameIdx == 0 ? Name :  firstNameIdx == 0 ? lastName[x] : String("\(mappedFirstName) \(mappedLastName)")
                    Name = Name.removeAccents()
                    Name = Name.split(separator: " ").count > 2 ? String(Name.split(separator: " ").first! + " " + Name.split(separator: " ").last!) : Name
                    let batdir = batsDirIdx == 0 ? "" : batsDirection[x]
                    let usesPasteOrder = batOrderIdx != 0 && batOrderIdx == player.components(separatedBy: delimeter).count + 2
                    let mappedRow = PasteLineupMappedRow(
                        number: numberIdx == 0 ? nil : num,
                        firstName: firstNameIdx == 0 ? nil : mappedFirstName,
                        lastName: lastNameIdx == 0 ? nil : mappedLastName,
                        batsDirection: batsDirIdx == 0 ? nil : batdir,
                        position: positionIdx == 0 ? nil : pos,
                        batOrder: usesPasteOrder || batOrderIdx == 0 ? nil : batOrder[x]
                    )
                    if PasteLineupHeaderRowPolicy.isHeaderRow(mappedRow) {
                        continue
                    }
                    let bOrder = PasteLineupBattingOrderPolicy.resolvedOrder(
                        mappedValue: batOrder[x],
                        usesPasteOrder: usesPasteOrder,
                        importedPlayerIndex: importedPlayerIndex
                    )
                    if RosterImportReconciler.activeSlot(bOrder) != nil {
                        for splayer in selectPlayers.filter({Int($0.batOrder) == bOrder}) {
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
                    importedPlayerIndex += 1
                }
                try? modelContext.save()
                selectPlayers.removeAll()
                // Refresh and display the team's players after a successful import
                checkForPlayers()
                withAnimation {
                    showPlayers = true
                }
            }
        } else {
            alertMessage = "Please select a team"
            showingAlert = true
        }
    }
    private func selectCreatedTeam(_ createdTeam: Team) {
        team = createdTeam
        previousTeam = createdTeam
        newTeam = true
        checkForPlayers()
        showPlayers = true
    }
    init() {
        _teams = Query(filter: #Predicate { team in
            true
        })
    }
    func checkForPlayers () {
        guard let team, !team.name.isEmpty else { return }
        let teamName = team.name
        var fetchDescriptor = FetchDescriptor<Player>()
        fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
        do {
            selectPlayers = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            print("SwiftData Error: \(error)")
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
    func countImpactsForSelectedTeam() -> (players: Int, atbats: Int, pitchers: Int) {
        guard let team else { return (0, 0, 0) }
        let teamName = team.name
        if teamName.isEmpty { return (0, 0, 0) }

        // Players on team
        var pfd = FetchDescriptor<Player>()
        pfd.predicate = #Predicate { $0.team?.name == teamName }
        let players = (try? modelContext.fetch(pfd)) ?? []
        // At-bats for team across all games
        var afd = FetchDescriptor<Atbat>()
        afd.predicate = #Predicate { $0.team.name == teamName }
        let atbats = (try? modelContext.fetch(afd)) ?? []

        // Pitchers for team across all games
        var pitchfd = FetchDescriptor<Pitcher>()
        pitchfd.predicate = #Predicate { $0.team.name == teamName }
        let pitchers = (try? modelContext.fetch(pitchfd)) ?? []

        return (players.count, atbats.count, pitchers.count)
    }

    func deleteAllPlayersOnSelectedTeam() {
        guard let team else { return }
        let tName = team.name
        guard !tName.isEmpty else { return }

        var fd = FetchDescriptor<Player>()
        fd.predicate = #Predicate { $0.team?.name == tName }

        do {
            let players = try modelContext.fetch(fd)
            for p in players {
                modelContext.delete(p)
            }
            try modelContext.save()

            // Refresh UI state
            selectPlayers.removeAll()
            showPlayers = false
            checkForPlayers()
            showPlayers = true
        } catch {
            alertMessage = "Error deleting players: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    func updPos() {
        if positionIdx != 0 {
            var x = 0
            for player in players {
                position.insert(player.components(separatedBy: delimeter)[positionIdx-1], at: x)
                x += 1
            }
        }
    }
    func updBatDir() {
        if batsDirIdx != 0 {
            var x = 0
            for player in players {
                batsDirection.insert(player.components(separatedBy: delimeter)[batsDirIdx-1], at: x)
                x += 1
            }
        }
    }
    func updBatOrder() {
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
    func updLName() {
        if lastNameIdx != 0 {
            var x = 0
            for player in players {
                lastName.insert(player.components(separatedBy: delimeter)[lastNameIdx-1], at: x)
                x += 1
            }
        }
    }
    func updFName() {
        if firstNameIdx != 0 {
            var x = 0
            for player in players {
                firstName.insert(player.components(separatedBy: delimeter)[firstNameIdx-1], at: x)
                x += 1
            }
        }
    }
    func updNum() {
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
}
