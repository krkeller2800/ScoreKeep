//
//  GameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//

import SwiftUI
import SwiftData
import Foundation
@MainActor
struct GameView: View {
    @Environment(\.modelContext) var modelContext
    @State private var title: String
    let com = Common()
    @Query var games: [Game]
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Game Date").frame(maxWidth: .infinity).border(.gray)
                        .foregroundColor(.red).bold().padding(.leading,0).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Visiting Team").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Home Team").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Field").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Every One Hits").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Num of Innings").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer()
                    Text("Final Score").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Spacer(minLength: 35)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                ForEach(games) { game in
                    NavigationLink(value: game) {
                        HStack {
                            let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                            Text(date.formatted(date:.abbreviated, time: .shortened)).frame(maxWidth: .infinity,maxHeight: 60, alignment: .leading).foregroundColor(.black).bold().padding(.trailing,5).lineLimit(2)
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(game.vteam?.name ?? "").frame(maxWidth:.infinity, alignment: .leading)
                                .foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(game.hteam?.name ?? "").frame(maxWidth:.infinity, alignment: .leading)
                                .foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(game.location).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text(game.everyOneHits ? "True" : "False").frame(maxWidth:.infinity, alignment: .center).foregroundColor(.black).bold()
                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                            Text("\(game.numInnings)").frame(maxWidth:.infinity, alignment: .center).foregroundColor(.black).bold()
                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing)

                            let hruns = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.hteam!.name}).count
                            let vruns = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.vteam!.name}).count
                            let outs = game.atbats.filter({$0.team.name == game.vteam!.name && (com.outresults.contains($0.result) || ($0.outAt != "Safe" && $0.outAt != "Not Out"))}).count
                            let inning = (outs / 3) + 1
                            let score:String = "\(vruns) to \(hruns)"
                            let winner:String = vruns > hruns ? (game.vteam?.name ?? " ") : vruns < hruns ? (game.hteam?.name ?? "") : "No winner yet"
                            let win = winner + " in the \(com.innAbr[inning])"
                            Spacer()
                            Text(score + " " + win ).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing)
                            Spacer()
                        }
                        
                    }
                }
                .onDelete(perform: deleteGame)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(self.title)
                        .font(.title)
                        .bold().frame(width:300, alignment: .leading)
                    }
            }
//            .navigationBarTitleDisplayMode(.inline)
        }
        .listRowSeparator(.hidden)
        
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Game>] = [],title:String) {
        
        self.title = title
        _games = Query(filter: #Predicate { game in
            if searchString.isEmpty {
                true
            } else {
                game.date.localizedStandardContains(searchString)
            }
        },  sort: sortOrder)
    }

    func deleteGame(at offsets: IndexSet) {
        for offset in offsets {
            let game = games[offset]
            modelContext.delete(game)
        }
    }
    

}
