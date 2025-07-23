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
                PitchersStaffView(searchString: searchText, sortOrder: sortDescriptor, passedGame: game, passedTeam: team, theTeam: team.name)
                    .navigationDestination(for: Player.self) { player in
//                        EditAllPlayerView(player: player, navigationPath: $navigationPath)
                        EditPlayerView(player: player, team: team, navigationPath: $navigationPath)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("< Back") {
                        dismiss()
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

            }
            .searchable(text: $searchText, prompt: "Player name")
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
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
