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
            HStack(spacing: 0) {
                scorebookHeaderCell("Select Game Date")
                    .frame(width: 200)
                scorebookHeaderCell("Field")
                    .frame(maxWidth: .infinity)
                scorebookHeaderCell("All Hit")
                    .frame(maxWidth: .infinity)
                scorebookHeaderCell("Visiting")
                    .frame(maxWidth: .infinity)
                scorebookHeaderCell("Home")
                    .frame(maxWidth: .infinity)
            }

            HStack{
                DatePicker("", selection: $date)
                    .onAppear {
                        date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                    }
                    .onChange(of: date) {
                        game.date = date.ISO8601Format()
                    }
                    .labelsHidden().scorebookTrailingSeparator()
                    .frame(width: 200, height: 30, alignment: .center)

                    .clipped()
                TextField("Field", text: $game.location, prompt: scorebookInputPrompt("Field"))
                    .frame(maxWidth: .infinity)
                    .scorebookInputField().bold()
                    .scorebookTrailingSeparator()
                    .focused($focusedField, equals: .field)

//                    .onAppear {self.focusedField = .field}
                    .autocapitalization(.words)
                    .textContentType(.none)
                Button(action:{game.everyOneHits.toggle()}){
                    Text(game.everyOneHits ? "True" : "False")
                        .frame(maxWidth:.infinity,maxHeight:30)
                        .foregroundStyle(ScoreKeepVisualStyle.accent).bold()
                }.buttonStyle(PlainButtonStyle())
                .cornerRadius(10)
                .scorebookTrailingSeparator()

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
                .frame(maxWidth: .infinity, alignment: .leading).labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
                .scorebookTrailingSeparator()

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
                .frame(maxWidth: .infinity, alignment: .leading).labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
                .scorebookTrailingSeparator()

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
            Text("Highlights").frame(width: 600, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).font(.title)
            TextField("Comment", text: $game.highLights, prompt: scorebookInputPrompt("Please input game highlights"), axis: .vertical)
                    .padding()
                    .background(ScoreKeepVisualStyle.selectedFill)
                    .cornerRadius(5.0)
                    .frame(width:600)
                    .scorebookInputField().bold()
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
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
        try? modelContext.save()
    }
}
