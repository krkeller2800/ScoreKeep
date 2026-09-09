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
struct TeamNavigationDestination: Hashable {
    let teamIdentity: UUID
}

struct TeamNavigationDestinationView: View {
    @Binding var navigationPath: NavigationPath
    @Query private var teams: [Team]

    init(destination: TeamNavigationDestination, navigationPath: Binding<NavigationPath>) {
        _navigationPath = navigationPath
        let teamIdentity = destination.teamIdentity
        _teams = Query(filter: #Predicate<Team> { team in
            team.ident == teamIdentity
        })
    }

    var body: some View {
        if let team = teams.first {
            EditTeamView(navigationPath: $navigationPath, team: team)
                .navigationDestination(for: TeamDefaultBattingOrderNavigationDestination.self) { destination in
                    TeamDefaultBattingOrderDestinationView(destination: destination, navigationPath: $navigationPath)
                }
        } else {
            Text("Team not found")
        }
    }
}

@MainActor
struct TeamView: View {
    @Environment(\.modelContext) var modelContext
    
    @State private var alertMessage = "kk"
    @State private var showingAlert: Bool = false

    @Query var teams: [Team]
    var body: some View {
        Form {
            if teams.count > 0 {
                Text("Select a Team to edit or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title2).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
            }

            HStack {
                scorebookHeaderCell("Team")
                    .frame(maxWidth: .infinity)
                scorebookHeaderCell("coach")
                    .frame(maxWidth: .infinity)
                scorebookHeaderCell("Team Info")
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 30)
            }

            ForEach(teams) { team in
                NavigationLink(value: TeamNavigationDestination(teamIdentity: team.ident)) {
                    HStack {
                        HStack {
                            if let imageData = team.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .scaleImage(iHeight: 30, imageData: imageData)
                            }
                            Text(team.name).lineLimit(2).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                        .scorebookTrailingSeparator().padding(.leading, 5)
                        
                        Text(team.coach).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                            .scorebookTrailingSeparator().lineLimit(2).minimumScaleFactor(0.5)
                        Text(team.details).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                            .scorebookTrailingSeparator().lineLimit(2).minimumScaleFactor(0.5)
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
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
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
            } else {
                delPlayersOnTeam(team:team)
                modelContext.delete(team)
                try? self.modelContext.save()
            }
        }
    }
    func delPlayersOnTeam(team:Team) {
        

        let tName = team.name

        if !tName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == tName }
            
            do {
                let existPlayers = try self.modelContext.fetch(fetchDescriptor)
                if existPlayers.first != nil {
                    for player in existPlayers {
                        self.modelContext.delete(player)
                    }
                    try? self.modelContext.save()
                }
            } catch {
                print("SwiftData Error fetching and deleting \(tName)'s Players: \(error)")
            }
        }
    }

    func teamOnGame(team:Team)->Bool {
        
        var exist = false
        let tName = team.name

        if !tName.isEmpty {
            
            var fetchDescriptor = FetchDescriptor<Game>()
            
            fetchDescriptor.predicate = #Predicate { $0.hteam?.name == tName || $0.vteam?.name == tName }
            
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
}
