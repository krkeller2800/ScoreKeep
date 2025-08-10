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
    @Binding var navigationPath: NavigationPath
    @Binding private var title: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var deleteIndexSet: IndexSet?
    @State private var date: Date = Date()
    @State private var theDate:  String = ""
    @State private var field: String = ""
    @State private var everyOneHits = false
    @State private var vTeam: Team?
    @State private var hTeam: Team?

    enum FocusField: Hashable {case field}
    
    @FocusState private var focusedField: FocusField?
    
    let com = Common()
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    @Query var games: [Game]
    var body: some View {
        Form {
            if games.count > 0 {
                if self.title == "Edit a Game" {
                    Text("Select a Game to edit or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title3).foregroundColor(.black).bold()
                } else if self.title == "Score a Game"{
                    Text("Select a Game to score or swipe to delete").frame(maxWidth:.infinity, alignment:.leading).font(.title3).foregroundColor(.black).bold()
                }
            }
            HStack {
                Text("Game Date").frame(width: UIDevice.type == "iPhone" && title.isEmpty ? 105 : 225).border(.gray)
                    .foregroundColor(.red).bold().background(.yellow.opacity(0.3))
                if !title.isEmpty {
                    Text("Field").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                    Text("All Hit").frame(maxWidth:60).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                }
     
                Text("Visiting").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                Text("Home").frame(maxWidth:.infinity).border(.gray)
                    .foregroundColor(.red).background(.yellow.opacity(0.3))
                if !title.isEmpty {
                    Text("Score").frame(maxWidth:.infinity).border(.gray)
                        .foregroundColor(.red).background(.yellow.opacity(0.3))
                }
                Text("").frame(maxWidth:40)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            if !title.isEmpty {
                HStack{
                    DatePicker("", selection: $date)
                        .onAppear {
                            date = ISO8601DateFormatter().date(from: theDate) ?? Date()
                        }
                        .onChange(of: date) {
                            theDate = date.ISO8601Format()
                        }
                        .labelsHidden().overlay(Divider().background(.black), alignment: .trailing)
                        .frame(width: 205, alignment: .leading)
                        .clipped()
                    TextField("Field", text: $field)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue).bold()
                        .overlay(Divider().background(.black), alignment: .trailing)
                        .focused($focusedField, equals: .field)
                    //                    .onAppear {self.focusedField = .field}
                        .autocapitalization(.words)
                        .textContentType(.none)
                    Button(action:{everyOneHits.toggle()}){
                        Text(everyOneHits ? "True" : "False")
                            .frame(maxWidth:60,maxHeight:30)
                            .foregroundColor(.blue).bold()
                            .background(Color.white)
                    }.buttonStyle(PlainButtonStyle())
                        .cornerRadius(10)
                        .overlay(Divider().background(.black), alignment: .trailing)
                    Picker("Visiting Team", selection: $vTeam) {
                        Text("Pick").tag(Optional<Team>.none)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams) { team in
                                if team.name != "" {
                                    Text(team.name).tag(Optional(team))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                    .overlay(Divider().background(.black), alignment: .trailing)
                    Picker("Home Team", selection: $hTeam) {
                        Text("Pick").tag(Optional<Team>.none)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams) { team in
                                if team.name != "" {
                                    Text(team.name).tag(Optional(team))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center).labelsHidden().pickerStyle(.menu).accentColor(.blue)
                    .overlay(Divider().background(.black), alignment: .trailing)
                    Text("Not Played Yet")
                        .frame(maxWidth: .infinity)
                        .overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                    HStack {
                        Image(systemName: "plus")
                            .onTapGesture {
                                if vTeam != nil && hTeam != nil {
                                    let theGame = Game(date: theDate, location: field, highLights: "", hscore: 0, vscore: 0, everyOneHits: everyOneHits, vteam:vTeam!, hteam:hTeam!)
                                    modelContext.insert(theGame)
                                    try? self.modelContext.save()
                                    field = ""; hTeam = nil; vTeam = nil; everyOneHits = false
                                } else {
                                    alertMessage = "You must select a Home and Visiting Team!"
                                    showingAlert = true
                                }
                            }
                    }
                }
            }
            ForEach(games) { game in
                NavigationLink(value: game) {
                    HStack {
                        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                        Text(date.formatted(date:.abbreviated, time: .shortened)).frame(width:UIDevice.type == "iPhone" && title.isEmpty ? 100 : 220, alignment: .center).foregroundColor(.black).bold().padding(.trailing,5).lineLimit(2).minimumScaleFactor(0.5)
                            .overlay(Divider().background(.black), alignment: .trailing)
                        if !title.isEmpty {
                            Text(game.location).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                            Text(game.everyOneHits ? "True" : "False").frame(maxWidth:60, alignment: .center).foregroundColor(.black).bold()
                                .padding(.leading, 0).overlay(Divider().background(.black), alignment: .trailing).lineLimit(1).minimumScaleFactor(0.5)
                        }
                        HStack {
                            if let imageData = game.vteam?.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .scaleImage(iHeight: 30, imageData: imageData)
                            }
                            Text(game.vteam?.name ?? "").lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing)
                        HStack {
                            if let imageData = game.hteam?.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .scaleImage(iHeight: 30, imageData: imageData)
                            }
                            Text(game.hteam?.name ?? "").lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.black).bold()
                        .overlay(Divider().background(.black), alignment: .trailing)
                        if !title.isEmpty {
                            let hruns = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.hteam!.name}).count
                            let vruns = game.atbats.filter({$0.maxbase == "Home" && $0.team.name == game.vteam!.name}).count
                            let outs = game.atbats.filter({$0.team.name == game.vteam!.name && (com.outresults.contains($0.result) || $0.outAt != "Safe" )}).count
                            let inning = (outs / 3) + 1
                            let score:String = "\(vruns) to \(hruns)"
                            let winner:String = vruns > hruns ? (game.vteam?.name ?? " ") : vruns < hruns ? (game.hteam?.name ?? "") : "No winner yet"
                            let fin = inning > 9 && winner != "No winner yet" ? " Final" : ""
                            let win = winner + (fin != "" ? fin : " in the \(com.innAbr[inning])")
                            Text(score + " " + win ).frame(maxWidth:.infinity, alignment: .leading).foregroundColor(.black).bold()
                                .overlay(Divider().background(.black), alignment: .trailing).lineLimit(2).minimumScaleFactor(0.5)
                        }
                        Spacer(minLength: 20)
                    }
                }
            }
            .onDelete(perform: { indexSet in
                self.showingAlert = true
                self.deleteIndexSet = indexSet
            })
            .alert(isPresented:$showingAlert) {
                Alert(
                    title: Text("Deleting a Game"),
                    message: Text("If a game is deleted all asssociated at bats and pitches will also be deleted and removed from the stats"),
                    primaryButton: .destructive(Text("Delete")) {
                        let indexSet = self.deleteIndexSet!
                        for index in indexSet {
                            let game = games[index]
                            for atbat in game.atbats {
                                modelContext.delete(atbat)
                            }
                            for pitcher in game.pitchers {
                                modelContext.delete(pitcher)
                            }
                            for lineup in game.lineups {
                                modelContext.delete(lineup)
                            }
                        }
                        deleteGame(at: indexSet)
                        print("Deleting...")
                    },
                    secondaryButton: .cancel()
                )
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(self.title)
                    .font(.title2)
                }
        }
        .listRowSeparator(.hidden)
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Game>] = [],title:Binding<String>, navigationPath: Binding<NavigationPath>) {
        
        _title = title
        _navigationPath = navigationPath
        
        _games = Query(filter: #Predicate { game in
            if !searchString.isEmpty {
                return game.hteam?.name.localizedStandardContains(searchString) ?? false ||
                       game.vteam?.name.localizedStandardContains(searchString) ?? false ||
                       game.location.localizedStandardContains(searchString) ||
                       game.date.localizedStandardContains(searchString)
            } else {
                return true
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
