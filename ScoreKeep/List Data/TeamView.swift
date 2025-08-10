//
//  TeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/22/25.
//

import SwiftUI
import SwiftData
import Foundation
@MainActor
struct TeamView: View {
    @Environment(\.modelContext) var modelContext
    
    @State private var alertMessage = "kk"
    @State private var showingAlert: Bool = false
    @State private var teamName = ""
    @State private var prevTName = ""
    @State private var dups = false
    @State private var checkForDups = true
    @State var coachName: String = ""
    @State var teamInfo: String = ""
    
    enum FocusField: Hashable {case field}

    @FocusState private var focusedField: FocusField?

    @Query var teams: [Team]
    var body: some View {
        Form {
            if teams.count > 0 {
                Text("Select a Team to edit or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title2).foregroundColor(.black).bold()
            }
            HStack {
                Text("Team").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold()
                    .background(.yellow.opacity(0.3))
                Text("coach").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red)
                    .background(.yellow.opacity(0.3))
                Text("Team Info").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red)
                    .background(.yellow.opacity(0.3))
                Spacer(minLength: 30)
            }
            HStack {
                TextField("Name", text: $teamName, onEditingChanged: { (editingChanged) in
                    if !editingChanged {
                        checkForDup()
                    }})
                    .frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                    .focused($focusedField, equals: .field)
                    .onChange(of: focusedField) { checkForDup()}
//                    .onAppear {self.focusedField = .field}
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                TextField("Coach", text: $coachName).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                TextField("Details", text: $teamInfo).frame(maxWidth:.infinity).foregroundColor(.blue).bold()
                    .overlay(Divider().background(.black), alignment: .trailing)
                HStack {
                    Image(systemName: "plus")
                      .onTapGesture {
                        if !dups {
                            let theTeam = Team(name:teamName, coach:coachName, details:teamInfo)
                            modelContext.insert(theTeam)
                            teamName = ""; coachName = ""; teamInfo = ""
                            try? self.modelContext.save()
                        } else {
                            alertMessage = "Team named \(teamName) already exists"
                            showingAlert = true
                        }
                    }
                }
                .accentColor(.black).background(.blue.opacity(0.2)).cornerRadius(20).padding(.leading,5)
            }
            ForEach(teams) { team in
                NavigationLink(value: team) {
                    HStack {
                        HStack {
                            if let imageData = team.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .scaleImage(iHeight: 30, imageData: imageData)
                            }
                            Text(team.name).lineLimit(2).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                        
                        Text(team.coach).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).lineLimit(2).minimumScaleFactor(0.5)
                        Text(team.details).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).lineLimit(2).minimumScaleFactor(0.5)
                        Spacer(minLength: 15)
                    }
                }
            }
            .onDelete(perform: deleteTeam)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Teams")
                    .font(.title2)
            }
        }
        .listRowSeparator(.hidden)
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Team>] = []) {
        
        _teams = Query(filter: #Predicate { team in
            if searchString.isEmpty {
                true
            } else {
                team.name.localizedStandardContains(searchString)
            }
        },  sort: sortOrder)
    }
    
    func deleteTeam (at offsets: IndexSet) {
        for offset in offsets {
            let team = teams[offset]
            if teamOnGame(team:team) {
                showingAlert = true
                alertMessage = "\(team.name) is associated with game(s). Cannot delete."
            } else if playersOnTeam(team:team) {
                showingAlert = true
                alertMessage = "\(team.name) has players on it. Cannot delete."
            } else {
                modelContext.delete(team)
            }
        }
    }
    func playersOnTeam(team:Team)->Bool {
        

        var exist = false
        let tName = team.name

        if !tName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == tName }
            
            do {
                let existPlayers = try self.modelContext.fetch(fetchDescriptor)
                if existPlayers.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Players: \(error)")
            }
        }
        return exist
    }

    func teamOnGame(team:Team)->Bool {
        
        var exist = false
        let tName = team.name

        if !tName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Game>()
            
            fetchDescriptor.predicate = #Predicate { $0.hteam?.name == tName || $0.hteam?.name == tName }
            
            do {
                let existGames = try self.modelContext.fetch(fetchDescriptor)
                if existGames.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Games: \(error)")
            }
        }
        return exist
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
}



