//
//  EditPlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//
import PhotosUI
import SwiftUI
import SwiftData

struct EditPlayerView: View {
    @Environment(\.modelContext) var modelContext
    @State private var selectedItem: PhotosPickerItem?
    @Bindable var player: Player
    @Bindable var team: Team
    @Binding var navigationPath: NavigationPath
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var playerName = ""
    @State private var prevPName = ""
    @State private var dups = false
    @State private var checkForDups = true

    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    var formatter: NumberFormatter {
        let formatter = NumberFormatter ()
        formatter.minimumIntegerDigits = 0
        formatter.maximumFractionDigits = 3
        
        return formatter
    }
    var body: some View {
        Form {
            VStack {
                HStack {
                    Text("Name").frame(width:150).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Number").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Position").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Bat Dir").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Bat Order").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Team").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                }
                .background {Color.yellow.opacity(0.3)}
                HStack {
                    TextField("Player", text: $playerName, onEditingChanged: { (editingChanged) in
                        if !editingChanged {
                            checkForDup(pname: playerName)
                        }})
                        .background(Color.white).frame(width: 150)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        .focused($focusedField, equals: .field)
                        .onChange(of: focusedField) { checkForDup(pname: playerName)}
                        .onAppear {self.focusedField = .field}
                        .autocapitalization(.words)
                        .textContentType(.none)
                        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    Spacer()
                    TextField("Number", text: $player.number).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                    Spacer()
                    TextField("Pos", text: $player.position).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                    Spacer()
                    TextField("Bat Dir", text: $player.batDir).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                    Spacer()
                    Picker("Bat Order", selection: $player.batOrder) {
                        let orders = ["None","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15th","16th","17th","18th","19th"]
                        ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                            Text(order).tag(index)
                        }
                        Text("Not Hitting").tag(99)
                    }
                    .frame(maxWidth:.infinity).labelsHidden().pickerStyle(.menu).accentColor(.blue)

                    Spacer()
                    Picker("Player Team", selection: $player.team) {
                        Text("Unknown Team").tag(Optional<Team>.none)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams) { nteam in
                                if nteam.name != "" {
                                    Text(nteam.name).tag(Optional(nteam))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .labelsHidden().pickerStyle(.menu).accentColor(.blue)
                    Spacer()
                }

            }
            HStack {
                Spacer()
                if let imageData = player.photo, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(maxWidth: 400, maxHeight: 400, alignment: .center)
                        .scaledToFit()
                        .cornerRadius(25)
                }
                Spacer()
            }
            Text("\n\n")
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select a photo", systemImage: "person")
                }
                .onChange(of: selectedItem, loadPhoto)
                .onDisappear() {
                    if dups || playerName.isEmpty {
                        modelContext.delete(player)
                    } else {
                        player.name = playerName
                    }
                }
                .onAppear() {
                    playerName = player.name
                    prevPName = player.name
                    if !playerName.isEmpty {
                        checkForDups = false
                    }

                }
                Spacer()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Update a Player")
                    .font(.title2)
            }
        }

    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }
    func checkForDup(pname:String) {
        
        if prevPName == pname {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let teamName = team.name
        let playName = pname
        prevPName = playName
        
        if !teamName.isEmpty && !playName.isEmpty && checkForDups{
            
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName && $0.name == playName}
            
            do {
                let existPlayers = try self.modelContext.fetch(fetchDescriptor)
                
                if existPlayers.first != nil {
                    dups = true
                    showingAlert = true
                    alertMessage = "\(pname) is already on the team."
                } else {
                    dups = false
                }
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            if teamName.isEmpty && !playerName.isEmpty {
                showingAlert = true
                alertMessage = "Please select a team so we can check if \(pname) is on already on it."
            }
        }
    }
}

