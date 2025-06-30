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
    @State var isHomeTeam: Bool = false
    @State var theTeam: String = ""
    @State var latbats: [Atbat] = []
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var sortAtbat = [SortDescriptor(\Atbat.col), SortDescriptor(\Atbat.seq)]
    @State var showingDetail = false
    @State var presentRpt = false
    enum FocusField: Hashable {case field}
    
    @State private var presentReplacements = false
    @State private var showPitchers:Bool = false
    @State private var visitSelected = true
    @State private var homeSelected = false
    @State private var showAlert = false
    @State private var showReport = false
    @State private var shareReport = false
    @State private var isLoading = false
    @State private var alertText = ""
    @State private var selectedOption = ""
    @State private var pdfURL:URL = URL.documentsDirectory.appending(path: "Stats.pdf")
    @State private var screenHeight = 0.0
    @State private var screenWidth = 0.0

    @FocusState private var focusedField: FocusField?
    
    @State var date = Date.now
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Text(game.location).font(.title3).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                        Spacer()
                        VStack (spacing: 5) {
                            Text("Select which team to score!").font(.headline).frame(maxWidth: .infinity,alignment: .center)
                            HStack {
                                ForEach([game.vteam?.name ?? "", game.hteam?.name ?? ""], id: \.self) { option in
                                    Button(action: {
                                        selectedOption = option
                                        isLoading = true
                                        if option == game.vteam?.name ?? "" {
                                            isHomeTeam = false
                                        } else {
                                            isHomeTeam = true
                                        }
                                    }) {
                                        HStack {
                                            if game.vteam != nil && game.hteam != nil {
                                                let theTeam = option == game.vteam?.name ?? "" ? game.vteam! : game.hteam!
                                                if let imageData = theTeam.logo, let uiImage = UIImage(data: imageData) {
                                                    Image(uiImage: uiImage)
                                                        .scaleImage(iHeight: 30, imageData: imageData)
                                                }
                                                Text(option)
                                                    .lineLimit(1).minimumScaleFactor(0.5).foregroundColor(selectedOption == option ? Color.blue : Color.gray).bold().italic()
                                            }
                                        }
                                    }
                                    if option == game.vteam?.name ?? "" {
                                        Text(" at ").foregroundColor(.black)
                                    }
                                }
                            }
                            .frame(width: 500)
                        }
                        .onAppear {
                            team = game.vteam ?? Team(name:"",coach:"",details:"")
                            theTeam = game.vteam?.name ?? ""
                            selectedOption = game.vteam?.name ?? ""
                            print(modelContext.sqliteCommand)
                            
                        }
                        .onChange(of: isHomeTeam, {
                            if isHomeTeam {
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
                        Text(date.formatted(date:.abbreviated, time: .shortened)).font(.title3).frame(maxWidth: .infinity,alignment: .trailing).padding(.trailing, 5)
                    }
                    .frame(maxWidth:.infinity,maxHeight: 75)
                    .overlay(drawBoxScore(game:game), alignment: .topTrailing)
                    Spacer()
                    PlayersToScoreView(passedGame: $game, teamName: theTeam, searchString: "", sortOrder: sortAtbat, theAtbats: $latbats, isLoading: $isLoading)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            presentReplacements.toggle()
                        }) {
                            Text("Replace Players")
                        }
                        .fullScreenCover(isPresented: $presentReplacements) {
                            ReplacementView(game: game, team: team)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            showPitchers.toggle()
                        }) {
                            Text("Add a Pitcher")
                        }
                        .fullScreenCover(isPresented: $showPitchers) {
                            PitcherContentView(team: team, game: game)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            self.showingDetail.toggle()
                        }) {
                            if isHomeTeam {
                                Text("\(game.hteam?.name ?? "") Lineup")
                            } else {
                                Text("\(game.vteam?.name ?? "") Lineup")
                            }
                        }
                        .onChange(of: showingDetail, {
                            if isHomeTeam {
                                team = game.hteam ?? Team(name:"",coach:"",details:"")
                                theTeam = game.hteam?.name ?? ""
                            } else {
                                team = game.vteam ?? Team(name:"",coach:"",details:"")
                                theTeam = game.vteam?.name ?? ""
                            }
                        })
                        .fullScreenCover(isPresented: $showingDetail) {
                            StartingLineupView(showingDetail: $showingDetail, passedGame: game, passedTeam: team, theTeam: theTeam, searchString: searchText,sortOrder: sortOrder)
                        }
                        //                    .sheet(isPresented: $showingDetail) {
                        //                        StartingLineupView(showingDetail: $showingDetail, passedGame: game, passedTeam: team, theTeam: theTeam,sortOrder: sortOrder)
                        //                    }
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
                    isLoading = true
                })
                .foregroundColor(.white).bold().padding().frame(maxHeight: 35)
                .background(Color.blue).cornerRadius(25)
                .position(x: bpos, y: 0)
                .fullScreenCover(isPresented: $showReport) {
                    ShowReportView(tName: team.name, isLoading: $isLoading)
                }
                if isLoading {
                    LoadingView()
                        .position(x: geometry.size.width / 2, y: -25)
                }
            }
        }
    }
    init(pgame: Game, pnavigationPath: Binding<NavigationPath>, ateam: String) {
        game = pgame
        _navigationPath = pnavigationPath
    }
}

#Preview {
    do {
        let previewer = try Previewer()

        return EditScoreView(pgame: previewer.game, pnavigationPath: .constant(NavigationPath()), ateam: previewer.game.vteam?.name ?? "")
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
