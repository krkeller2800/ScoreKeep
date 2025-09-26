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
    @Binding var columnVisibility:NavigationSplitViewVisibility
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
    @State private var showPitchRpt = false
    @State private var shareReport = false
    @State private var isLoading = false
    @State private var isError = false
    @State private var alertText = ""
    @State private var teamName = ""
    @State private var selectedOption = ""
    @State private var pdfURL:URL = URL.documentsDirectory.appending(path: "Stats.pdf")
    @State private var screenHeight = 0.0
    @State private var screenWidth = 0.0
    @State private var preferenceValue: String = ""
    @State var screenshotMaker: ScreenshotMaker?
    @State var doShot = false
    @State var hasChanged = false
    @State var url:URL?

    @FocusState private var focusedField: FocusField?
    
    @State var date = Date.now
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        VStack{
                         if game.location.count < 15 {
                                Text(game.location).font(.title3).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                            } else {
                                Text("")
                                let firstWord = game.location.split(separator: " ").count > 0 ? game.location.split(separator: " ")[0] : ""
                                let secondWord = game.location.split(separator: " ").count > 1 ? game.location.split(separator: " ")[1] : ""
                                Text(firstWord).font(.title3).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                                Text(secondWord).font(.title3).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                            }
                        }
                        Spacer()
                        VStack (spacing: 5) {
                            Text("Select which team to score!").font(.headline).frame(maxWidth: .infinity,alignment: .center)
                            HStack {
                                ForEach([game.vteam?.name ?? "", game.hteam?.name ?? ""], id: \.self) { option in
                                    Button(action: {
                                        selectedOption = option
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
                            .frame(width: 500).lineLimit(1).minimumScaleFactor(0.3).font(.largeTitle).italic(true)
                        }
                        .onAppear {
                            if !isHomeTeam {
                                team = game.vteam ?? Team(name:"",coach:"",details:"")
                                theTeam = game.vteam?.name ?? ""
                                selectedOption = game.vteam?.name ?? ""
                            }
                            print(modelContext.sqliteCommand)
                            print(NSHomeDirectory())
                            
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
                        .alert(alertText, isPresented: $isError) {
                            Button("OK", role: .cancel) { }
                        }
                        Spacer ()
                        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                        VStack {
                            Text(date.formatted(date:.abbreviated, time: .omitted)).font(.title3).frame(maxWidth: .infinity,alignment: .trailing).padding(.trailing, 5)
                                .lineLimit(1).minimumScaleFactor(0.60)
                            Text(date.formatted(date:.omitted, time: .shortened)).font(.title3).frame(maxWidth: .infinity,alignment: .trailing).padding(.trailing, 5)
                                .lineLimit(1).minimumScaleFactor(0.60)
                        }
                    }
                    .frame(maxWidth:.infinity,maxHeight: 75)
                    Spacer()
                    PlayersToScoreView(passedGame: $game, teamName: theTeam, searchString: "", sortOrder: sortAtbat, theAtbats: $latbats, isLoading: $isLoading, hasChanged: $hasChanged,columnVisability: $columnVisibility)
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
                .onChange(of: doShot) {
                    if doShot {
                        if let screenshotMaker = screenshotMaker {
                            url = saveImage(uiimage: screenshotMaker.screenshot()!)
                            doShot.toggle()
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button(action: {
                            showPitchers.toggle()
                        }) {
                            Text("Add Pitcher")
                        }
                        .frame(width: 120)
                        .buttonStyle(ToolBarButtonStyle())
                        .fullScreenCover(isPresented: $showPitchers) {
                            let opTeam = team == game.hteam ? game.vteam! : game.hteam!
                            PitcherContentView(team: opTeam, game: game)
                        }
                        Button {
                            let generatePDF = PDFGenerator()
                            url = generatePDF.generatePDFData(game: game, team: team, title: "Test PDF", body: "This is a test")
                        } label: {
                            Text("PDF")
                        }
                        .frame(width: 40)
                        .buttonStyle(ToolBarButtonStyle())
                        if let pdfURL = url {
                            ShareLink("Share", item: pdfURL)
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(action: {
                            presentReplacements.toggle()
                        }) {
                            Text("Replace Players")
                        }
                        .frame(width: 140)
                        .buttonStyle(ToolBarButtonStyle())
                        .fullScreenCover(isPresented: $presentReplacements) {
                            ReplacementView(game: game, team: team)
                        }
                        Button(action: {
                            self.showingDetail.toggle()
                        }) {
                            Text("Lineup")
                        }
                        .buttonStyle(ToolBarButtonStyle())
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: {
                            showPitchRpt.toggle()
                            isLoading = true
                        }) {
                            Text("Pitch Stats")
                        }
                        .frame(width: 100)
                        .buttonStyle(ToolBarButtonStyle())
                        .fullScreenCover(isPresented: $showPitchRpt) {
                            if UIDevice.type == "iPad" {
                                ShowPitchRptView(tName: team.name, isLoading: $isLoading)
                            } else {
                                PitcherRptView(teamName: team.name, isLoading: $isLoading)
                            }
                        }
                        Spacer()
                        Button(action: {
                            showReport.toggle()
                            isLoading = true
                        }) {
                            Text("Hit Stats")
                        }
                        .frame(width: 100)
                        .buttonStyle(ToolBarButtonStyle())
                        .fullScreenCover(isPresented: $showReport) {
                            if UIDevice.type == "iPad" {
                                ReportView(teamName: team.name, isLoading: $isLoading)
                            } else {
                                ShowReportView(tName: team.name, isLoading: $isLoading)
                            }
                        }
                    }
 
                    ToolbarItem(placement: .principal) {
                        Text("Score the Game")
                            .font(.title2)
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
                            columnVisibility = .detailOnly
                        }
                    }
                }
                if isLoading {
                    LoadingView()
                        .position(x: geometry.size.width / 2, y: -25)
                }
            }
            .screenshotMaker { screenshotMaker in
                     self.screenshotMaker = screenshotMaker
                 }
        }
     
    }
    init(pgame: Game, pnavigationPath: Binding<NavigationPath>, ateam: String, columnVisability: Binding<NavigationSplitViewVisibility>) {
        game = pgame
        teamName = ateam
        _navigationPath = pnavigationPath
        _columnVisibility = columnVisability
    }
    func saveImage(uiimage: UIImage?)-> URL? {
        
        guard let data = uiimage?.jpegData(compressionQuality: 0.8) else {
            print("Could not convert UIImage to Data.")
            alertText = "Could not save image"
            isError = true
            isLoading = false
               return nil
        }
        
        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = url.appendingPathComponent("\(theTeam) on \(date.formatted( date: .abbreviated, time: .omitted)).jpg")
        
        do {
            try data.write(to: fileURL)
            print("Image saved successfully to: \(fileURL.path)")
            isLoading = false
            return fileURL
        } catch {
            print("Error saving image: \(error.localizedDescription)")
            alertText = "Could not save image"
            isError = true
            isLoading = false
        }
        return nil
    }
}
