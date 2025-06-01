//
//  ContentGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/31/25.
//

import SwiftUI
import SwiftData
@Query var allGames: [Game]

struct ContentGameView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()
    
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Game.date)]
    
    var body: some View {
//        NavigationStack(path: $path) {
            GameView(searchString: searchText, sortOrder: sortOrder,title:"Add/Edit or Delete a Game")
                .navigationDestination(for: Game.self) { game in
                    EditGameView(game: game, navigationPath: $path)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name (A-Z)")
                                    .tag([SortDescriptor(\Game.date)])
                                
                                Text("Name (Z-A)")
                                    .tag([SortDescriptor(\Game.date, order: .reverse)])
                            }
                        }
                        Button("Add Game", systemImage: "plus", action: addGame)
                    }
//                    ToolbarItem(placement: .topBarLeading) {
//                         Button("< Back") {
//                             dismiss()
//                         }
//                    }

                }
                .searchable(text: $searchText)
//        }
    }
    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
    }
}


#Preview {
    do {
        let previewer = try Previewer()
        return ContentGameView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
