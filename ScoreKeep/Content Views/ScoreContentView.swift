//
//  ScoreGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/26/25.
//

import SwiftUI
import SwiftData

struct ScoreContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()
    @State private var addAGame: Bool = false
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Game.date, order: .reverse)]
    @AppStorage("selectedGameCriteria") var selectedSortCriteria: SortCriteria = .dateAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case dateAsc, dateDec, homeTeam, visitorTeam
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Game>] {
        switch selectedSortCriteria {
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
            GameView(searchString: searchText, sortOrder: sortDescriptor, title:"Score a Game", navigationPath: $path)
                .navigationDestination(for: Game.self) { game in
                    if addAGame || game.date == "" || game.hteam?.name ?? "" == "" || game.hteam?.name ?? "" == "" {
                        EditGameView(game: game, navigationPath: $path)
                    } else {
                        EditScoreView(pgame: game, pnavigationPath: $path, ateam: game.vteam?.name ?? "")
                    }
                }
                .onAppear() {
                    addAGame = false
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $selectedSortCriteria) {
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

            }
            .searchable(text: $searchText, prompt: "YYYY-MM-DD or any text")
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $path, team: team)
            }

        }
    }
    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        addAGame = true
        print(addAGame)
    }
}


#Preview {
    do {
        let previewer = try Previewer()
        return ContentView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
