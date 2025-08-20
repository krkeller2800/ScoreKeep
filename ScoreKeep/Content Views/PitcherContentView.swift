//
//  PitcherContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/27/25.
//


import SwiftUI
import SwiftData

struct PitcherContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var team:Team
    @State var game:Game 
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var rpText = ""
    @State private var spText = ""
    @State private var whichPlayers = "All Players"
    @State private var isSearching = false
    @State private var sortOrder = [SortDescriptor(\Player.name)]
    @AppStorage("selectedPitcherCriteria") var selectedPitcherCriteria: SortCriteria = .nameAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, numAsc, numDec
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPitcherCriteria {
        case .nameAsc:
            return [SortDescriptor(\Player.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Player.name, order: .reverse)]
        case .numAsc:
            return [SortDescriptor(\Player.number, order: .forward)]
        case .numDec:
            return [SortDescriptor(\Player.number, order: .reverse)]
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                PitchersStaffView(searchString: searchText, sortOrder: sortDescriptor, passedGame: game, passedTeam: team, theTeam: team.name, rpText: rpText, spText: spText)
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView(player: player, team: team, navigationPath: $navigationPath)
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
                        Picker("Sort", selection: $selectedPitcherCriteria) {
                            ForEach(SortCriteria.allCases) { criteria in
                                if criteria == .nameAsc {
                                    Text("Name (A-Z)").tag(criteria)
                                } else if criteria == .nameDec {
                                    Text("Name (Z-A)").tag(criteria)
                                } else if criteria == .numAsc {
                                    Text("Number (A-Z)").tag(criteria)
                                } else if criteria == .numDec {
                                    Text("Number (Z-A)").tag(criteria)
                                }
                            }
                        }
                    }
                    Button("Add Player", systemImage: "plus", action: addPlayers)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let options = ["Pitchers","All Players"]
                    Picker("Select Option", selection: $whichPlayers) {
                        ForEach(options, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
            .onChange(of: whichPlayers) {
                if whichPlayers == "Pitchers" {
                    rpText = "RP"
                    spText = "SP"
                } else {
                    rpText = ""
                    spText = ""
                }
            }
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.3)
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
        }
    }
    func addPlayers() {
        let  player = Player(name: "", number: "",  position: "", batDir: "", batOrder: 99,team: team)
        modelContext.insert(player)
        navigationPath.append(player)
        try? modelContext.save()
    }
}
