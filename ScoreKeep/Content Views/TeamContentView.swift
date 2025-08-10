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

    @State private var isSearching = false
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Team.name)]
    @AppStorage("selectedTeamCriteria") var selectedTeamCriteria: SortCriteria = .nameAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Team>] {
        switch selectedTeamCriteria {
        case .nameAsc:
            return [SortDescriptor(\Team.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Team.name, order: .reverse)]
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TeamView(searchString: searchText, sortOrder: sortDescriptor)
                .navigationDestination(for: Team.self) { team in
                    EditTeamView(navigationPath: $path, team: team)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $selectedTeamCriteria) {
                                ForEach(SortCriteria.allCases) { criteria in
                                    if criteria == .nameAsc {
                                        Text("Name (A-Z)").tag(criteria)
                                    } else if criteria == .nameDec {
                                        Text("Name (Z-A)").tag(criteria)
                                    }
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Team Name")
                .onAppear {
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
                .onChange(of: sortDescriptor) {
                    sortOrder = sortDescriptor
                }

        }
    }
    func addTeam() {
        let team = Team(name: "" ,coach: "",details: "")
        modelContext.insert(team)
        path.append(team)
        try? modelContext.save()
    }
}
