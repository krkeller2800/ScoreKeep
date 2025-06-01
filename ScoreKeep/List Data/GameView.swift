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
        Form {
            HStack {
                Text("Game Date").frame(width: 100).border(.gray)
                    .foregroundColor(.red).bold().padding(.leading,0).background(.yellow.opacity(0.3))
                Spacer()
                Text("Visiting").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Home").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Field").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("All Hit").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Innings").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer()
                Text("Score").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Spacer(minLength: 35)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            ForEach(games) { game in
                NavigationLink(value: game) {
                    HStack {
                        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                        Text(date.formatted(date:.abbreviated, time: .shortened)).frame(width: 100, alignment: .leading).foregroundColor(.black).bold().padding(.trailing,5).lineLimit(2).minimumScaleFactor(0.5)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        Spacer()
                        HStack {
                            if let imageData = game.vteam?.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
                            } else {
                                Text("").frame(width: 30, height: 30).background(.clear)
                            }
                            Text(game.vteam?.name ?? "").lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
                        Spacer()
                        HStack {
                            if let imageData = game.hteam?.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
                            } else {
                                Text("").frame(width: 30, height: 30).background(.clear)
                            }
                            Text(game.hteam?.name ?? "").lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing).padding(.leading, 5)
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
                            .overlay(Divider().background(.black), alignment: .trailing).lineLimit(2).minimumScaleFactor(0.5)
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
                    .font(.title2)
                }
//            ToolbarItem(placement: .principal) {
//                Text("Edit/Add a Team")
//                    .font(.title2)
//            }
        }
        .listRowSeparator(.hidden)
        
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Game>] = [],title:String) {
        
        self.title = title
        _games = Query(filter: #Predicate { game in
            if searchString.isEmpty {
                (game.hteam != nil && game.vteam != nil) || title == "Add or Delete a Game"
            } else {
                ((game.hteam != nil && game.vteam != nil) || title == "Add or Delete a Game") &&
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
