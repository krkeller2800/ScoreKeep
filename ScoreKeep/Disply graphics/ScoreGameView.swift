//
//  ScoreGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/6/25.
//

import SwiftUI
import SwiftData

struct ScoreGameView: View {
    @Environment(\.modelContext) var modelContext
    @State private var path = NavigationPath()
    @Binding private var atbat:Atbat
    @Binding private var showingScoring:Bool
    @State private var thisInning:Int = 0
    @State private var earnedRun: Bool = true
    @State private var recPlay: Bool = false
    @State private var delAtbat: Bool = false
    @State private var playRec: String = ""
    @State private var onBase: String = "Result"
    @State private var batOut: String = "Result"
    @State private var pendingAdditionalChoice: LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice?
    @State private var pendingMaxBase: String = "No Bases"
    @State private var pendingOutAt: String = "Safe"
    @State private var pendingRBIs: Int = 0
    @State private var pendingStolenBases: Int = 0
    @State private var pendingEarnedRun: Bool = true
    @State private var pendingPlayRecord: String = ""
    @State private var correctionResult: String = "Result"
    @State private var correctionMaxBase: String = "No Bases"
    @State private var correctionOutAt: String = "Safe"
    @State private var correctionRBIs: Int = 0
    @State private var correctionStolenBases: Int = 0
    @State private var correctionEarnedRun: Bool = true
    @State private var correctionPlayRecord: String = ""

    let enabledActionPresentation: LiveScoringShellPresentation.EnabledActionSetPresentation?
    let submitScoringAction: ((String) -> LiveScoringShellPresentation.SubmissionPresentation)?
    let prepareAdditionalChoiceScoringAction: ((String) -> LiveScoringShellPresentation.AdditionalChoicePresentation)?
    let submitAdditionalChoiceScoringAction: ((LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice, LiveScoringWorkflowCoordinator.AdditionalScoringChoices) -> LiveScoringShellPresentation.SubmissionPresentation)?
    let isCorrectionEntry: Bool
    let submitCorrectionEntry: ((LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement) -> Void)?
    let com:Common = Common()

    init(
        atbat: Binding<Atbat>,
        showingScoring: Binding<Bool>,
        enabledActionPresentation: LiveScoringShellPresentation.EnabledActionSetPresentation? = nil,
        submitScoringAction: ((String) -> LiveScoringShellPresentation.SubmissionPresentation)? = nil,
        prepareAdditionalChoiceScoringAction: ((String) -> LiveScoringShellPresentation.AdditionalChoicePresentation)? = nil,
        submitAdditionalChoiceScoringAction: ((LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice, LiveScoringWorkflowCoordinator.AdditionalScoringChoices) -> LiveScoringShellPresentation.SubmissionPresentation)? = nil,
        isCorrectionEntry: Bool = false,
        submitCorrectionEntry: ((LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement) -> Void)? = nil
    ) {
        _atbat = atbat
        _showingScoring = showingScoring
        self.enabledActionPresentation = enabledActionPresentation
        self.submitScoringAction = submitScoringAction
        self.prepareAdditionalChoiceScoringAction = prepareAdditionalChoiceScoringAction
        self.submitAdditionalChoiceScoringAction = submitAdditionalChoiceScoringAction
        self.isCorrectionEntry = isCorrectionEntry
        self.submitCorrectionEntry = submitCorrectionEntry
    }
    
    var body: some View {
        Section {
            GeometryReader { geometry in
                VStack(spacing:0) {
                    HStack(spacing:0) {
                        Button("Done", action: {
                            if isCorrectionEntry {
                                submitCorrectionDraft()
                                showingScoring.toggle()
                            } else if let pendingAdditionalChoice {
                                let presentation = finalizeAdditionalChoice(pendingAdditionalChoice)
                                if presentation?.shouldDismissScoringSheet == true {
                                    showingScoring.toggle()
                                }
                            } else {
                                showingScoring.toggle()
                            }
                            if atbat.result == "Result" && pendingAdditionalChoice == nil && !isCorrectionEntry {
                                if atbat.col != 1 {
                                    atbat.game.atbats.removeAll() {$0 == atbat}
                                    delAtbat = true
                                }
                            }
                        })
                        .accessibilityIdentifier("submit_scoring_action")
                        .frame(maxWidth: 120,minHeight: 30, alignment:.center).background(.green.opacity(0.5))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.all, 15)
                        Spacer()
                        Text("\(atbat.player.team?.name ?? "") Batting").font(.title2)
                        Spacer()
                        Button("Delete At Bat", action: {
                            showingScoring.toggle()
                            if atbat.col != 1 {
                                atbat.game.atbats.removeAll() {$0 == atbat}
                                delAtbat = true
                            } else {
                                atbat.result = "Result"
                                atbat.maxbase = "No Bases"
                                atbat.outAt = "Safe"
                                checkForCol1Dup ()
                            }
                        })
                        .accessibilityIdentifier("cancel_scoring_action")
                        .frame(maxWidth: 120,minHeight: 30, alignment:.center).background(.red.opacity(0.5))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.all, 15)

                    }
                    HStack {
                        Picker("RBI", selection: rbiBinding) {
                            let rbis = ["RBIs","1 RBI","2 RBIs","3 RBIs","4 RBIs"]
                            ForEach(Array(rbis.enumerated()), id: \.1) { index, rbi in
                                Text(rbi).tag(index)
                            }
                        }
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.leading, 15)
                        Spacer()
                        Text("\(atbat.player.number) \(atbat.player.name)").font(.title3)
                        Spacer()
                        Picker("Steal", selection: stolenBaseBinding) {
                            let rbis = ["Steals","1 Stolen","2 Stolen","3 Stolen"]
                            ForEach(Array(rbis.enumerated()), id: \.1) { index, rbi in
                                Text(rbi).tag(index)
                            }
                        }
                        .frame(maxWidth: 120,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black).padding(.trailing, 15)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Text("On Base").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 30)
                        Spacer()
                        Text("Batting Out").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                        Text("Max Base").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                        Text("Base path Out").frame(maxWidth: 120, maxHeight: 50 ,alignment:.bottomLeading).padding(.leading, 0)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Picker("Batting", selection: $onBase) {
                            Text("Result").tag("Result")
                            Divider()
                            let bats = com.onresults
                            ForEach (bats, id: \.self) { batting in
                                if batting != "" {
                                    let action = resultPresentation(for: batting)
                                    Text(batting)
                                        .tag(batting)
                                        .disabled(!action.isEnabled)
                                        .accessibilityLabel(action.accessibilityLabel)
                                        .accessibilityHint(action.accessibilityHint ?? "")
                                }
                                if batting == "Dropped 3rd Stike" || batting == "Fielder's Choice" || batting == "Home Run" {
                                    Divider()
                                }
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                         .onChange(of: onBase) {
                             if onBase != "Result" {
                                 selectResult(onBase)
                                 batOut = "Result"
                             }
                         }
                        Spacer()
                        Picker("Batting", selection: $batOut) {
                            Text("Result").tag("Result")
                            Divider()
                            let bats = com.outresults
                            ForEach (bats, id: \.self) { batting in
                                if batting != "" {
                                    let action = resultPresentation(for: batting)
                                    Text(batting)
                                        .tag(batting)
                                        .disabled(!action.isEnabled)
                                        .accessibilityLabel(action.accessibilityLabel)
                                        .accessibilityHint(action.accessibilityHint ?? "")
                                }
                                if batting == "Strikeout Looking" {
                                    Divider()
                                }
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                         .onChange(of: batOut) {
                             if batOut != "Result" {
                                 selectResult(batOut)
                                 onBase = "Result"
                             }
                         }
                         Spacer()
                        Picker("Running", selection: maxBaseBinding) {
                            Text("No Bases").tag("No Bases")
                            let bases = ["","First","Second","Third","Home"]
                            ForEach (bases, id: \.self) { base in
                                (base != "") ? Text(base).tag(base): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                        Spacer()
                        Picker("Out", selection: outAtBinding) {
                            Text("Safe").tag("Safe")
                            let outs = ["","First","Second","Third","Home"]
                            ForEach (outs, id: \.self) { out in
                                (out != "") ? Text(out).tag(out): nil
                            }
                        }
                         .frame(maxWidth: 120,maxHeight: 60, alignment:.center).background(.blue.opacity(0.2))
                         .border(.gray).cornerRadius(10).accentColor(.black)
                        Spacer()
                    }
                    .padding(.leading, 0)
                    .onChange(of: atbat.result) {
                        let result = displayedResult
                        if result == "Dropped 3rd Strike" || result == "Error" {
                            earnedRun = false
                        }
                        if !com.recOuts.contains(result) || displayedOutAt != "Safe"  {
                            recPlay = false
                        } else {
                            recPlay = true
                        }
                    }
                    .onChange(of: displayedOutAt) {
                        if displayedOutAt != "Safe" {
                            recPlay = true
                        } else {
                            if pendingAdditionalChoice == nil {
                                clearPlayRecord()
                            }
                            recPlay = false
                            if !isCorrectionEntry {
                                showingScoring.toggle()
                            }
                        }
                        if !isCorrectionEntry {
                            setEndOfInning()
                        }
                    }
                    .onAppear {
                        prepareCorrectionDraftIfNeeded()
                        if currentPlayRecord != "" || com.recOuts.contains(displayedResult) || displayedOutAt != "Safe" {
                            recPlay = true
                        }
                        if com.onresults.contains(displayedResult) {
                            onBase = displayedResult
                            batOut = "Result"
                        } else if com.outresults.contains(displayedResult) {
                            batOut = displayedResult
                            onBase = "Result"
                        } else {
                            onBase = "Result"
                            batOut = "Result"
                        }
                        earnedRun = currentEarnedRun
                    }
                    .onDisappear {
                        if pendingAdditionalChoice == nil && !isCorrectionEntry {
                            setEndOfInning()
                        }
                        if delAtbat {
                            modelContext.delete(atbat)
                        }
                    }
                    Spacer()
                    HStack (spacing: 0){
                        if com.onresults.contains(displayedResult) {
                            Text("\nIf batter scores:").padding(.leading, 10).font(.title3)
                        }
                        Spacer()
                        if recPlay {
                            Text("Select player(s)\nto record the out").padding([.bottom,.trailing],10)
                        }
                    }
                    HStack {
                        if com.onresults.contains(displayedResult) {
                            Button(earnedRunText, action: {
                                toggleEarnedRun()
                            })
                            .frame(maxWidth: 130,maxHeight: 30, alignment:.center).background(currentEarnedRun ? .green.opacity(0.5) : .red.opacity(0.5))
                            .border(.gray).cornerRadius(10).accentColor(.black).padding([.leading, .trailing, .bottom], 15)
                        }
                        Spacer()
                        if recPlay {
                            Spacer()
                            Text(currentPlayRecord).padding(.trailing,15)
                            Button("Clear", action: {
                                 clearPlayRecord()
                             })
                             .frame(maxWidth: 50,maxHeight: 30, alignment:.center).background(.red.opacity(0.5))
                             .border(.gray).cornerRadius(10).accentColor(.black).padding([.bottom,.trailing], 15)
                        }
                    }
   
                }
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.yellow.opacity(0.1)).stroke(.black, lineWidth: 8))
                if recPlay {
                    fielderButtons(size: geometry.size, result: displayedResult, playRecord: playRecordBinding)
                }
                if let idx = com.battings.firstIndex(where: { $0 == displayedResult }) {
                    let abb = com.batAbbrevs[idx]
                    drawIt(size: geometry.size, atbat: atbat, abb: abb)
                }
                if UIDevice.type == "iPhone" {
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(45))
                        .position(x:0.57 * geometry.size.width, y:0.81 * geometry.size.height)
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(45))
                        .position(x:0.5 * geometry.size.width, y:0.7 * geometry.size.height)
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 15).rotationEffect(.degrees(47))
                        .position(x:0.43 * geometry.size.width, y:0.81 * geometry.size.height)
                    if com.onresults.contains(displayedResult) || displayedResult == "Result" {
                        Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 11)
                            .position(x:0.5 * geometry.size.width, y:0.92 * geometry.size.height)
                        Path() {
                            myPath in
                            myPath.move(to: CGPoint(x: 0.487 * geometry.size.width, y: 0.93 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.50 * geometry.size.width, y: 0.96 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.512 * geometry.size.width, y: 0.93 * geometry.size.height))
                            myPath.addLine(to: CGPoint(x: 0.49 * geometry.size.width, y: 0.93 * geometry.size.height))
                        }
                        .fill(Color.gray.opacity(0.5))
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                         .position(x:0.75 * geometry.size.width, y:0.7 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(45))
                         .position(x:0.5 * geometry.size.width, y:0.5 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 30).rotationEffect(.degrees(47))
                         .position(x:0.25 * geometry.size.width, y:0.7 * geometry.size.height)
                     Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 30, height: 22)
                         .position(x:0.5 * geometry.size.width, y:0.88 * geometry.size.height)
                     Path() {
                         myPath in
                         myPath.move(to: CGPoint(x: 0.475 * geometry.size.width, y: 0.9 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.50 * geometry.size.width, y: 0.92 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.525 * geometry.size.width, y: 0.90 * geometry.size.height))
                         myPath.addLine(to: CGPoint(x: 0.48 * geometry.size.width, y: 0.90 * geometry.size.height))
                     }
                     .fill(Color.gray.opacity(0.5))
                }
            }
        }
    }
    func setEndOfInning () {
     
        var inning = 0
        var outs = 0
        let bats = atbat.game.atbats.filter { $0.team == atbat.team && $0.result != "Result" }.sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }
        for atbat in bats {
            atbat.endOfInning = false
            inning += outs % 3 == 0 ? 1 : 0
            if (com.outresults.contains(atbat.result) || atbat.outAt != "Safe") && atbat.team == atbat.team {
                outs += 1
            }
//            atbat.inning = CGFloat(outs)/3.0
//            if CGFloat(inning) > atbat.inning {
//                atbat.inning += 0.1
//            }
        }
        let innings:Int = outs / 3
        let out = outs % 3

        if innings > 0 {
            for inning in 1...innings {
                if inning <= innings || out == 0 {
                    let gAtbats = atbat.game.atbats.filter { $0.team == atbat.team && $0.result != "Result" && $0.result != "Pitch Hitter" &&
                        ($0.inning >= CGFloat(inning-1) && $0.inning <= CGFloat(inning)) }.sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }
                    gAtbats.last?.endOfInning = true
                }
            }
            atbat.sacFly = atbat.sacFly != 0 ? 0 : -1
        }
    }
    func checkForCol1Dup () {
        let dups = atbat.game.atbats.filter({ $0.team == atbat.team && $0.col == 1 && $0.player == atbat.player})
        if dups.count > 1 {
            for dup in dups {
                if dup.result != "Result" {
                    if let index = atbat.game.atbats.firstIndex(of: dup) {
                        atbat.game.atbats.remove(at: index)
                    }
                    modelContext.delete(dup)
                }
            }
        }
    }

    private var displayedResult: String {
        pendingAdditionalChoice?.legacyResult ?? (isCorrectionEntry ? correctionResult : atbat.result)
    }

    private var displayedOutAt: String {
        pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionOutAt : atbat.outAt) : pendingOutAt
    }

    private var currentEarnedRun: Bool {
        pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionEarnedRun : earnedRun) : pendingEarnedRun
    }

    private var earnedRunText: String {
        currentEarnedRun ? "Run Earned" : "Run Unearned"
    }

    private var currentPlayRecord: String {
        pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionPlayRecord : atbat.playRec) : pendingPlayRecord
    }

    private var rbiBinding: Binding<Int> {
        Binding(
            get: { pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionRBIs : atbat.rbis) : pendingRBIs },
            set: { value in
                if isCorrectionEntry && pendingAdditionalChoice == nil {
                    correctionRBIs = value
                } else if pendingAdditionalChoice == nil {
                    atbat.rbis = value
                } else {
                    pendingRBIs = value
                }
            }
        )
    }

    private var stolenBaseBinding: Binding<Int> {
        Binding(
            get: { pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionStolenBases : atbat.stolenBases) : pendingStolenBases },
            set: { value in
                if isCorrectionEntry && pendingAdditionalChoice == nil {
                    correctionStolenBases = value
                } else if pendingAdditionalChoice == nil {
                    atbat.stolenBases = value
                } else {
                    pendingStolenBases = value
                }
            }
        )
    }

    private var maxBaseBinding: Binding<String> {
        Binding(
            get: { pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionMaxBase : atbat.maxbase) : pendingMaxBase },
            set: { value in
                if isCorrectionEntry && pendingAdditionalChoice == nil {
                    correctionMaxBase = value
                } else if pendingAdditionalChoice == nil {
                    atbat.maxbase = value
                } else {
                    pendingMaxBase = value
                }
            }
        )
    }

    private var outAtBinding: Binding<String> {
        Binding(
            get: { pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionOutAt : atbat.outAt) : pendingOutAt },
            set: { value in
                if isCorrectionEntry && pendingAdditionalChoice == nil {
                    correctionOutAt = value
                    if value == "Safe" {
                        correctionPlayRecord = ""
                    }
                } else if pendingAdditionalChoice == nil {
                    atbat.outAt = value
                } else {
                    pendingOutAt = value
                    if value == "Safe" {
                        pendingPlayRecord = ""
                        recPlay = com.recOuts.contains(displayedResult)
                    } else {
                        recPlay = true
                    }
                }
            }
        )
    }

    private var playRecordBinding: Binding<String> {
        Binding(
            get: { pendingAdditionalChoice == nil ? (isCorrectionEntry ? correctionPlayRecord : atbat.playRec) : pendingPlayRecord },
            set: { value in
                if isCorrectionEntry && pendingAdditionalChoice == nil {
                    correctionPlayRecord = value
                } else if pendingAdditionalChoice == nil {
                    atbat.playRec = value
                } else {
                    pendingPlayRecord = value
                }
            }
        )
    }

    private func selectResult(_ result: String) {
        if isCorrectionEntry {
            correctionResult = result
            return
        }
        if requiresAdditionalChoice(result), let prepareAdditionalChoiceScoringAction {
            let presentation = prepareAdditionalChoiceScoringAction(result)
            if let pending = presentation.pendingChoice, presentation.shouldPresentAdditionalChoices {
                beginAdditionalChoice(pending)
            }
            if let message = presentation.message {
                print(message)
            }
        } else {
            submitResult(result)
        }
    }

    private func requiresAdditionalChoice(_ result: String) -> Bool {
        com.onresults.contains(result) || com.recOuts.contains(result)
    }

    private func beginAdditionalChoice(_ pending: LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice) {
        pendingAdditionalChoice = pending
        pendingMaxBase = pending.choices.maxBase
        pendingOutAt = pending.choices.outAt
        pendingRBIs = pending.choices.rbis
        pendingStolenBases = pending.choices.stolenBases
        pendingEarnedRun = pending.choices.earnedRun
        pendingPlayRecord = pending.choices.playRecord
        earnedRun = pending.choices.earnedRun
        recPlay = pending.allowsPlayRecordChoice || pending.choices.outAt != "Safe"
    }

    @discardableResult
    private func finalizeAdditionalChoice(
        _ pending: LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice
    ) -> LiveScoringShellPresentation.SubmissionPresentation? {
        guard let submitAdditionalChoiceScoringAction else { return nil }
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: pending.legacyResult,
            maxBase: pendingMaxBase,
            outAt: pendingOutAt,
            rbis: pendingRBIs,
            stolenBases: pendingStolenBases,
            earnedRun: pendingEarnedRun,
            playRecord: pendingPlayRecord
        )
        let presentation = submitAdditionalChoiceScoringAction(pending, choices)
        if presentation.disposition == .accepted || presentation.disposition == .duplicatePrevented {
            pendingAdditionalChoice = nil
            earnedRun = atbat.earnedRun
            recPlay = com.recOuts.contains(atbat.result) || atbat.outAt != "Safe"
        }
        if let message = presentation.message {
            print(message)
        }
        return presentation
    }

    private func toggleEarnedRun() {
        if isCorrectionEntry && pendingAdditionalChoice == nil {
            correctionEarnedRun.toggle()
            earnedRun = correctionEarnedRun
        } else if pendingAdditionalChoice == nil {
            earnedRun.toggle()
            atbat.earnedRun = earnedRun
        } else {
            pendingEarnedRun.toggle()
            earnedRun = pendingEarnedRun
        }
    }

    private func clearPlayRecord() {
        if isCorrectionEntry && pendingAdditionalChoice == nil {
            correctionPlayRecord = ""
        } else if pendingAdditionalChoice == nil {
            atbat.playRec = ""
        } else {
            pendingPlayRecord = ""
        }
    }

    @discardableResult
    private func submitResult(_ result: String) -> LiveScoringShellPresentation.SubmissionPresentation? {
        if let submitScoringAction {
            let presentation = submitScoringAction(result)
            if presentation.disposition == .accepted || presentation.disposition == .duplicatePrevented {
                recPlay = com.recOuts.contains(result) || atbat.outAt != "Safe"
                if result == "Dropped 3rd Strike" || result == "Error" {
                    earnedRun = false
                }
            }
            return presentation
        }

        atbat.result = result
        return nil
    }

    private func prepareCorrectionDraftIfNeeded() {
        guard isCorrectionEntry else { return }
        correctionResult = atbat.result
        correctionMaxBase = atbat.maxbase
        correctionOutAt = atbat.outAt
        correctionRBIs = atbat.rbis
        correctionStolenBases = atbat.stolenBases
        correctionEarnedRun = atbat.earnedRun
        correctionPlayRecord = atbat.playRec
    }

    private func submitCorrectionDraft() {
        submitCorrectionEntry?(
            LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
                result: correctionResult,
                maxBase: correctionMaxBase,
                outAt: correctionOutAt,
                rbis: correctionRBIs,
                stolenBases: correctionStolenBases,
                earnedRun: correctionEarnedRun,
                playRecord: correctionPlayRecord
            )
        )
    }

    private func resultPresentation(for result: String) -> LiveScoringShellPresentation.EnabledActionPresentation {
        let identity = LiveScoringWorkflowCoordinator.ScoringActionIdentity.legacyResult(result)
        if let action = enabledActionPresentation?.state(for: identity) {
            return action
        }
        return LiveScoringShellPresentation.EnabledActionPresentation(
            identity: identity,
            isEnabled: false,
            accessibilityLabel: result,
            accessibilityHint: "Scoring state is not ready for this action.",
            warningMessage: nil
        )
    }
 }
