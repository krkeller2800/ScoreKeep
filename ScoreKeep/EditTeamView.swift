//
//  EditTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//

import SwiftUI
import SwiftData

struct EditTeamView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var navigationPath: NavigationPath
    @Bindable var team: Team
//    enum FocusField: Hashable {case field}
//    
//    @FocusState private var focusedField: FocusField?
    @FocusState private var nameIsFocused: Bool

    @State private var AddPlayers: Bool = true
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Player.name)]
    
    var body: some View {
        Form {
            HStack {
                Text("Team Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Coach Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Team Notes").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
            }
            HStack {
                //                TextField("team", text: $team.name).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                //                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                //                    .focused($focusedField, equals: .field)
                //                    .onAppear {self.focusedField = .field}
                TextField("team", text: $team.name).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                    .focused($nameIsFocused)
                Spacer()
                TextField("Coach", text: $team.coach).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                Spacer()
                TextField("Details", text: $team.details).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                Spacer()
            }
        }
        .frame(maxWidth:.infinity, maxHeight: 150, alignment: .top)

        Section() {
            VStack( ) {
                PlayersOnTeamView(teamName: team.name, searchString: searchText, sortOrder: sortOrder)
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView( player: player, team: team, navigationPath: $navigationPath).navigationTitle(Text("Update Player"))
                    }
                    .border(Color.gray)
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
                        }
                    }
                    .searchable(text: $searchText)
            }
            Spacer()
            Button("Add Player",  action: addPlayers).font(.title).background(Color.white)
        }
    }

    func addPlayers() {
        nameIsFocused = false
        if AddPlayers {
            for i in 1...10 {
                let player = Player(name: "Player \(i)", number: "\(i * 3)", position: "1b", batOrder: (CGFloat(i)), team: team)
                modelContext.insert(player)
            }
        } else {
            let  player = Player(name: "", number: "", position: "", batOrder: 99, team: team)
            modelContext.insert(player)
            navigationPath.append(player)
        }
        try? modelContext.save()
    }
}



