//
//  EditScoreView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/26/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct EditScoreView: View {
    @Environment(\.modelContext) var modelContext
    @State var game: Game
    @Binding var navigationPath: NavigationPath
    @State var team: Team = Team(name: "", coach: "", details: "")
    @State var isHomeTeam: Bool = true
    @State var theTeam: String = ""
    @State var latbats: [Atbat] = []
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var sortAtbat = [SortDescriptor(\Atbat.col), SortDescriptor(\Atbat.seq)]
    @State var showingDetail = false
    @State var presentRpt = false
    enum FocusField: Hashable {case field}
    
    @State private var presentReplacements = false
    @State private var visitSelected = true
    @State private var homeSelected = false
    @State private var showAlert = false
    @State private var showReport = false
    @State private var shareReport = false
    @State private var alertText = ""
    @State private var pdfURL:URL = URL.documentsDirectory.appending(path: "Stats.pdf")
    @State private var screenHeight = 0.0
    @State private var screenWidth = 0.0

    @FocusState private var focusedField: FocusField?
    
    @State var date = Date.now
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text(game.location).font(.title3)
                    Spacer()
                    VStack (spacing: 5) {
                        Text("Select which team to score!").font(.headline)
                        HStack {
                            SelectButton(isSelected: $visitSelected, color:.blue, text:game.vteam?.name ?? "")
                                .onTapGesture {
                                    visitSelected.toggle()
                                    isHomeTeam.toggle()
                                    
                                    AudioServicesPlaySystemSound(1052)
                                    if visitSelected {
                                        homeSelected = false
                                    } else {
                                        homeSelected = true
                                    }
                                }
                            Text(" at ")
                            SelectButton(isSelected: $homeSelected, color:.blue, text:game.hteam?.name ?? "")
                                .onTapGesture {
                                    homeSelected.toggle()
                                    isHomeTeam.toggle()
                                    
                                    AudioServicesPlaySystemSound(1052)
                                    if homeSelected {
                                        visitSelected = false
                                    } else {
                                        visitSelected = true
                                    }
                                }
                        }
                    }
                    .onAppear {
                        team = game.vteam ?? Team(name:"",coach:"",details:"")
                        theTeam = game.vteam!.name
                        print(modelContext.sqliteCommand)
                        
                    }
                    .onChange(of: isHomeTeam, {
                        if !isHomeTeam {
                            theTeam = game.hteam?.name ?? ""
                            team = game.hteam ?? Team(name:"",coach:"",details:"")
                        } else {
                            theTeam = game.vteam?.name ?? ""
                            team = game.vteam ?? Team(name:"",coach:"",details:"")
                        }
                    })
                    .lineLimit(1).minimumScaleFactor(0.3)
                    .font(.largeTitle).italic(true)
                    Spacer ()
                    let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                    Text(date.formatted(date:.numeric, time: .shortened)).font(.title3)
                }
                .frame(maxWidth:.infinity,maxHeight: 75)
                .overlay(drawBoxScore(game:game), alignment: .topTrailing)
                Spacer()
                PlayersToScoreView(passedGame: $game, teamName: theTeam, searchString: "", sortOrder: sortAtbat, theAtbats: $latbats)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        presentReplacements.toggle()
                    }) {
                        Text("Replacement/Pinch Players")
                    }
                    .fullScreenCover(isPresented: $presentReplacements) {
                        ReplacementView(game: game, team: team)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        self.showingDetail.toggle()
                    }) {
                        if !isHomeTeam {
                            Text("\(game.hteam!.name) Lineup")
                        } else {
                            Text("\(game.vteam!.name) Lineup")
                        }
                    }
                    .onChange(of: showingDetail, {
                        if !isHomeTeam {
                            team = game.hteam ?? Team(name:"",coach:"",details:"")
                            theTeam = game.hteam?.name ?? ""
                        } else {
                            team = game.vteam ?? Team(name:"",coach:"",details:"")
                            theTeam = game.vteam?.name ?? ""
                        }
                    })
                    .sheet(isPresented: $showingDetail) {
                        PlayersLineupView(showingDetail: $showingDetail, passedGame: game, passedTeam: team, theTeam: theTeam, searchString: searchText, sortOrder: sortOrder)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Score the Game")
                        .font(.title2)
//                        .frame(width:300, alignment: .leading)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    
                // Give a moment for the screen boundaries to change after
                // the device is rotated
                Task { @MainActor in
                    try await Task.sleep(for: .seconds(0.1))
                    withAnimation {
                        screenHeight = UIScreen.main.bounds.height
                        screenWidth = UIScreen.main.bounds.width
                    }
                }
            }
//            let bpos:CGFloat = UIScreen.screenWidth > 1300 ? 1250 : UIScreen.screenWidth > 1100 ? 1075 : 900
            let bpos:CGFloat = screenWidth == 0 ? UIScreen.screenWidth * 0.9 : screenWidth * 0.9
            Button("Show Stats", action: {
                showReport.toggle()
            })
            .foregroundColor(.white).bold().padding().frame(maxHeight: 35)
            .background(Color.blue).cornerRadius(25)
            .position(x: bpos, y: 0)
            .fullScreenCover(isPresented: $showReport) {
                ShowReportView(teamName: team.name)
            }
        }
        
    }
    init(pgame: Game, pnavigationPath: Binding<NavigationPath>, ateam: String) {
        game = pgame
        _navigationPath = pnavigationPath
    }
}
extension ModelContext {
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
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
