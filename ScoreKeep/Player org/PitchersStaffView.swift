//
//  PitchersStaffView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/26/25.
//

import SwiftUI
import SwiftData

struct PitchersStaffView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var team: Team
    @State var game: Game
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State var updDatePitcher = false
    @State var pName = "Not Selected Yet"
    @State var pNum = ""
    @State var pPos = ""
    @State var startInn = 0
    @State var endInn = 0
    @State var sOuts = 0
    @State var eOuts = 0
    @State var sBats = 0
    @State private var reviewState: LiveScoringShellPresentation.PitcherChangeReviewState?
    let presenter = LiveScoringShellPresentation()
    @State var eBats = 0
    @State var thisPlayer = Player(name: "", number: "", position: "", batDir: "", batOrder: 99)
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State private var selection: Player?
    @State private var path = NavigationPath()
    @State private var editPitcher: Bool = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    let pitcherChangeCompleted: (LiveScoringShellPresentation.PitcherSectionScrollRequest) -> Void

    enum FocusField: Hashable {case field}
    @FocusState private var focusedField: FocusField?

//    @Query var pitchers: [Pitcher]
    @Query var players: [Player]
    
    var body: some View {
        ScrollView {

            HStack (spacing:0) {
                scorebookHeaderCell("Num")
                    .frame(width: 50).padding(.leading,10)
                scorebookHeaderCell("Name")
                    .frame(width: 150)
                scorebookHeaderCell("Pos")
                    .frame(width: 45)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "Start Inning" : "Strt Inn")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "Start Outs" :"Strt Out")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell("Start Batter")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "End Inning" : "End Inn")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "End Outs" : "End Out")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell("End Batter")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                Spacer(minLength: 50)
            }
            .minimumScaleFactor(0.8).lineLimit(1)
            HStack (spacing:0) {
                Text(pNum).frame(width:50, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).minimumScaleFactor(0.5).lineLimit(1)
                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).padding(.leading,10)
                Text(pName).frame(width:150, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).minimumScaleFactor(0.5).lineLimit(1)
                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                Text(pPos).frame(width:45, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText).minimumScaleFactor(0.5).lineLimit(1)
                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                Picker("Start Inning", selection: $startInn) {
                    let innings = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                    ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                        Text(inning).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Picker("Starts Outs", selection: $sOuts) {
                    let outs = ["0","1","2","3"]
                    ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                        Text(out).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Picker("Starts Bats", selection: $sBats) {
                    let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                    ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                        Text(out).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Picker("End Inning", selection: $endInn) {
                    let innings = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                    ForEach(Array(innings.enumerated()), id: \.1) { index, inning in
                        Text(inning).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Picker("End Outs", selection: $eOuts) {
                    let outs = ["0","1","2","3"]
                    ForEach(Array(outs.enumerated()), id: \.1) { index, out in
                        Text(out).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Picker("End Bats", selection: $eBats) {
                    let bats = ["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18"]
                    ForEach(Array(bats.enumerated()), id: \.1) { index, out in
                        Text(out).tag(index)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight: 25).overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).labelsHidden()
                Button("Delete") {
                    deleteStats()
                }
                .padding([.leading, .top, .bottom],2)
                .foregroundColor(.white)
                .buttonStyle(.borderless)
                .background(Color.red, in: Capsule())
            }
            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
            .onChange(of: [startInn, sOuts, sBats, endInn, eOuts, eBats]) {
                if let pitch = game.pitchers.first(where: { $0.player.name == pName }) {
                    pitch.startInn = startInn
                    pitch.sOuts = sOuts
                    pitch.sBats = sBats
                    pitch.endInn = endInn
                    pitch.eOuts = eOuts
                    pitch.eBats = eBats
                } else {
                    for player in players {
                        if pName == player.name {
                            thisPlayer = player
                        }
                    }
                    if !thisPlayer.name.isEmpty {
                        reviewState = presenter.preparePitcherChangeReview(
                            gameIdentity: game.ident,
                            teamIdentity: team.ident,
                            incomingPitcherIdentity: thisPlayer.identifier,
                            startInning: startInn,
                            startOuts: sOuts,
                            startBatters: sBats,
                            summaryIncomingName: thisPlayer.name
                        )
                    }
                }
            }
            Text("Select which player will pitch!").frame(maxWidth: .infinity, maxHeight: 20, alignment: .bottomLeading).font(UIDevice.type == "iPad" ? .callout : .caption)
                .italic().padding(.leading,10)
            HStack (spacing:0) {
                scorebookHeaderCell("Num")
                    .frame(width: 50).padding(.leading,10)
                scorebookHeaderCell("Name")
                    .frame(width: 150)
                scorebookHeaderCell("Pos")
                    .frame(width: 45)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "Start Inning" : "Strt Inn")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "Start Outs" :"Strt Out")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell("Start Batter")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "End Inning" : "End Inn")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell(UIDevice.type == "iPad" ? "End Outs" : "End Out")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                scorebookHeaderCell("End Batter")
                    .frame(maxWidth:.infinity,maxHeight: 50)
                Spacer(minLength: 50)
            }
            .minimumScaleFactor(0.8).lineLimit(1)
            ForEach(players, id: \.self) { player in
                HStack(spacing:0) {
                    Spacer(minLength: 10).background(.white)
                    HStack(spacing: 0) {
                        Text(player.number).frame(width: 50, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(player.name).frame(width: 150, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(player.position).frame(width: 45, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        let pitch = game.pitchers.first(where: { $0.player.id == player.id })
                        Text(String(pitch?.startInn ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.sOuts ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.sBats ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.endInn ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.eOuts ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                        Text(String(pitch?.eBats ?? 0)).frame(maxWidth: .infinity, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing).minimumScaleFactor(0.5).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .background(player == selection ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        self.selection = player
                    }
                    Spacer(minLength: 50).background(.white)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listStyle(.plain)
            .contentMargins(.top, 0)
            .onChange(of: selection, {
                cleanupPitchers()
                if let selection {
                    self.updDatePitcher = true
                    if let pitch = game.pitchers.first(where: { $0.player.id == selection.id }) {
                        pName = pitch.player.name
                        pNum = pitch.player.number
                        pPos = pitch.player.position
                        startInn = pitch.startInn
                        sOuts = pitch.sOuts
                        sBats = pitch.sBats
                        endInn = pitch.endInn
                        eOuts = pitch.eOuts
                        eBats = pitch.eBats
                    } else {
                        pName = selection.name
                        pNum = selection.number
                        pPos = selection.position
                        startInn = 0
                        sOuts = 0
                        sBats = 0
                        endInn = 0
                        eOuts = 0
                        eBats = 0
                    }
                }
            })
        }
        .alert("Confirm Pitcher Change", isPresented: Binding(
            get: { reviewState != nil && reviewState!.outcome == .pending },
            set: { if !$0 { _ = presenter.cancelPitcherChangeReview(&reviewState) } }
        )) {
            Button("Cancel", role: .cancel) {
                _ = presenter.cancelPitcherChangeReview(&reviewState)
            }
            Button("Confirm") {
                let coordinator = LiveScoringWorkflowCoordinator()
                let incomingPitcherIdentity = reviewState?.incomingPitcherIdentity
                let presentation = presenter.confirmPitcherChangeReview(&reviewState) { gameId, teamId, incomingId, sInn, sOuts, sBats in
                    coordinator.submitPitcherChange(
                        gameIdentity: gameId,
                        teamIdentity: teamId,
                        incomingPitcherIdentity: incomingId,
                        startInning: sInn,
                        startOuts: sOuts,
                        startBatters: sBats,
                        displayedAtbats: game.atbats,
                        pitchers: game.pitchers,
                        modelContext: modelContext,
                        save: { try modelContext.save() }
                    )
                }
                if presentation.outcome != .accepted {
                    alertMessage = presentation.message ?? "Pitcher change failed."
                    showingAlert = true
                } else {
                    if let scrollRequest = presenter.pitcherSectionScrollRequest(
                        afterPitcherChange: presentation,
                        incomingPitcherIdentity: incomingPitcherIdentity
                    ) {
                        pitcherChangeCompleted(scrollRequest)
                    }
                    dismiss()
                }
            }
        } message: {
            if let review = reviewState {
                Text("Confirm pitcher change to \(review.summaryIncomingName)?")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(ScoreKeepVisualStyle.secondaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding before his first batter? Leave Start Inning at 0 — ScoreKeep fills in the rest.")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("Start/End Batter define batters faced in the inning.")
                }
                .font(.subheadline)
                .foregroundColor(ScoreKeepVisualStyle.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ScoreKeepVisualStyle.elevatedSurface)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onDisappear {
            if game.pitchers.first(where: { $0.player.name == pName }) == nil {
                for player in players {
                    if pName == player.name {
                        thisPlayer = player
                    }
                }
                if pName != "" && pName != "Not Selected Yet" {
                    let coordinator = LiveScoringWorkflowCoordinator()
                    let result = coordinator.submitPitcherChange(
                        gameIdentity: game.ident,
                        teamIdentity: team.ident,
                        incomingPitcherIdentity: thisPlayer.identifier,
                        startInning: startInn,
                        startOuts: sOuts,
                        startBatters: sBats,
                        displayedAtbats: game.atbats,
                        pitchers: game.pitchers,
                        modelContext: modelContext,
                        save: { try modelContext.save() }
                    )
                    if result.disposition != .accepted {
                        alertMessage = result.message ?? "Error saving new pitcher"
                        showingAlert = true
                    } else {
                        let presentation = LiveScoringShellPresentation.SubstitutionReviewPresentation(
                            outcome: .accepted,
                            shouldClearPendingReview: true,
                            shouldMarkChanged: true,
                            refreshedState: result.refreshedState,
                            message: result.message
                        )
                        if let scrollRequest = presenter.pitcherSectionScrollRequest(
                        afterPitcherChange: presentation,
                        incomingPitcherIdentity: thisPlayer.identifier
                    ) {
                            pitcherChangeCompleted(scrollRequest)
                        }
                    }
                }
            }
            cleanupPitchers()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Select who will pitch")
                    .font(.title2)
            }
        }
        Spacer()
    }
    init(
        searchString: String = "",
        sortOrder: [SortDescriptor<Player>] = [],
        passedGame: Game,
        passedTeam: Team,
        theTeam: String,
        showPitchersOnly: Bool = false,
        pitcherChangeCompleted: @escaping (LiveScoringShellPresentation.PitcherSectionScrollRequest) -> Void = { _ in }
    ) {
        team = passedTeam
        game = passedGame
        self.pitcherChangeCompleted = pitcherChangeCompleted
        
        if searchString.isEmpty && showPitchersOnly == false {
            _players = Query(filter: #Predicate { player in
                player.team?.name == theTeam
            }, sort: sortOrder)
        } else if searchString.isEmpty && showPitchersOnly {
            _players = Query(filter: #Predicate { player in
                player.team?.name == theTeam &&
                (player.position == "P" || player.position == "SP" || player.position == "RP")
            }, sort: sortOrder)
        } else if showPitchersOnly == false {
            _players = Query(filter: #Predicate { player in
                player.team?.name == theTeam &&
                (player.name.localizedStandardContains(searchString)
                || player.number.localizedStandardContains(searchString))
            }, sort: sortOrder)
        } else {
            _players = Query(filter: #Predicate { player in
                player.team?.name == theTeam &&
                (player.position == "P" || player.position == "SP" || player.position == "RP") &&
                (player.name.localizedStandardContains(searchString)
                || player.number.localizedStandardContains(searchString))
            }, sort: sortOrder)
        }
        
    }
    func deleteStats() {
        if let pitch = game.pitchers.first(where: { $0.player.name == pName }) {
            game.pitchers.removeAll { $0.player.name == pName }
            modelContext.delete(pitch)
            pNum = ""
            pName = "Not Selected Yet"
            pPos = ""
            startInn = 0
            sOuts = 0
            endInn = 0
            eOuts = 0
            do {
                try self.modelContext.save()
            }
            catch {
                print("Error deleting pitcher: \(error)")
            }
        } else {
            if selection != nil {
                selection = nil
                pNum = ""
                pName = "Not Selected Yet"
                pPos = ""
                startInn = 0
                sOuts = 0
                endInn = 0
                eOuts = 0
            } else {
                alertMessage = "No pitcher selected"
                showingAlert = true
            }
        }
    }
    func cleanupPitchers() {
        for pitcher in game.pitchers {
            if pitcher.player.name.isEmpty {
                game.pitchers.removeAll {
                    $0 == pitcher }
                modelContext.delete(pitcher)
            }
        }
        try? modelContext.save()
    }
}
