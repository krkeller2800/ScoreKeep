//
//  PlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//

import SwiftData
import SwiftUI

struct PlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var pTeam: Team
    @State private var playerNavigationPath = NavigationPath()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSearching = false
    @State private var showingAddPlayerDraft = false
    @Binding private var searchText: String
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]

    @AppStorage("selectedPlayerTCriteria") var selectedPlayerPCriteria: SortCriteria = .orderAsc

    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }

    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPlayerPCriteria {
        case .nameAsc:
            return [SortDescriptor(\Player.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Player.name, order: .reverse)]
        case .orderAsc:
            return [SortDescriptor(\Player.batOrder, order: .forward)]
        case .numAsc:
            return [SortDescriptor(\Player.number, order: .forward)]
        }
    }

    @Query private var players: [Player]

    var body: some View {
        NavigationStack(path: $playerNavigationPath) {
            GeometryReader { geometry in
                Form {
                    let nameWidth = geometry.size.width / 4
                    let smallWidth = geometry.size.width / 13
                    let mediumWidth = geometry.size.width / 10
                    Section {
                        HStack {
                            scorebookHeaderCell("Name")
                                .frame(width: nameWidth)
                            scorebookHeaderCell("Num")
                                .frame(width: smallWidth)
                            scorebookHeaderCell("Pos")
                                .frame(width: smallWidth)
                            scorebookHeaderCell("Dir")
                                .frame(width: smallWidth)
                            scorebookHeaderCell("Order")
                                .frame(width: mediumWidth)
                            Text("").frame(width: 45)
                        }

                        ForEach(players) { player in
                            NavigationLink(value: player) {
                                HStack {
                                    Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                        .scorebookTrailingSeparator().padding(.leading, 5)
                                    Text(player.number).frame(width: smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                        .scorebookTrailingSeparator()
                                    Text(player.position).frame(width: smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                        .scorebookTrailingSeparator()
                                    Text(player.batDir).frame(width: smallWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                        .scorebookTrailingSeparator()
                                    Text(Double(player.batOrder), format: .number.rounded(increment: 1.0))
                                        .frame(width: mediumWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                                        .scorebookTrailingSeparator()
                                    Text("")
                                        .frame(width: 25)
                                }
                            }
                        }
                        .onDelete(perform: deletePlayer)
                    } header: {
                        if players.count > 0 {
                            Text("Select a Player to edit").frame(maxWidth: .infinity, alignment: .leading).font(UIDevice.type == "iPhone" ? .callout : .title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $selectedPlayerPCriteria) {
                                ForEach(SortCriteria.allCases) { criteria in
                                    if criteria == .nameAsc {
                                        Text("Name (A-Z)").tag(criteria)
                                    } else if criteria == .nameDec {
                                        Text("Name (Z-A)").tag(criteria)
                                    } else if criteria == .numAsc {
                                        Text("Number (A-Z)").tag(criteria)
                                    } else if criteria == .orderAsc {
                                        Text("order (A-Z)").tag(criteria)
                                    }
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("\(pTeam.name) Players")
                            .font(.title2)
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showingAddPlayerDraft = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add player")

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
                .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
                .onAppear {
                    if UIDevice.type == "iPhone" {
                       isSearching = false
                    } else {
                        isSearching = true
                    }
                }
                .onChange(of: isSearching) {
                    if isSearching == false {
                        searchText = ""
                    }
                }
                .onChange(of: sortDescriptor) {
                    sortOrder = sortDescriptor
                }
                .navigationDestination(for: Player.self) { player in
                    EditPlayerView(player: player, team: pTeam, navigationPath: $playerNavigationPath)
                }
                .sheet(isPresented: $showingAddPlayerDraft) {
                    NavigationStack {
                        AddPlayerDraftView(team: pTeam)
                    }
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
            .scrollContentBackground(.hidden)
            .background(ScoreKeepVisualStyle.background)
        }
    }

    init(team: Team, navigationPath: Binding<NavigationPath>, searchString: Binding<String>, sortOrder: [SortDescriptor<Player>] = []) {
        self.pTeam = team
        _searchText = searchString
        let teamName = team.name
        let search = searchString.wrappedValue
        _players = Query(filter: #Predicate { player in
            if search.isEmpty {
                player.team?.name == teamName
            } else {
                player.team?.name == teamName &&
                (player.name.localizedStandardContains(search) || player.number.localizedStandardContains(search))
            }
        }, sort: sortDescriptor)
    }

    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = players[offset]
            if playedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) is associated with game(s). Cannot delete."
            } else if pitchedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) has pitched in a game. Cannot delete."
            } else {
                modelContext.delete(player)
            }
        }
    }

    func playedInGame(player: Player) -> Bool {
        var exist = false
        let pName = player.name

        if !pName.isEmpty {
            var fetchDescriptor = FetchDescriptor<Atbat>()
            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existAtbats = try self.modelContext.fetch(fetchDescriptor)
                exist = existAtbats.first != nil
            } catch {
                print("SwiftData Error fetching Atbats: \(error)")
            }
        }
        return exist
    }

    func pitchedInGame(player: Player) -> Bool {
        var exist = false
        let pName = player.name

        if !pName.isEmpty {
            var fetchDescriptor = FetchDescriptor<Pitcher>()
            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existPitcher = try self.modelContext.fetch(fetchDescriptor)
                exist = existPitcher.first != nil
            } catch {
                print("SwiftData Error fetching Games: \(error)")
            }
        }
        return exist
    }
}
