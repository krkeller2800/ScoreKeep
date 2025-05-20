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
//                .navigationTitle(Text("Add or Edit the Players"))
                .navigationDestination(for: Player.self) { player in
                    EditAllPlayerView(player: player, navigationPath: $navigationPath)
//                        .navigationTitle(Text("Update the Player"))

                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name (A-Z)")
                                    .tag([SortDescriptor(\Player.name)])
                                
                                Text("Name (Z-A)")
                                    .tag([SortDescriptor(\Player.name, order: .reverse)])
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
