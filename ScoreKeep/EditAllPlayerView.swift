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
                    Text("Player Name").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Player Number").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Player Position").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Place in Order").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Player Team").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                }
                .background {Color.yellow.opacity(0.3)}
                HStack {
                    TextField("Player", text: $player.name).background(Color.white).frame(maxWidth:.infinity)
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
                    TextField("Batting Order", value: $player.batOrder, formatter: formatter).background(Color.white).frame(maxWidth:.infinity)
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
        
    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }

}
