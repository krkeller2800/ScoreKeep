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
    @Query var teams: [Team]
    var body: some View {
        Form {
            HStack {
                Text("Team Name").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold()
                    .background(.yellow.opacity(0.3))
                Spacer()
                Text("Team coach").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red)
                    .background(.yellow.opacity(0.3))
                Spacer()
                Text("Team Info").frame(maxWidth:.infinity).border(.gray).foregroundColor(.red)
                    .background(.yellow.opacity(0.3))
                Spacer(minLength: 35)
            }
            ForEach(teams) { team in
                NavigationLink(value: team) {
                    HStack {
                        HStack {
                            if let imageData = team.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
                            } else {
                                Text("").frame(width: 30, height: 30).background(.clear)
                            }
                            Text(team.name)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                        Spacer()
                        Text(team.coach).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                        Text(team.details).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
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
            modelContext.delete(team)
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return TeamView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
