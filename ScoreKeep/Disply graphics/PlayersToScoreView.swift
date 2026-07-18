//
//  PlayersToScoreView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/29/25.
//

import SwiftUI
import SwiftData
struct PlayersToScoreView: View {
    @Environment(\.modelContext) var modelContext
    @Query var atbats: [Atbat]
    @Query var pitchers: [Pitcher]
    @Binding var lAtbats: [Atbat]
    @Binding var game: Game
    @Binding var isLoading: Bool
    @Binding var hasChanged: Bool
    @Binding var columnVisability:NavigationSplitViewVisibility
    @State var screenSize: CGSize = .zero
    @State var screenWidth = UIScreen.screenWidth
    @State var screenHeight = UIScreen.screenHeight
    @State var showingScoring = false
    @State var firstTime = true
    @State var teamName = ""
    @State var playerName = ""
    @State private var offset = CGFloat.zero

    @State var colbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var batbox:[BoxScore] = Array(repeating: BoxScore(), count: 20)
    @State var totbox:[BoxScore] = Array(repeating: BoxScore(), count: 5)
    @State var iStat:InnStatus = InnStatus()
    @State private var preparedLiveGameState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?
    @State private var semanticScorePresentation: LiveScoringShellPresentation.SemanticScorePresentation?
    @State private var enabledActionPresentation: LiveScoringShellPresentation.EnabledActionSetPresentation?
    let liveScoringCoordinator = LiveScoringWorkflowCoordinator()
    let liveScoringShellPresentation = LiveScoringShellPresentation()
    let com = Common()

    @State var theAtbat = Atbat(game: Game(date: "", location: "", highLights: "", hscore: 0, vscore: 0),
                                team: Team(name: "", coach: "", details: ""),
                                player: Player(name: "", number: "", position: "", batDir: "", batOrder: 99),
                                result: "Result", maxbase: "No Bases", batOrder: 99, outAt: "Safe", inning: 1, seq:0, col:1, rbis:0, outs:0,
                                sacFly: 0,sacBunt: 0,stolenBases: 0)
    var body: some View {
        Section {
            GeometryReader { geometry in
                let gWidth = geometry.size.width
                drawIndicator(iStat:iStat,size:geometry.size,colbox:colbox,space:calcSpace(gWidth: gWidth))
                drawBoxScore(game:game,size:geometry.size)
                if let semanticScorePresentation {
                    semanticScoreLine(presentation: semanticScorePresentation, size: geometry.size)
                }
                drawInnings(game: game, atbats: atbats, space: calcSpace(gWidth: gWidth),offset: offset,gWidth: gWidth)
                VStack ( spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Num").frame(width:30, height: 15, alignment:.center).font(.caption).foregroundColor(.black).bold().padding(.leading, 3)
                        Text("Name").frame(width:50, height: 15, alignment:.leading).font(.caption).foregroundColor(.black).bold()
                        Spacer()
                    }
                    ScrollView() {
                        HStack {
                            VStack (spacing: 0){
                                ForEach(Array(atbats.enumerated()), id: \.element.persistentModelID) { index, atbat in
                                    HStack(spacing: 2) {
                                        if atbat.inning <= 1 && atbat.col == 1 && atbat.batOrder != 99 {
                                            let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                            let player = atbat.player
                                            let strikeIt = containsPlayer(player, in: game.replaced)
                                            let isIncoming = containsPlayer(player, in: game.incomings)
                                            let iName = isIncoming ? "    \(player.name)" : player.name
                                            Text(player.number).frame(width: 30, height: bSiz,alignment: .center).foregroundColor(.black)
                                                .overlay(Divider().background(.black), alignment: .trailing)
                                            Text(iName).frame(width: 150, alignment: .leading).foregroundColor(.black).strikethrough(strikeIt)
                                                .fixedSize(horizontal: true, vertical: true).padding(.leading,5).lineLimit(2)

                                        }
                                    }
                                }
                                Spacer()
                            }
                            ScrollView(.horizontal) {
                                ZStack {
                                    let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
                                    let gridSz = CGFloat(gWidth > 1100 ? 60 : 50)
                                    let bSize = Int(((gWidth - (gWidth > 1100 ? 425 : 325)) / gridSz).rounded(.down))
                                    let newCol = (bigCol?.col ?? 1) + 1
                                    let maxCol = newCol < bSize ? bSize : newCol
                                    VStack (spacing: 0) {
                                        ForEach(Array(atbats.enumerated()), id: \.element.persistentModelID) { index, atbat in
                                            HStack(spacing: 0) {
                                                if atbat.inning <= 1 && atbat.col == 1 && atbat.batOrder != 99 {
                                                    ForEach((1...maxCol), id: \.self) {ind in
                                                        let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                                        Button(action: {
                                                            doAtbat(ind: ind, index: index, atbat: atbat)
                                                        }, label: {
                                                            Image("field").resizable().scaledToFit()
                                                        })
                                                        .frame(width: bSiz, height: bSiz)
                                                        .buttonStyle(GlowButtonStyle())
                                                        .disabled(!scorecardCellPresentation(column: ind, atbat: atbat).isEnabled)
                                                        .accessibilityLabel(scorecardCellPresentation(column: ind, atbat: atbat).accessibilityLabel)
                                                        .accessibilityHint(scorecardCellPresentation(column: ind, atbat: atbat).accessibilityHint ?? "")
                                                    }
                                                }
                                                let mCol = Double(gWidth) - 150 - (Double(maxCol+1) * gridSz)
                                                Spacer(minLength:mCol < 0 ? 0 : mCol)
                                            }
                                        }
                                        if let firstAtbat = atbats.first,
                                           let opTeam = opponentTeam(for: firstAtbat.team) {
                                            let numOfPitchers = CGFloat(pitchers.filter { $0.team == opTeam }.count)
                                            Spacer(minLength: numOfPitchers * 25 + 100)
                                        }
                                    }
                                    .background(GeometryReader {
                                        Color.clear.preference(key: ViewOffsetKey.self, value: -$0.frame(in: .named("scroll")).origin.x)
                                    })
                                    .onPreferenceChange(ViewOffsetKey.self) {
                                        offset = $0
                                    }
                                    if let firstAtbat = atbats.first,
                                       let opTeam = opponentTeam(for: firstAtbat.team) {
                                        drawSing(space: calcSpace(gWidth:gWidth), atbats: atbats.sorted{ ($0.col, $0.seq) < ($1.col, $1.seq) },colbox: colbox,batbox: batbox, totbox: totbox,sWidth: gWidth, isLoading: $isLoading)
                                        drawPitchers(space: calcSpace(gWidth:gWidth), atbats: atbats, abb: "", inning: 1,game: game, team: opTeam, width: gWidth)
                                    }
                                }
                            }
                            .coordinateSpace(name: "scroll")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // <5>
                .onAppear() {
                    lAtbats = atbats
                }
                .onChange(of: atbats) {
                    if firstTime {
                        refreshLiveScoringWorkflow()
                        firstTime = false
                    }
                }
                .onChange(of: theAtbat.result) {
                    refreshLiveScoringWorkflow()
                }
                .onChange(of: theAtbat.outAt) {
                    refreshLiveScoringWorkflow()
                }
                .onChange(of: atbats.count > 0 ? atbats[0].team.name : "") {
                    refreshLiveScoringWorkflow()
                }
                .onChange(of: theAtbat.sacFly) {
                    refreshLiveScoringWorkflow()
                }
                .onChange(of: pitchers.count) { _, _ in
                    // A pitcher was added or removed; sync markers now.
                    refreshLiveScoringWorkflow()
                }

            }
            .sheet(isPresented: $showingScoring) {
                ScoreGameView(
                    atbat: $theAtbat,
                    showingScoring: $showingScoring,
                    enabledActionPresentation: enabledActionPresentation,
                    submitScoringAction: submitScoringAction,
                    prepareAdditionalChoiceScoringAction: prepareAdditionalChoiceScoringAction,
                    submitAdditionalChoiceScoringAction: submitAdditionalChoiceScoringAction
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                
            // Give a moment for the screen boundaries to change after
            // the device is rotated
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(0.2))
                    withAnimation {
                        screenHeight = UIScreen.main.bounds.height
                        screenWidth = UIScreen.main.bounds.width
                        columnVisability = .detailOnly
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    func calcSpace(gWidth:CGFloat) -> CGRect {
        let bSize:CGFloat = gWidth > 1100 ? 60 : 50
        let newx:CGFloat = gWidth > 1100 ? -60 : -50
        return CGRect(x: newx, y: 0, width: bSize, height: bSize)
    }
    func refreshLiveScoringWorkflow() {
        let battingTeam = atbats.first?.team ?? teamForName(teamName)
        let preparedResult = liveScoringCoordinator.prepareLiveGameState(
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: atbats,
            pitchers: pitchers
        )
        let preparedPresentation = liveScoringShellPresentation.presentPreparedState(preparedResult)
        preparedLiveGameState = preparedPresentation.preparedState
        if let message = preparedPresentation.message {
            print(message)
        }
        let semanticState = liveScoringCoordinator.semanticScoreState(
            preparedState: preparedPresentation.preparedState,
            displayedAtbats: atbats
        )
        let scorePresentation = liveScoringShellPresentation.presentSemanticScoreState(semanticState)
        semanticScorePresentation = scorePresentation
        if let message = scorePresentation.message {
            print(message)
        }
        let enabledActions = liveScoringCoordinator.enabledScoringActions(
            preparedState: preparedPresentation.preparedState,
            semanticScoreState: semanticState,
            displayedAtbats: atbats,
            supportedLegacyResults: com.onresults + com.outresults
        )
        enabledActionPresentation = liveScoringShellPresentation.presentEnabledActionSet(enabledActions)

        let result = liveScoringCoordinator.refreshProjections(
            displayedAtbats: atbats,
            pitchers: pitchers,
            game: game,
            save: { try modelContext.save() }
        )

        let presentation = liveScoringShellPresentation.presentProjectionResult(result)

        colbox = presentation.columnBoxes
        batbox = presentation.batterBoxes
        totbox = presentation.totalBoxes
        iStat = presentation.inningStatus

        if let message = presentation.message {
            print(message)
        }
    }
    init(passedGame: Binding<Game>, teamName: String, searchString: String = "", sortOrder: [SortDescriptor<Atbat>] = [], theAtbats: Binding<[Atbat]>, isLoading: Binding<Bool>, hasChanged: Binding<Bool>, columnVisability: Binding<NavigationSplitViewVisibility>) {
        _game = passedGame
        _lAtbats = theAtbats
        _isLoading = isLoading
        _hasChanged = hasChanged
        _columnVisability = columnVisability

        let date = game.date
        let location = game.location
        _atbats = Query(filter: #Predicate { atbat in
            if searchString.isEmpty {
                atbat.team.name == teamName &&
                atbat.game.date == date &&
                atbat.game.location == location
            } else {
                atbat.team.name == teamName &&
                atbat.game.date == date &&
                atbat.game.location == location &&
                (atbat.player.name.localizedStandardContains(searchString)
                 || atbat.player.number.localizedStandardContains(searchString))
            }
        },  sort: sortOrder)
        _pitchers = Query(filter: #Predicate { pitcher in
            pitcher.game.date == date && pitcher.game.location == location
        })
    }
    private func opponentTeam(for battingTeam: Team) -> Team? {
        if battingTeam == game.hteam {
            return game.vteam
        }
        if battingTeam == game.vteam {
            return game.hteam
        }
        return nil
    }

    private func containsPlayer(_ player: Player, in players: [Player]) -> Bool {
        let playerID = player.persistentModelID
        return players.contains { $0.persistentModelID == playerID }
    }

    private func scorecardCellPresentation(
        column: Int,
        atbat: Atbat
    ) -> LiveScoringShellPresentation.EnabledActionPresentation {
        let identity = LiveScoringWorkflowCoordinator.ScoringActionIdentity.scorecardCell(
            column: column,
            battingOrder: atbat.batOrder
        )
        if let presentation = enabledActionPresentation?.state(for: identity) {
            return presentation
        }
        let enabled = liveScoringShellPresentation.scorecardCellIsEnabled(column: column, sourceAtbat: atbat)
        return LiveScoringShellPresentation.EnabledActionPresentation(
            identity: identity,
            isEnabled: enabled,
            accessibilityLabel: "Score batter \(atbat.batOrder), column \(column)",
            accessibilityHint: enabled ? nil : "Scorecard selection is unavailable.",
            warningMessage: nil
        )
    }

    private func teamForName(_ name: String) -> Team? {
        if game.hteam?.name == name {
            return game.hteam
        }
        if game.vteam?.name == name {
            return game.vteam
        }
        return nil
    }

    @discardableResult
    func doAtbat(ind:Int, index:Int, atbat:Atbat) -> LiveScoringShellPresentation.SelectionPresentation {
        let result = liveScoringCoordinator.selectAtbat(
            column: ind,
            rowIndex: index,
            sourceAtbat: atbat,
            displayedAtbats: atbats,
            game: game,
            modelContext: modelContext,
            save: { try modelContext.save() }
        )
        let presentation = liveScoringShellPresentation.presentSelectionResult(result)

        if let selectedAtbat = presentation.selectedAtbat, presentation.shouldPresentScoringSheet {
            theAtbat = selectedAtbat
        }
        showingScoring = presentation.shouldPresentScoringSheet
        hasChanged = presentation.shouldMarkChanged

        if let message = presentation.message {
            print(message)
        }

        return presentation
    }

    @discardableResult
    func submitScoringAction(_ result: String) -> LiveScoringShellPresentation.SubmissionPresentation {
        let battingTeam = theAtbat.team
        let displayedAtbats = atbats.contains(where: { $0.ident == theAtbat.ident }) ? atbats : atbats + [theAtbat]
        let submission = liveScoringCoordinator.submitScoringAction(
            legacyResult: result,
            targetAtbat: theAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: com.onresults + com.outresults,
            save: { try modelContext.save() }
        )
        let requiresAdditionalChoice = com.recOuts.contains(result) || theAtbat.outAt != "Safe"
        let presentation = liveScoringShellPresentation.presentSubmissionResult(
            submission,
            requiresAdditionalChoice: requiresAdditionalChoice
        )

        hasChanged = presentation.shouldMarkChanged
        if presentation.shouldDismissScoringSheet {
            showingScoring = false
        }
        refreshLiveScoringWorkflow()

        if let message = presentation.message {
            print(message)
        }

        return presentation
    }

    @discardableResult
    func prepareAdditionalChoiceScoringAction(_ result: String) -> LiveScoringShellPresentation.AdditionalChoicePresentation {
        let battingTeam = theAtbat.team
        let displayedAtbats = atbats.contains(where: { $0.ident == theAtbat.ident }) ? atbats : atbats + [theAtbat]
        let preparation = liveScoringCoordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: result,
            targetAtbat: theAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: com.onresults + com.outresults
        )
        let presentation = liveScoringShellPresentation.presentAdditionalChoicePreparation(preparation)

        hasChanged = presentation.shouldMarkChanged
        if let message = presentation.message {
            print(message)
        }

        return presentation
    }

    @discardableResult
    func submitAdditionalChoiceScoringAction(
        pendingChoice: LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice,
        choices: LiveScoringWorkflowCoordinator.AdditionalScoringChoices
    ) -> LiveScoringShellPresentation.SubmissionPresentation {
        let battingTeam = theAtbat.team
        let displayedAtbats = atbats.contains(where: { $0.ident == theAtbat.ident }) ? atbats : atbats + [theAtbat]
        let submission = liveScoringCoordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pendingChoice,
            choices: choices,
            targetAtbat: theAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: com.onresults + com.outresults,
            save: { try modelContext.save() }
        )
        let presentation = liveScoringShellPresentation.presentSubmissionResult(
            submission,
            requiresAdditionalChoice: false
        )

        hasChanged = presentation.shouldMarkChanged
        if presentation.shouldDismissScoringSheet {
            showingScoring = false
        }
        refreshLiveScoringWorkflow()

        if let message = presentation.message {
            print(message)
        }

        return presentation
    }

    private func semanticScoreLine(
        presentation: LiveScoringShellPresentation.SemanticScorePresentation,
        size: CGSize
    ) -> some View {
        let half = presentation.semanticScoreState.halfInning == .visiting ? "Top" : "Bottom"
        let text = "V \(presentation.visitingScore)  H \(presentation.homeScore)   \(half) \(presentation.inning)   \(presentation.outs) out\(presentation.outs == 1 ? "" : "s")"

        return Text(text)
            .font(.caption)
            .bold()
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.25), lineWidth: 1))
            .position(x: min(size.width - 120, max(120, size.width * 0.5)), y: 18)
    }
}
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}
