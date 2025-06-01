//
//  TeamContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/22/25.
//

import SwiftUI
import SwiftData
@Query var teams: [Team]

struct TeamContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()

    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Team.name)]
    
    var body: some View {
        NavigationStack(path: $path) {
            TeamView(searchString: searchText, sortOrder: sortOrder)
                .navigationDestination(for: Team.self) { team in
                    EditTeamView(navigationPath: $path, team: team)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button("< Back") {
                            dismiss()
                        }
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name (A-Z)")
                                    .tag([SortDescriptor(\Team.name)])
                                
                                Text("Name (Z-A)")
                                    .tag([SortDescriptor(\Team.name, order: .reverse)])
                            }
                        }
                        Button("Add Team", systemImage: "plus", action: addTeam)
                    }
                }
                .searchable(text: $searchText)
        }
    }
    func addTeam() {
        let team = Team(name: "" ,coach: "",details: "")
        modelContext.insert(team)
        path.append(team)
    }
}
