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
    @State private var isSearching = false
    @State private var sortOrder = [SortDescriptor(\Player.name)]
    @AppStorage("selectedPlayerCriteria") var selectedPlayerCriteria: SortCriteria = .teamOrderAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc, teamOrderAsc
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPlayerCriteria {
        case .nameAsc:
            return [SortDescriptor(\Player.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Player.name, order: .reverse)]
        case .orderAsc:
            return [SortDescriptor(\Player.batOrder, order: .forward)]
        case .numAsc:
            return [SortDescriptor(\Player.number, order: .forward)]
        case .teamOrderAsc:
            return [SortDescriptor(\Player.team?.name, order: .forward), SortDescriptor(\Player.batOrder, order: .forward)]
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
//            PlayerView(team: <#Team#>, searchString: searchText, sortOrder: sortDescriptor, navigationPath: $navigationPath)
//                .navigationDestination(for: Player.self) { player in
//                    EditAllPlayerView(player: player, navigationPath: $navigationPath)
//                }
            VStack {
                
            }
                 .toolbar {
                     ToolbarItemGroup(placement: .topBarLeading) {
                         Menu("Sort", systemImage: "arrow.up.arrow.down") {
                             Picker("Sort", selection: $selectedPlayerCriteria) {
                                 ForEach(SortCriteria.allCases) { criteria in
                                     if criteria == .nameAsc {
                                         Text("Name (A-Z)").tag(criteria)
                                     } else if criteria == .nameDec {
                                         Text("Name (Z-A)").tag(criteria)
                                     } else if criteria == .numAsc {
                                         Text("Number (A-Z)").tag(criteria)
                                     } else if criteria == .orderAsc {
                                         Text("order (A-Z)").tag(criteria)
                                     } else if criteria == .teamOrderAsc {
                                         Text("Team then order (A-Z)").tag(criteria)
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
                 .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name")
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
    func addPlayers() {
        let  player = Player(name: "", number: "",  position: "", batDir: "", batOrder: 99)
        modelContext.insert(player)
        navigationPath.append(player)
        try? modelContext.save()
    }
}
