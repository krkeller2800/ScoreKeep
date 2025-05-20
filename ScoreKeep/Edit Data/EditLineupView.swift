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
                .frame(maxWidth: .infinity, alignment:.leading).background(Color.white)
                Spacer()
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select a photo", systemImage: "person")
                }
                .frame(maxWidth: .infinity, alignment:.trailing).background(Color.white)
                .onChange(of: selectedItem, loadPhoto)
                Spacer(minLength: 10)
            }
            Text("").frame(height: 5)
            HStack {
                Text("Name").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Number").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Position").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Bat Direction").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Order").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Team").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
            }
            .background {Color.yellow.opacity(0.3)}
            HStack {
                TextField("Player", text: $player.name).background(Color.white).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                    .focused($focusedField, equals: .field)
                    .onAppear {self.focusedField = .field}
                Spacer()
                TextField("Number", text: $player.number).background(Color.white).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                Spacer()
                TextField("Position", text: $player.position).background(Color.white).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                Spacer()
                TextField("Bat Direction", text: $player.batDir).background(Color.white).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                Spacer()
                TextField("Batting Order", value: $player.batOrder, formatter: formatter)
                    .background(Color.white).frame(maxWidth:.infinity)
                    .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .labelsHidden().pickerStyle(.menu).accentColor(.blue)
                Spacer()
            }
            HStack {
                Spacer()
                if let imageData = player.photo, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(maxWidth: 250, maxHeight: 250, alignment: .center)
                        .scaledToFit()
                        .cornerRadius(25)
                }
                Spacer()
            }
            Spacer()
        }
    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }
}
