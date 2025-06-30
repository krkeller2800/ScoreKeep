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
    @State private var alertMessage = "kk"
    @State private var showingAlert: Bool = false
    @State private var teamName = ""
    @State private var prevTName = ""
    @State private var dups = false
    @State private var checkForDups = true
    @AppStorage("selectedPlayerTCriteria") var selectedPlayerTCriteria: SortCriteria = .orderAsc
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPlayerTCriteria {
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

    var body: some View {
        Form {
            HStack {
                Text("Logo").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("Coach Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("Notes").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
            }
            HStack {
                if let imageData = team.logo, let uiImage = UIImage(data: imageData) {
                    HStack {
                        Image(uiImage: uiImage)
                            .scaleImage(iHeight: 50, imageData: imageData)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(maxWidth: 50, maxHeight: 50, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75, alignment: .center)
                    .overlay(Divider().background(.black), alignment: .trailing)
                } else {
                    Text("")
                        .frame(maxWidth: .infinity, maxHeight: 75, alignment: .center)
                        .overlay(Divider().background(.black), alignment: .trailing)
                }
                TextField("team", text: $teamName, onEditingChanged: { (editingChanged) in
                    if !editingChanged {
                        checkForDup()
                    }})
                    .frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                    .focused($focusedField, equals: .field)
                    .onChange(of: focusedField) { checkForDup()}
//                    .onAppear {self.focusedField = .field}
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                TextField("Coach", text: $team.coach).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                TextField("Details", text: $team.details).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
            }
            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Select a logo")
                }
                .onChange(of: selectedItem, loadLogo).frame(maxWidth:.infinity,alignment:.center)
                Text("").frame(maxWidth:.infinity)
                Text("").frame(maxWidth:.infinity)
                Text("").frame(maxWidth:.infinity)
            }
        }
        .frame(maxWidth:.infinity, maxHeight: 175, alignment: .top)

        Section() {
            VStack( ) {
                PlayersOnTeamView(team: team, searchString: searchText, sortOrder: sortDescriptor)
                    .navigationDestination(for: Player.self) { player in
                        EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
                    }
                    .border(Color.gray)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                                Picker("Sort", selection: $selectedPlayerTCriteria) {
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
                            Text("\(team.name)")
                                .font(.title2)
                            }
                    }
                    .searchable(text: $searchText, prompt: "Player name or number")
                    .onChange(of: sortDescriptor) {
                        sortOrder = sortDescriptor
                    }

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



