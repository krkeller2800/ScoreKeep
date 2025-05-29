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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                PitchersStaffView(searchString: searchText, sortOrder: sortOrder, passedGame: game, passedTeam: team, theTeam: team.name)
                    .navigationDestination(for: Player.self) { player in
                        EditAllPlayerView(player: player, navigationPath: $navigationPath)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Name (A-Z)")
                                .tag([SortDescriptor(\Player.name)])
                            
                            Text("Name (Z-A)")
                                .tag([SortDescriptor(\Player.name, order: .reverse)])
                            Text("Number (1-99)")
                                .tag([SortDescriptor(\Player.number)])
                        }
                    }
                    Button("Add Player", systemImage: "plus", action: addPlayers)
                }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("< Back") {
                            dismiss()
                        }
                    }
            }
            .searchable(text: $searchText)
        }
    }
    func addPlayers() {
        let  player = Player(name: "", number: "",  position: "", batDir: "", batOrder: 99)
        modelContext.insert(player)
        navigationPath.append(player)
    }
}
