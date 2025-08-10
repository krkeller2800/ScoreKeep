//
//  ContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import SwiftUI
import SwiftData
@Query var games: [Game]

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()
    
    @State var title = "Games"
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var sortOrder = [SortDescriptor(\Game.date, order: .reverse)]
    @AppStorage("selectedGameCriteria") var selectedGameCriteria: SortCriteria = .dateAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case dateAsc, dateDec, homeTeam, visitorTeam
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Game>] {
        switch selectedGameCriteria {
        case .dateAsc:
            return [SortDescriptor(\Game.date, order: .forward)]
        case .dateDec:
            return [SortDescriptor(\Game.date, order: .reverse)]
        case .homeTeam:
            return [SortDescriptor(\Game.hteam!.name, order: .forward)]
        case .visitorTeam:
            return [SortDescriptor(\Game.vteam!.name, order: .forward)]
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            GameView(searchString: searchText, sortOrder: sortDescriptor, title:$title, navigationPath: $path)
                .navigationDestination(for: Game.self) { game in
                    EditGameView(game: game, navigationPath: $path)
            }
            .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "YYYY-MM-DD or any text")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $selectedGameCriteria) {
                            ForEach(SortCriteria.allCases) { criteria in
                                if criteria == .dateAsc {
                                    Text("Date (A-Z)").tag(criteria)
                                } else if criteria == .dateDec {
                                    Text("Date (Z-A)").tag(criteria)
                                } else if criteria == .homeTeam {
                                    Text("Home Team (A-Z)").tag(criteria)
                                } else if criteria == .visitorTeam {
                                    Text("Visitor Team (A-Z)").tag(criteria)
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add a team") {
                        let team = Team(name: "", coach: "", details: "")
                        modelContext.insert(team)
                        try? modelContext.save()
                        path.append(team)
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
            .onChange(of: isSearching) {
                if isSearching == false {
                    searchText = "" // Clear the search text when the search field is dismissed
                }
            }
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $path, team: team)
            }
            .onAppear {
                if UIDevice.type == "iPhone" {
                   isSearching = false
                } else {
                    isSearching = true
                }
            }
        }
    }
    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        try? modelContext.save()
    }
}


