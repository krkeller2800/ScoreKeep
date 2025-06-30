//
//  EditGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//
import SwiftUI
import SwiftData

struct EditGameView: View {
    @Environment(\.modelContext) var modelContext
    @Bindable var game: Game
    @Binding var navigationPath: NavigationPath
    @State var date = Date.now
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var addingTeam = false

    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    var formatter: NumberFormatter {
        let formatter = NumberFormatter ()
        formatter.minimumIntegerDigits = 0
        formatter.maximumIntegerDigits = 1

        return formatter
    }
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    
    var body: some View {
        Form {
            HStack{
                Text("Select Game Date").frame(width: 200, alignment: .center).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("Field").frame(maxWidth: .infinity, alignment: .center).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("All Hit").frame(maxWidth: .infinity, alignment: .center).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
//                Text("Innings").frame(maxWidth: .infinity, alignment: .center).border(.gray)
//                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
//                Spacer()
                Text("Visiting").frame(maxWidth: .infinity, alignment: .center).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Text("Home").frame(maxWidth: .infinity, alignment: .center).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
            }
            HStack{
                DatePicker("", selection: $date)
                    .onAppear {
                        date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                    }
                    .onChange(of: date) {
                        game.date = date.ISO8601Format()
                    }
                    .labelsHidden().overlay(Divider().background(.black), alignment: .trailing)
                    .frame(width: 200, height: 30, alignment: .center)
                    .clipped()
                TextField("Field", text: $game.location)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                    .focused($focusedField, equals: .field)
//                    .onAppear {self.focusedField = .field}
                    .autocapitalization(.words)
                    .textContentType(.none)
                Button(action:{game.everyOneHits.toggle()}){
                    Text(game.everyOneHits ? "True" : "False")
                        .frame(maxWidth:.infinity,maxHeight:30)
                        .foregroundColor(.blue).bold()
                        .background(Color.white)
                }.buttonStyle(PlainButtonStyle())
                .cornerRadius(10)
                .overlay(Divider().background(.black), alignment: .trailing)
                Picker("Visiting Team", selection: $game.vteam) {
                    Text("Unknown Team").tag(Optional<Team>.none)
                    if teams.isEmpty == false {
                        Divider()
                        ForEach(teams) { team in
                            if team.name != "" {
                                Text(team.name).tag(Optional(team))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                .overlay(Divider().background(.black), alignment: .trailing)
                Picker("Home Team", selection: $game.hteam) {
                    Text("Unknown Team").tag(Optional<Team>.none)
                    if teams.isEmpty == false {
                        Divider()
                        ForEach(teams) { team in
                            if team.name != "" {
                                Text(team.name).tag(Optional(team))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                .overlay(Divider().background(.black), alignment: .trailing)
            }
            .onDisappear() {
                if (game.hteam == nil || game.vteam == nil) && !addingTeam {
                    modelContext.delete(game)
                    alertMessage = "You must select a Home and Visiting Team! Game deleted."
                    showingAlert = true
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
            HStack {
            }
            Text("Highlights").frame(width: 600, alignment: .center).foregroundColor(.black).font(.title)
            TextField("Comment", text: $game.highLights, prompt: Text("Please input game highlights"), axis: .vertical)
                    .padding()
                    .background(.green.opacity(0.2))
                    .cornerRadius(5.0)
                    .frame(width:600)
                    .foregroundColor(.blue).bold()
        }
//        .navigationDestination(for: Team.self) { team in
//            EditTeamView(navigationPath: $navigationPath, team: team)
//            }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add home or visiting team", action: addTeam)
            }
            ToolbarItem(placement: .principal) {
                Text("Games")
                    .font(.title2)
            }

        }
    }
    func addTeam() {
        addingTeam = true
        let team = Team(name: "", coach: "", details: "")
        modelContext.insert(team)
        navigationPath.append(team)
    }
}
#Preview {
    do {
        let previewer = try Previewer()

        return EditGameView(game: previewer.game, navigationPath: .constant(NavigationPath()))
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
