//
//  ImportPlayersView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/18/25.
//

import SwiftUI
import SwiftData

struct ImportPlayersView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State         var importURL:URL
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var navigationPath = NavigationPath()
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var sharePlayers: [SharePlayer] = []
    @State private var searchText = ""
    @State private var team: Team?

    @Query var teams: [Team]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    Text("Which Players shouldn't have non-blank fields overwritten?")
                        .bold().italic().lineLimit(1).minimumScaleFactor(0.5)
                    Button("Imported") {
                        sharedPlayersBoss(sharedPlayers: sharePlayers)
                        alertMessage = "Import Complete"
                        showingAlert = true
                    }
                    .foregroundColor(.blue).buttonStyle(.bordered)
                    Text(" or ")
                    Button("Current") {
                        currentPlayersBoss(sharedPlayers: sharePlayers)
                        alertMessage = "Import Complete"
                        showingAlert = true
                    }
                    .foregroundColor(.blue).buttonStyle(.bordered)
                }
                HStack {
                    let teamName = importURL.lastPathComponent.count > 0 ? importURL.lastPathComponent.components(separatedBy: ".")[0] : "Unknown"
                    let tm = teams.first(where: { $0.name == teamName }) != nil ? teams.first(where: { $0.name == teamName })! : Team(name: teamName, coach: "", details: "")
                    VStack {
                        Text("Imported \(teamName) Players")
                        showSharedPlayers(sharePlayers: $sharePlayers, searchText: searchText)
                    }
                    Spacer()
                    VStack {
                        Text("Current \(teamName) Players")
                        PlayersOnTeamView(showHeader: true, team: tm, searchString: searchText, sortOrder: sortOrder)
                    }
                    .alert(alertMessage, isPresented: $showingAlert) {
                        Button("OK", role: .cancel) { }
                    }
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView( player: player, team: tm, navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: Team.self) { team in
                        EditTeamView(navigationPath: $navigationPath, team: team)
                    }
                    .onAppear() {
                        sharePlayers = decode()
                   }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Import Players")
                                .font(.title2).bold()
                        }
                    }
                    .searchable(text: $searchText,  prompt: "Player Name or Number")
                }
            }
        }
    }
    init(iURL: URL) {
        self.importURL = iURL
    }
    func decode() -> [SharePlayer] {
        
        let needsAccess = importURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                importURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: importURL.absoluteURL)
        
            let decoder = JSONDecoder()
            
            guard let loadedFile = try? decoder.decode([SharePlayer].self, from: data) else {
                fatalError("Failed to decode \(importURL)")
            }
            return loadedFile.sorted { $0.batOrder < $1.batOrder }
        }
        catch {
            alertMessage = "Error reading file: \(error.localizedDescription)"
            showingAlert = true
        }
        return []
    }
    func sharedPlayersBoss (sharedPlayers: [SharePlayer]) {
        let players = getCurrentPlayers()
        for sharePlayer in sharedPlayers {
            if let currPlayer = players.first(where: { $0.name == sharePlayer.name }) {
                currPlayer.number = !sharePlayer.number.isEmpty ? sharePlayer.number : currPlayer.number
                currPlayer.batOrder = sharePlayer.batOrder < 50 ? sharePlayer.batOrder : currPlayer.batOrder
                currPlayer.batDir = !sharePlayer.batDir.isEmpty ? sharePlayer.batDir : currPlayer.batDir
                currPlayer.position = !sharePlayer.position.isEmpty ? sharePlayer.position : currPlayer.position
                currPlayer.photo = !sharePlayer.photo.isEmpty ? sharePlayer.photo : currPlayer.photo
            }
            else {
                let newPlayer = Player(name: sharePlayer.name, number: sharePlayer.number, position: sharePlayer.position,
                                       batDir: sharePlayer.batDir, batOrder: sharePlayer.batOrder, team: team)
                modelContext.insert(newPlayer)
                team?.players.append(newPlayer)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "SwiftData Error: \(error)"
            showingAlert = true
        }
    }
    func currentPlayersBoss (sharedPlayers: [SharePlayer]) {
        
        let players = getCurrentPlayers()
        for sharePlayer in sharedPlayers {
            if let currPlayer = players.first(where: { $0.name == sharePlayer.name }) {
                currPlayer.number = currPlayer.number.isEmpty ? sharePlayer.number : currPlayer.number
                currPlayer.batOrder = currPlayer.batOrder > 50 ? sharePlayer.batOrder : currPlayer.batOrder
                currPlayer.batDir = currPlayer.batDir.isEmpty ? sharePlayer.batDir : currPlayer.batDir
                currPlayer.position = currPlayer.position.isEmpty ? sharePlayer.position : currPlayer.position
                currPlayer.photo = currPlayer.photo?.isEmpty ?? true ? sharePlayer.photo : currPlayer.photo
            }
            else {
                let newPlayer = Player(name: sharePlayer.name, number: sharePlayer.number, position: sharePlayer.position,
                                       batDir: sharePlayer.batDir, batOrder: sharePlayer.batOrder, team: team)
                modelContext.insert(newPlayer)
                team?.players.append(newPlayer)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "SwiftData Error: \(error)"
            showingAlert = true
            print("SwiftData Error: \(error)")
        }
    }
    func getCurrentPlayers() -> [Player] {
        let teamName = importURL.lastPathComponent.count > 0 ? importURL.lastPathComponent.components(separatedBy: ".")[0] : ""
          
        if !teams.contains(where: { $0.name == teamName }) {
            alertMessage = "No team named \(teamName) found on this device.  Creating a new one."
            showingAlert = true
            let theTeam = Team(name: teamName, coach: "", details: "")
            modelContext.insert(theTeam)
            try? modelContext.save()
            team = theTeam
            do {
                try modelContext.save()
            }
            catch {
                alertMessage = DataError.savingData(dataType:"Players").localizedDescription
                showingAlert = true
                print(DataError.SwiftDataError(error: error).localizedDescription)
            }
        } else {
            team = teams.first(where: { $0.name == teamName })!
        }
        
        var fetchDescriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder)])
        fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
        
        do {
            let players = try self.modelContext.fetch(fetchDescriptor)
            return players
        }
        catch {
            alertMessage = "SwiftData Error: \(error)"
            showingAlert = true
            return []
        }
    }
}
struct showSharedPlayers: View {
    
    @Binding var sharePlayers: [SharePlayer]
             var searchText: String
    
    var body: some View {
        GeometryReader { geometry in
            Form {
                let nameWidth =  geometry.size.width/4
                let smallWidth =  geometry.size.width/12
                let mediumWidth =  geometry.size.width/8
                
                Section {
                    HStack {
                        Text("Order")
                            .frame(width:mediumWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.6)
                        Text("Name")
                            .frame(width:nameWidth).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                        Text("Num")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Pos")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("Dir")
                            .frame(width:smallWidth).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.5)
                        Text("")
                            .frame(width:70)
                    }
                    ForEach(sharePlayers) { player in
                        if player.name.localizedStandardContains(searchText) || player.number.localizedStandardContains(searchText) || searchText.isEmpty {
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:mediumWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundColor(.black).bold().lineLimit(1).minimumScaleFactor(0.5)
                                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 0)
                                Text(player.number).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:smallWidth, alignment: .center).foregroundColor(.black).bold()
                                    .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                                Text("").frame(width:50)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
                header: {
                    if sharePlayers.count > 0 {
                        Text("Swipe a Player from the left to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title2).foregroundColor(.black).bold()
                    }
                 }
            }
        }
    }
    func deletePlayer(at offsets: IndexSet) {
        sharePlayers.remove(atOffsets: offsets)
    }

}
