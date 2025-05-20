//
//  PlayersOnTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/22/25.
//
import SwiftUI
import SwiftData

struct PlayersOnTeamView: View {
    @Environment(\.modelContext) var modelContext
    @Query var players: [Player]
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Name")
                        .frame(width:175).border(.gray).foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Number")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Pos")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Bat Dir")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Order")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text(" Team")
                        .frame(maxWidth:.infinity).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer(minLength: 35)
                }
                ForEach(players) { player in
                    NavigationLink(value: player) {
                        HStack {
                            Text(player.name).frame(width: 175, alignment: .leading).foregroundColor(.black).bold().lineLimit(1).minimumScaleFactor(0.5)
                                .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                            Spacer()
                            Text(player.number).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(player.position).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(player.batDir).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(player.team?.name ?? "").frame(maxWidth: .infinity, alignment: .center).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                            Spacer()
                        }
                    }
                }
                .onDelete(perform: deletePlayer)
            }
            header: {
                Text("Select a Player or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title2).foregroundColor(.black).bold()
                }
        }
    }
    
    init(teamName: String, searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        _players = Query(filter: #Predicate { player in
            if searchString.isEmpty {
                player.team?.name == teamName
            } else {
                player.team?.name == teamName &&
                (player.name.localizedStandardContains(searchString)
                || player.number.localizedStandardContains(searchString))
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
