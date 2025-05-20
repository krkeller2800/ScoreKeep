//
//  PlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    @Environment(\.modelContext) var modelContext
    @Query var players: [Player]
    
    var body: some View {
        Form {
            HStack {
                Text("Name")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                Spacer()
                Text("Number")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Position")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Bat Direction")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Batting Order")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Team")
                    .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer(minLength: 35)
            }
            ForEach(players) { player in
                NavigationLink(value: player) {
                    HStack {
                        Text(player.name).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                        Spacer()
                        Text(player.number).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                        Text(player.position).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                        Text(player.batDir).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                        Text(Double(player.batOrder), format: .number.rounded(increment: 1.0))
                            .frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                       Spacer()
                        Text(player.team?.name ?? "").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                    }
                }
            }
            .onDelete(perform: deletePlayer)
        }
        .toolbar {
             ToolbarItem(placement: .principal) {
                 Text("Edit/Add a Player")
                     .font(.title2)
             }
         }
    }
    
    init(searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        _players = Query(filter: #Predicate { player in
            if searchString.isEmpty {
                true
            } else {
                player.name.localizedStandardContains(searchString)
                || player.number.localizedStandardContains(searchString)
            }
        },  sort: sortOrder)
    }
    
    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = players[offset]
            modelContext.delete(player)
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return PlayerView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
