//
//  ShareContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/18/25.
//

import SwiftUI
import SwiftData

struct ShareContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var team:Team?
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var path = NavigationPath()
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var importPlayers = false
    @State private var searchText = ""
    @State private var playerURL: URL?
    @State private var players:[Player] = []
    @State private var sharePlayers:[SharePlayer] = []

    @Query var teams: [Team]
    
    @AppStorage("selectedShareCriteria") var selectedShareCriteria: SortCriteria = .orderAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedShareCriteria {
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

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                VStack {
                    Text("To share a lineup with another device running ScoreKeep, select a team from the dropdown and all the Players on that team will be displayed.  If you want to share these players so they can be added to the ScoreKeep app on another iPad - hit the share button.  A share pane will displayed so the lineup file can be Emailed, texted, etc to another iPad.  Once received, the recipient can simply touch the file in the Email and the file will be sent to ScoreKeep's import screen or, depending on the iPad, displayed. An \"Open in ScoreKeep\" button will be at the top right of the screen.")
                        .padding().italic().font(.title3)
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
                        .frame(maxWidth: 175,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, geometry.size.width / 3 - 125)
                        .onChange(of: team) {
                            if team == nil {
                                showingAlert = true
                                alertMessage = "Please select a team"
                            } else {
                                if let playerData = generatePlayers() {
                                    playerURL = savePlayers(playerData: playerData, fileName: team!.name)
                                 }
                                 players.removeAll()
                                 sharePlayers.removeAll()
                            }
                        }
                        if let playerURL = playerURL {
                            ShareLink("Share \(team!.name)", item: playerURL).padding()
                                .frame(maxHeight: 50, alignment:.center).background(.blue.opacity(0.2)).font(.title3)
                                .border(.gray).cornerRadius(10).foregroundColor(.black).padding(.leading, (geometry.size.width / 3) - 125)
                        } else {
                            Button {
                                showingAlert = true
                                alertMessage = "Please select a team"
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .frame(maxWidth: 175, maxHeight: 50, alignment:.center).background(.blue.opacity(0.2)).font(.title3)
                            .border(.gray).cornerRadius(10).foregroundColor(.black).padding(.leading, (geometry.size.width / 3) - 125)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if team != nil {
                        PlayersOnTeamView(team: team!, searchString: searchText, sortOrder: sortOrder)
                    }
                    Spacer()
                }
                .navigationDestination(for: Player.self) { player in
                    EditPlayerView( player: player, team: team!, navigationPath: $path)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Share \(team?.name ?? "") Lineup")
                            .font(.title2).bold()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            
                        }) {
                            
                        }
                        .alert(alertMessage, isPresented: $showingAlert) {
                            Button("OK", role: .cancel) { }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $selectedShareCriteria) {
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
                }
                .searchable(text: $searchText, prompt: "Player name or number")
                .onChange(of: sortDescriptor) {
                    sortOrder = sortDescriptor
                }
            }
        }
    }
    init() {
        
        _teams = Query(filter: #Predicate { team in
                true
        })
    }
    func generatePlayers() -> Data? {
        getPlayers()
        for player in players {
            let shareplayer = SharePlayer(name: player.name, number: player.number, position: player.position, batDir: player.batDir,
                                          batOrder: player.batOrder, photo: player.photo ?? Data())
            sharePlayers.append(shareplayer)
        }
        let encoder = JSONEncoder()
            // Error handling for encoding
        if let encodedData = try? encoder.encode(sharePlayers) {
            return encodedData
        } else {
            return Data() // Return empty data on error
        }
    }
    func savePlayers(playerData: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentDirectory.appendingPathComponent("\(fileName).ScoreKeep_Players")
        
        do {
            try playerData.write(to: fileURL)
            print(fileURL.absoluteString)
            return fileURL
        } catch {
            print("Error saving Players: \(error.localizedDescription)")
            return nil
        }
    }
    func getPlayers () {
        
        let teamName = team?.name ?? ""
        
        if !teamName.isEmpty {
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
            
            do {
                players = try self.modelContext.fetch(fetchDescriptor)
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
        }
    }
}


