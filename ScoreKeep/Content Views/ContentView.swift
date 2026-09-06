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
    @State var columnVisability = NavigationSplitViewVisibility.detailOnly
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
        case .homeTeam, .visitorTeam:
            return []
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            let currentSortMode: GameView.GameSort = {
                switch selectedGameCriteria {
                case .dateAsc:     return .dateAsc
                case .dateDec:     return .dateDec
                case .homeTeam:    return .homeTeam
                case .visitorTeam: return .visitorTeam
                }
            }()
            GameView(
                searchString: searchText,
                sortOrder: sortDescriptor,
                sortMode: currentSortMode,
                title: $title,
                navigationPath: $path,
                columnVisability: $columnVisability,
                createGame: { dateISO, field, everyOneHits, numInnings, vTeam, hTeam, isSeeded in
                    // This ContentView path represents normal user creation; treat as non-seeded.
                    createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, numInnings: numInnings, vTeam: vTeam, hTeam: hTeam)
                }
            )
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
                    Button("Add Team") {
                        path.append(AddTeamNavigationDestination())
                    }
                    .accessibilityLabel("Add Team")
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
            .navigationDestination(for: TeamNavigationDestination.self) { destination in
                TeamNavigationDestinationView(destination: destination, navigationPath: $path)
            }
            .navigationDestination(for: AddTeamNavigationDestination.self) { _ in
                AddTeamDraftView(dismissAfterCreation: false) { team in
                    path.removeLast()
                    path.append(TeamNavigationDestination(teamIdentity: team.ident))
                }
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

    private func createGame(dateISO: String, field: String, everyOneHits: Bool, numInnings: Int, vTeam: Team, hTeam: Team) {
        let theGame = Game(date: dateISO, location: field, highLights: "", hscore: 0, vscore: 0, everyOneHits: everyOneHits, numInnings: numInnings, vteam: vTeam, hteam: hTeam)
        modelContext.insert(theGame)
        try? modelContext.save()
        // If you want to navigate to EditGameView after creation, uncomment the next line:
        // path.append(theGame)
    }

    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        try? modelContext.save()
    }
}
