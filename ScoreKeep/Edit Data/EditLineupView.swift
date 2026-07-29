//
//  EditLineupView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/31/25.
//
import PhotosUI
import SwiftUI
import SwiftData

struct EditLineupView: View {
    @Environment(\.modelContext) var modelContext
    @State private var selectedItem: PhotosPickerItem?
    @Bindable var player: Player
    @Bindable var team: Team
    @Binding var addPlayer: Bool
    
    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    var formatter: NumberFormatter {
        let formatter = NumberFormatter ()
        formatter.minimumIntegerDigits = 0
        formatter.maximumFractionDigits = 0
        
        return formatter
    }
    var body: some View {
        VStack {
            Text("").frame(height: 10)
            HStack {
                Spacer(minLength: 10)
                Button("Back to Lineup") {
                    self.addPlayer.toggle()
                }
                .frame(maxWidth: .infinity, alignment:.leading)
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select a photo", systemImage: "person")
                }
                .frame(maxWidth: .infinity, alignment:.trailing)
                .onChange(of: selectedItem, loadPhoto)
                Spacer(minLength: 10)
            }
            Text("").frame(height: 5)
            HStack {
                scorebookHeaderCell("Name")
                    .frame(maxWidth:.infinity)
                scorebookHeaderCell("Number")
                    .frame(maxWidth:.infinity)
                scorebookHeaderCell("Position")
                    .frame(maxWidth:.infinity)
                scorebookHeaderCell("Bat Direction")
                    .frame(maxWidth:.infinity)
                scorebookHeaderCell("Order")
                    .frame(maxWidth:.infinity)
                scorebookHeaderCell("Team")
                    .frame(maxWidth:.infinity)
            }
            HStack {
                TextField("Player", text: $player.name, prompt: scorebookInputPrompt("Player")).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                    .focused($focusedField, equals: .field)
                    .onAppear {self.focusedField = .field}
                    .autocapitalization(.words)
                    .textContentType(.none)
                TextField("Number", text: $player.number, prompt: scorebookInputPrompt("Number")).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                TextField("Position", text: $player.position, prompt: scorebookInputPrompt("Position")).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                TextField("Bat Direction", text: $player.batDir, prompt: scorebookInputPrompt("Bat Direction")).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                TextField("Batting Order", value: $player.batOrder, formatter: formatter)
                    .frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).scorebookInputField().bold()
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
            }
            HStack {
                if let imageData = player.photo, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(maxWidth: 250, maxHeight: 250, alignment: .center)
                        .scaledToFit()
                        .cornerRadius(25)
                }
            }
        }
    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }
}
