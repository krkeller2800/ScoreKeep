//
//  PlayerContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/25/25.
//

import SwiftUI
import SwiftData

struct PlayerContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var navigationPath = NavigationPath()

    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Player.name)]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PlayerView(searchString: searchText, sortOrder: sortOrder)
                .navigationDestination(for: Player.self) { player in
                    EditAllPlayerView(player: player, navigationPath: $navigationPath)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button("< Back") {
                            dismiss()
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
                                Text("Team then Order (1-99)")
                                    .tag([SortDescriptor(\Player.team?.name),SortDescriptor(\Player.batOrder)])
                            }
                        }
                        Button("Add Player", systemImage: "plus", action: addPlayers)
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
