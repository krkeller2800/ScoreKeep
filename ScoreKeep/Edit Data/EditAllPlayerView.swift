//
//  EditAllPlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/26/25.
//

import PhotosUI
import SwiftUI
import SwiftData

struct EditAllPlayerView: View {
    @Environment(\.modelContext) var modelContext
    @State private var selectedItem: PhotosPickerItem?
    @Bindable var player: Player
    @Binding var navigationPath: NavigationPath
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
                    Text("Name").frame(width: 150).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Number").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Pos").frame(maxWidth:.infinity).border(.gray)
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
                    TextField("Player", text: $player.name).background(Color.white).frame(width: 150)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        .focused($focusedField, equals: .field)
                        .onAppear {self.focusedField = .field}
                        .autocapitalization(.words)
                        .textContentType(.name)
                    Spacer()
                    TextField("Number", text: $player.number).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                    Spacer()
                    TextField("Position", text: $player.position).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        .autocapitalization(.none)
                        .textContentType(.none)
                    Spacer()
                    TextField("Bat Direction", text: $player.batDir).background(Color.white).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).foregroundColor(.blue).bold()
                        .autocapitalization(.none)
                        .textContentType(.none)
                    Spacer()
                    Picker("Bat Order", selection: $player.batOrder) {
                        let orders = ["None","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15th","16th","17th","18th","19th"]
                        ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                            Text(order).tag(index)
                        }
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
                Spacer()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit a Player")
                    .font(.title2)
            }
        }
    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }

}
