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
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
    @SceneStorage("activeScoringTeamName") private var activeScoringTeamName: String?
    enum FocusField: Hashable {case field}

    @State private var presentReplacements = false
    @State private var showPitchers:Bool = false
    @State private var pendingPitcherSectionScrollRequest: LiveScoringShellPresentation.PitcherSectionScrollRequest?
    @State private var pitcherSectionScrollRequest: LiveScoringShellPresentation.PitcherSectionScrollRequest?
    @State private var visitSelected = true
    @State private var homeSelected = false
    @State private var showAlert = false
    @State private var showReport = false
    @State private var showPitchRpt = false
    @State private var shareReport = false
    @State private var showPaywall = false
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
    @State private var generatedOutputGateLifecycle = PurchaseGatedWorkflowLifecycle()
    private let purchaseDecisionAuthority = PurchaseDecisionAuthority()

    @FocusState private var focusedField: FocusField?

    @State var date = Date.now

    private var scorecardBottomToolbarClearance: CGFloat {
        12
    }

    private var pitchStatsButton: some View {
        Button(action: {
            requestGeneratedOutput(.pitchingStatistics)
        }) {
            Text("Pitch Stats")
        }
        .frame(width: 118)
        .buttonStyle(ToolBarButtonStyle())
        .fullScreenCover(isPresented: $showPitchRpt) {
            ShowPitchRptView(tName: team.name, isLoading: $isLoading)
        }
    }

    private var hitStatsButton: some View {
        Button(action: {
            requestGeneratedOutput(.hittingStatistics)
        }) {
            Text("Hit Stats")
        }
        .frame(width: UIDevice.type == "iPad" ? 100 : 112)
        .buttonStyle(ToolBarButtonStyle())
        .fullScreenCover(isPresented: $showReport) {
            ShowReportView(tName: team.name, isLoading: $isLoading)
        }
    }

    @ViewBuilder
    private var bottomStatsControls: some View {
        if UIDevice.type == "iPhone" {
            HStack {
                pitchStatsButton
                Spacer(minLength: 16)
                hitStatsButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        } else {
            iPadStatsControls
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iPadStatsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            hitStatsButton
            pitchStatsButton
        }
        .padding(.vertical, 2)
    }

    private var bottomStatsOverlayBottomPadding: CGFloat {
        UIDevice.type == "iPhone" && verticalSizeClass == .compact ? -32 : 4
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        VStack{
                         if game.location.count < 15 {
                                Text(game.location).font(.title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                            } else {
                                Text("")
                                let firstWord = game.location.split(separator: " ").count > 0 ? game.location.split(separator: " ")[0] : ""
                                let secondWord = game.location.split(separator: " ").count > 1 ? game.location.split(separator: " ")[1] : ""
                                Text(firstWord).font(.title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                                Text(secondWord).font(.title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .leading).padding(.leading, 5)
                            }
                        }
                        Spacer()
                        VStack (spacing: 5) {
                            Text("Select which team to score!").font(.headline).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .center)
                            HStack {
                                ForEach([game.vteam?.name ?? "", game.hteam?.name ?? ""], id: \.self) { option in
                                    Button(action: {
                                        selectedOption = option
                                        if option == game.vteam?.name ?? "" {
                                            isHomeTeam = false
                                        } else {
                                            isHomeTeam = true
                                        }
                                        activeScoringTeamName = option
                                    }) {
                                        HStack {
                                            if game.vteam != nil && game.hteam != nil {
                                                let theTeam = option == game.vteam?.name ?? "" ? game.vteam! : game.hteam!
                                                if let imageData = theTeam.logo, let uiImage = UIImage(data: imageData) {
                                                    Image(uiImage: uiImage)
                                                        .scaleImage(iHeight: 30, imageData: imageData)
                                                }
                                                Text(option)
                                                    .lineLimit(1).minimumScaleFactor(0.5).foregroundStyle(selectedOption == option ? ScoreKeepVisualStyle.accent : ScoreKeepVisualStyle.secondaryText).bold().italic()
                                            }
                                        }
                                    }
                                    if option == game.vteam?.name ?? "" {
                                        Text(" at ").foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                    }
                                }
                            }
                            .frame(width: 500).lineLimit(1).minimumScaleFactor(0.3).font(.largeTitle).italic(true)
                        }
                        .onAppear {
                            if let savedName = activeScoringTeamName, savedName == game.hteam?.name {
                                isHomeTeam = true
                                theTeam = game.hteam?.name ?? ""
                                team = game.hteam ?? Team(name:"",coach:"",details:"")
                                selectedOption = theTeam
                            } else if let savedName = activeScoringTeamName, savedName == game.vteam?.name {
                                isHomeTeam = false
                                theTeam = game.vteam?.name ?? ""
                                team = game.vteam ?? Team(name:"",coach:"",details:"")
                                selectedOption = theTeam
                            } else if !isHomeTeam {
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
                            activeScoringTeamName = theTeam
                        })
                        .alert(alertText, isPresented: $isError) {
                            Button("OK", role: .cancel) { }
                        }
                        Spacer ()
                        let date = ISO8601DateFormatter().date(from: game.date) ?? Date()
                        VStack {
                            Text(date.formatted(date:.abbreviated, time: .omitted)).font(.title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .trailing).padding(.trailing, 5)
                                .lineLimit(1).minimumScaleFactor(0.60)
                            Text(date.formatted(date:.omitted, time: .shortened)).font(.title3).foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth: .infinity,alignment: .trailing).padding(.trailing, 5)
                                .lineLimit(1).minimumScaleFactor(0.60)
                        }
                    }
                    .frame(maxWidth:.infinity,maxHeight: 75)
                    Spacer()
                    PlayersToScoreView(
                        passedGame: $game,
                        teamName: theTeam,
                        searchString: "",
                        sortOrder: sortAtbat,
                        theAtbats: $latbats,
                        isLoading: $isLoading,
                        hasChanged: $hasChanged,
                        columnVisability: $columnVisibility,
                        pitcherSectionScrollRequest: $pitcherSectionScrollRequest
                    )
                        .padding(.bottom, scorecardBottomToolbarClearance)
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
                            pitcherSelectionView()
                        }
                        .onChange(of: showPitchers, handlePitcherSelectionPresentationChange)
                        Button {
                            requestGeneratedOutput(.scorecardPDF)
                        } label: {
                            Text("PDF")
                        }
                        .frame(width: 56)
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
                        .frame(width: 160)
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
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if UIDevice.type == "iPhone" {
                bottomStatsControls
                    .padding(.bottom, bottomStatsOverlayBottomPadding)
            }
        }
        .overlayPreferenceValue(PitcherInningsTrackingTableBoundsPreferenceKey.self) { tableBounds in
            GeometryReader { proxy in
                if UIDevice.type != "iPhone", let tableBounds {
                    let tableFrame = proxy[tableBounds]
                    iPadStatsControls
                        .position(x: 75, y: tableFrame.midY)
                }
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: cancelPendingGeneratedOutputFlow) {
            PaywallView(context: .reports)
                .environmentObject(purchaseManager)
                .presentationDetents([.large])
        }
        .onReceive(purchaseManager.$entitlementState) { entitlementState in
            guard purchaseDecisionAuthority.decision(for: entitlementState).permitsCurrentSeasonAccess else { return }
            applyGeneratedOutputTransition(generatedOutputGateLifecycle.entitlementBecameActive())
        }
        .onDisappear {
            cancelPendingGeneratedOutputFlow()
        }

    }
    init(pgame: Game, pnavigationPath: Binding<NavigationPath>, ateam: String, columnVisability: Binding<NavigationSplitViewVisibility>) {
        game = pgame
        teamName = ateam
        _navigationPath = pnavigationPath
        _columnVisibility = columnVisability
    }

    private func requestGeneratedOutput(_ action: PurchaseGatedAction) {
        let workflow = PurchaseGatedWorkflowState(
            action: action,
            gameIdentity: game.ident,
            teamIdentity: team.ident,
            scopeDescription: "\(team.name) generated output",
            idempotencyKey: "\(game.ident.uuidString)-\(team.ident.uuidString)-\(action.rawValue)"
        )
        let transition = generatedOutputGateLifecycle.request(
            action: action,
            entitlement: purchaseDecisionAuthority.purchaseEntitlementState(for: purchaseManager.entitlementState),
            workflow: workflow
        )
        applyGeneratedOutputTransition(transition)
    }

    private func cancelPendingGeneratedOutputFlow() {
        applyGeneratedOutputTransition(generatedOutputGateLifecycle.purchaseFlowDismissedOrAbandoned())
    }

    private func applyGeneratedOutputTransition(_ transition: PurchaseGatedWorkflowTransition) {
        switch transition {
        case .none:
            break
        case .presentPaywall:
            showPaywall = true
        case .perform(let action):
            showPaywall = false
            performGeneratedOutput(action)
        }
    }

    private func performGeneratedOutput(_ action: PurchaseGatedAction) {
        switch action {
        case .scorecardPDF:
            let generatePDF = PDFGenerator()
            url = generatePDF.generatePDFData(game: game, team: team, title: "Test PDF", body: "This is a test")
        case .pitchingStatistics:
            showPitchRpt.toggle()
            isLoading = true
        case .hittingStatistics:
            showReport.toggle()
            isLoading = true
        case .existingRecordReview, .compatibleSourceDataExport:
            break
        }
    }

    @ViewBuilder
    private func pitcherSelectionView() -> some View {
        if let opTeam = opposingPitcherTeam() {
            PitcherContentView(team: opTeam, game: game) { request in
                pendingPitcherSectionScrollRequest = request
                publishPendingPitcherSectionScrollRequestIfReady()
            }
        }
    }

    private func opposingPitcherTeam() -> Team? {
        if team == game.hteam {
            return game.vteam
        }
        if team == game.vteam {
            return game.hteam
        }
        return nil
    }

    private func handlePitcherSelectionPresentationChange(_ oldValue: Bool, _ isPresented: Bool) {
        publishPendingPitcherSectionScrollRequestIfReady()
    }

    private func publishPendingPitcherSectionScrollRequestIfReady() {
        guard !showPitchers else {
            return
        }
        guard let request = pendingPitcherSectionScrollRequest else { return }
        pendingPitcherSectionScrollRequest = nil
        pitcherSectionScrollRequest = request
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
