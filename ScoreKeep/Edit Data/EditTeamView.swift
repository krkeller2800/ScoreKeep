//
//  EditTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//
import PhotosUI
import SwiftUI
import SwiftData

struct EditTeamView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var navigationPath: NavigationPath
    @Bindable var team: Team
    @State private var selectedItem: PhotosPickerItem?
    enum FocusField: Hashable {case field}

    @FocusState private var focusedField: FocusField?

    @State private var AddPlayers: Bool = false
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var alertMessage = ""
    @State private var showingAlert: Bool = false
    @State private var teamName = ""
    @State private var prevTName = ""
    @State private var dups = false
    @State private var checkForDups = true

    
    var body: some View {
        Form {
            HStack {
                Text("Logo").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Coach Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Notes").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
            }
            HStack {
                if let imageData = team.logo, let uiImage = UIImage(data: imageData) {
                    HStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 50, maxHeight: 50, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75, alignment: .center)
                    .overlay(Divider().background(.black), alignment: .trailing)
                } else {
                    Text("")
                        .frame(maxWidth: .infinity, maxHeight: 75, alignment: .center)
                        .overlay(Divider().background(.black), alignment: .trailing)
                }
                Spacer()
                TextField("team", text: $teamName, onEditingChanged: { (editingChanged) in
                    if !editingChanged {
                        checkForDup()
                    }})
                    .frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                    .focused($focusedField, equals: .field)
                    .onChange(of: focusedField) { checkForDup()}
                    .onAppear {self.focusedField = .field}
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                Spacer()
                TextField("Coach", text: $team.coach).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                Spacer()
                TextField("Details", text: $team.details).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                Spacer()
            }
            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Select a logo")
                }
                .onChange(of: selectedItem, loadLogo).frame(maxWidth:.infinity,alignment:.center)
                Spacer()
                Text("").frame(maxWidth:.infinity)
                Spacer()
                Text("").frame(maxWidth:.infinity)
                Spacer()
                Text("").frame(maxWidth:.infinity)
                Spacer()
            }
        }
        .frame(maxWidth:.infinity, maxHeight: 175, alignment: .top)

        Section() {
            VStack( ) {
                PlayersOnTeamView(teamName: team.name, searchString: searchText, sortOrder: sortOrder)
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
                    }
                    .border(Color.gray)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                                Picker("Sort", selection: $sortOrder) {
                                    Text("Name (A-Z)")
                                        .tag([SortDescriptor(\Player.name)])
                                    
                                    Text("Name (Z-A)")
                                        .tag([SortDescriptor(\Player.name, order: .reverse)])
                                    Text("Battin Order (1-99)")
                                        .tag([SortDescriptor(\Player.batOrder)])
                                }
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            Text("Teams")
                                .font(.title2)
                            }
                    }
                    .searchable(text: $searchText)
            }
            .onDisappear() {
                if dups || teamName.isEmpty {
                   modelContext.delete(team)
                } else {
                    team.name = teamName
                }
            }
            .onAppear() {
                teamName = team.name
                prevTName = team.name
                if !teamName.isEmpty {
                    checkForDups = false
                }
            }
            Spacer()
            Button("Add Player",  action: addPlayers).font(.title).background(Color.white)
        }
    }

    func addPlayers() {
        if AddPlayers {
            for i in 1...10 {
                let player = Player(name: "Player \(i)", number: "\(i * 3)", position: "1b", batDir: "(L)", batOrder: (i), team: team)
                modelContext.insert(player)
            }
        } else {
            let  player = Player(name: "", number: "", position: "", batDir: "", batOrder: 99, team: team)
            modelContext.insert(player)
            navigationPath.append(player)
        }
    }
    func checkForDup() {
        
        if prevTName == teamName {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let tName = teamName
        prevTName = tName

        if !tName.isEmpty && checkForDups {
            
            var fetchDescriptor = FetchDescriptor<Team>()
            
            fetchDescriptor.predicate = #Predicate { $0.name == tName }
            
            do {
                let existTeams = try self.modelContext.fetch(fetchDescriptor)
                if existTeams.first != nil {
                    dups = true
                    showingAlert = true
                    alertMessage = "\(teamName) has already been created."
                } else {
                    dups = false
                }
            } catch {
                print("SwiftData Error: \(error)")
            }
        }
    }
    func loadLogo() {
        Task { @MainActor in
            team.logo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }

}



