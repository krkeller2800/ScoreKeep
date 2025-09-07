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
    @Binding var columnVisability:NavigationSplitViewVisibility
    @State private var path = NavigationPath()
    @State private var addAGame: Bool = false
    @State private var isSearching: Bool = false
    @State var doGame = "Edit"
    @State var title = "Edit a Game"
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Game.date, order: .reverse)]
    @AppStorage("selectedGameCriteria") var selectedSortCriteria: SortCriteria = .dateAsc
    var compileDate:Date
    {
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
           let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
           let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date
        { return infoDate }
        return Date()
    }
    
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
             GameView(searchString: searchText, sortOrder: sortDescriptor, title:$title, navigationPath: $path, columnVisability: $columnVisability)
                .navigationDestination(for: Game.self) { game in
                    if addAGame || game.date == "" || game.hteam?.name ?? "" == "" || game.hteam?.name ?? "" == "" || doGame == "Edit" {
                        EditGameView(game: game, navigationPath: $path)
                    } else {
                        EditScoreView(pgame: game, pnavigationPath: $path, ateam: game.vteam?.name ?? "", columnVisability: $columnVisability)
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
                    ToolbarItem(placement: .topBarTrailing) {
                        let options = ["Score","Edit"]
                        Picker("Select Option", selection: $doGame) {
                            ForEach(options, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
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
                    ToolbarItem(placement: .bottomBar) {
                        if UIDevice.type == "iPad" || (UIDevice.type == "iPhone" && doGame == "Edit") {
                            Text("This app was compiled on " + compileDate.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundColor(.gray).italic()
                        }
                    }
            }
            .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "YYYY-MM-DD or any text")
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.3)
                if doGame == "Score" {
                    columnVisability = .detailOnly
                } else {
                    columnVisability = .doubleColumn
                }
            }
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .onChange(of: doGame) {
                title = "\(doGame) a Game"
                if doGame == "Score" {
                    columnVisability = .detailOnly
                } else {
                    columnVisability = .doubleColumn
                }
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $path, team: team)
            }
            .onChange(of: isSearching) {
                if isSearching == false {
                    searchText = "" // Clear the search text when the search field is dismissed
                }
            }
        }
    }
    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        addAGame = true
        print(addAGame)
        try? modelContext.save()
    }
}


