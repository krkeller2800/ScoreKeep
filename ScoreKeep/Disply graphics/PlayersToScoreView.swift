//
//  PlayersToScoreView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 8/29/25.
//

import SwiftUI
import SwiftData
import UIKit
struct PlayersToScoreView: View {
    @Environment(\.modelContext) var modelContext
    @Query var atbats: [Atbat]
    @Query var pitchers: [Pitcher]
    @Binding var lAtbats: [Atbat]
    @Binding var game: Game
    @Binding var isLoading: Bool
    @Binding var hasChanged: Bool
    @Binding var columnVisability:NavigationSplitViewVisibility
    @Binding var pitcherSectionScrollRequest: LiveScoringShellPresentation.PitcherSectionScrollRequest?
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
    @State private var ordinaryScoringOperationIdentity: UUID?
    @State private var ordinaryScoringIntentKey: String?
    @State private var isCorrectionEntry = false
    @State private var pendingPitcherSectionScrollRequest: LiveScoringShellPresentation.PitcherSectionScrollRequest?
    @State private var scorecardScrollController = ScorecardScrollController()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var highlightedCell: String? = nil
    @State private var invalidSelectionGuidanceToken: UUID?
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
                        Text("Num").frame(width:30, height: 15, alignment:.center).font(.caption).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold().padding(.leading, 3)
                        Text("Name").frame(width:50, height: 15, alignment:.leading).font(.caption).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold()
                        Spacer()
                    }
                    ScrollView() {
                            HStack {
                                VStack (spacing: 0){
                                    ForEach(Array(atbats.enumerated()), id: \.element.persistentModelID) { index, atbat in
                                        HStack(spacing: 2) {
                                            if ScorecardRenderedRows.isRenderedBattingRow(atbat) {
                                                let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                                let player = atbat.player
                                                let strikeIt = containsPlayer(player, in: game.replaced)
                                                let isIncoming = containsPlayer(player, in: game.incomings)
                                                let iName = isIncoming ? "    \(player.name)" : player.name
                                                Text(player.number).frame(width: 30, height: bSiz,alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                                    .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                                Text(iName).frame(width: 150, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).strikethrough(strikeIt)
                                                    .fixedSize(horizontal: true, vertical: true).padding(.leading,5).lineLimit(2)

                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                ScrollView(.horizontal) {
                                    ScrollViewReader { scrollProxy in
                                        ZStack {
                                    let bigCol = atbats.filter{$0.result != "Result"}.max { $0.col < $1.col }
                                    let gridSz = CGFloat(gWidth > 1100 ? 60 : 50)
                                    let bSize = Int(((gWidth - (gWidth > 1100 ? 425 : 325)) / gridSz).rounded(.down))
                                    let newCol = (bigCol?.col ?? 1) + 1
                                    let maxCol = newCol < bSize ? bSize : newCol
                                    VStack (spacing: 0) {
                                        ForEach(Array(atbats.enumerated()), id: \.element.persistentModelID) { index, atbat in
                                            HStack(spacing: 0) {
                                                if ScorecardRenderedRows.isRenderedBattingRow(atbat) {
                                                    ForEach((1...maxCol), id: \.self) {ind in
                                                        let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                                        let cellId = LiveScoringWorkflowCoordinator.RenderedScorecardCellTarget.uiIdentifier(
                                                            renderedRowIdentity: atbat.ident,
                                                            column: ind
                                                        )
                                                        let isHighlighted = highlightedCell == cellId
                                                        let cellPresentation = scorecardCellPresentation(column: ind, atbat: atbat)
                                                        ScorecardCellView(
                                                            atbat: atbat,
                                                            ind: ind,
                                                            bSiz: bSiz,
                                                            cellId: cellId,
                                                            isHighlighted: isHighlighted,
                                                            cellPresentation: cellPresentation,
                                                            action: {
                                                                doAtbat(ind: ind, index: index, atbat: atbat)
                                                            }
                                                        )
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
                                        drawPitchers(
                                            space: calcSpace(gWidth:gWidth),
                                            atbats: atbats,
                                            abb: "",
                                            inning: 1,
                                            game: game,
                                            team: opTeam,
                                            width: gWidth
                                        )
                                    }
                                }
                                .onChange(of: highlightedCell) { _, newValue in
                                    if let target = newValue {
                                        withAnimation {
                                            scrollProxy.scrollTo(target, anchor: .center)
                                        }
                                    }
                                }
                                    }
                                }
                                .coordinateSpace(name: "scroll")
                            }
                            .background(
                                ScorecardScrollViewObserver(controller: scorecardScrollController)
                            )
                        }
                        .coordinateSpace(name: "pitcher_vertical_scroll")
                        .onChange(of: pitcherSectionScrollRequest) { _, request in
                            guard let request else { return }
                            pendingPitcherSectionScrollRequest = request
                            scorecardScrollController.prepareForPitcherSectionScroll(requestID: request.identity)
                            refreshLiveScoringWorkflow()
                            scrollToPendingPitcherSectionIfAvailable()
                        }
                        .onChange(of: pitchers.map { $0.player.identifier }) { _, _ in
                            refreshLiveScoringWorkflow()
                            scrollToPendingPitcherSectionIfAvailable()
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // <5>
                .accessibilityIdentifier("live_scoring_root")
                .overlay(alignment: .top) {
                    if showingAlert {
                        InvalidScorecardSelectionBanner(message: alertMessage)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                    }
                }
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
                    submitAdditionalChoiceScoringAction: submitAdditionalChoiceScoringAction,
                    isCorrectionEntry: isCorrectionEntry,
                    submitCorrectionEntry: { replacement in
                        let target = LiveScoringWorkflowCoordinator.LegacyCorrectionTarget(
                            gameIdentity: game.ident,
                            atbatIdentity: theAtbat.ident,
                            expectedOriginal: nil
                        )
                        let submission = liveScoringCoordinator.submitCorrection(
                            target: target,
                            replacement: replacement,
                            displayedAtbats: atbats,
                            pitchers: pitchers,
                            modelContext: modelContext,
                            save: { try modelContext.save() }
                        )
                        if let refreshedState = submission.refreshedState, submission.disposition == .accepted {
                            preparedLiveGameState = refreshedState
                            refreshLiveScoringWorkflow()
                        }
                        isCorrectionEntry = false
                    }
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
                    }
                } catch {
                    #if DEBUG
                    print("Error: \(error.localizedDescription)")
                    #endif
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
            #if DEBUG
            print(message)
            #endif
        }
        let semanticState = liveScoringCoordinator.semanticScoreState(
            preparedState: preparedPresentation.preparedState,
            displayedAtbats: atbats
        )
        let scorePresentation = liveScoringShellPresentation.presentSemanticScoreState(semanticState)
        semanticScorePresentation = scorePresentation
        if let message = scorePresentation.message {
            #if DEBUG
            print(message)
            #endif
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
            maintainPitcherMarkers: preparedPresentation.preparedState.canScore && preparedPresentation.preparedState.currentOrPendingLegacyAtbat != nil,
            save: { try modelContext.save() }
        )

        let presentation = liveScoringShellPresentation.presentProjectionResult(result)

        colbox = presentation.columnBoxes
        batbox = presentation.batterBoxes
        totbox = presentation.totalBoxes
        iStat = presentation.inningStatus

        if let message = presentation.message {
            #if DEBUG
            print(message)
            #endif
        }
    }
    init(
        passedGame: Binding<Game>,
        teamName: String,
        searchString: String = "",
        sortOrder: [SortDescriptor<Atbat>] = [],
        theAtbats: Binding<[Atbat]>,
        isLoading: Binding<Bool>,
        hasChanged: Binding<Bool>,
        columnVisability: Binding<NavigationSplitViewVisibility>,
        pitcherSectionScrollRequest: Binding<LiveScoringShellPresentation.PitcherSectionScrollRequest?> = .constant(nil)
    ) {
        _game = passedGame
        _lAtbats = theAtbats
        _isLoading = isLoading
        _hasChanged = hasChanged
        _columnVisability = columnVisability
        _pitcherSectionScrollRequest = pitcherSectionScrollRequest

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

    private func scrollToPendingPitcherSectionIfAvailable() {
        guard let request = pendingPitcherSectionScrollRequest else { return }
        guard pitcherRowTargetExists(for: request) else { return }

        let didBeginScroll = scorecardScrollController.markPitcherSectionRendered(for: request.identity)
        if didBeginScroll {
            pendingPitcherSectionScrollRequest = nil
            pitcherSectionScrollRequest = nil
        }
    }

    private func pitcherRowTargetExists(for request: LiveScoringShellPresentation.PitcherSectionScrollRequest) -> Bool {
        pitchers.contains {
            LiveScoringShellPresentation.pitcherRowScrollTargetID(for: $0.player.identifier) == request.targetID
        }
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
        if let enabledActionPresentation {
            return enabledActionPresentation.scorecardCellState(
                column: column,
                sourceAtbat: atbat,
                displayedAtbats: atbats
            )
        }
        let enabled = liveScoringShellPresentation.scorecardCellIsEnabled(column: column, sourceAtbat: atbat)
        return LiveScoringShellPresentation.EnabledActionPresentation(
            identity: identity,
            isEnabled: enabled,
            accessibilityLabel: "Scorecard cell",
            accessibilityValue: "Batter \(atbat.batOrder), scorecard column \(column), \(enabled ? "available" : "unavailable")",
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
            clearInvalidSelectionGuidance()
            theAtbat = selectedAtbat
            isCorrectionEntry = selectedAtbat.result != "Result"
            resetScoringOperationIdentity()
        } else {
            isCorrectionEntry = false
        }
        showingScoring = presentation.shouldPresentScoringSheet
        hasChanged = presentation.shouldMarkChanged

        if let message = presentation.message {
            #if DEBUG
            print(message)
            #endif
            if !presentation.shouldPresentScoringSheet {
                alertMessage = message
                showingAlert = true
                let guidanceToken = restartInvalidSelectionGuidanceTimer()

                if let renderedTarget = presentation.renderedTarget {
                    let targetId = renderedTarget.uiIdentifier
                    highlightedCell = targetId
                } else if let targetAction = presentation.targetAction {
                    if case .scorecardCell(let column, let battingOrder) = targetAction {
                        let targetId = "scorecard_cell_\(battingOrder)_\(column)"
                        highlightedCell = targetId
                    }
                }
                hideInvalidSelectionGuidance(after: .now() + 5, token: guidanceToken)
            }
        }

        return presentation
    }

    private func restartInvalidSelectionGuidanceTimer() -> UUID {
        let token = UUID()
        invalidSelectionGuidanceToken = token
        return token
    }

    private func hideInvalidSelectionGuidance(after deadline: DispatchTime, token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            guard invalidSelectionGuidanceToken == token else { return }
            clearInvalidSelectionGuidance()
        }
    }

    private func clearInvalidSelectionGuidance() {
        invalidSelectionGuidanceToken = nil
        showingAlert = false
        highlightedCell = nil
    }



    @discardableResult
    func submitScoringAction(_ result: String) -> LiveScoringShellPresentation.SubmissionPresentation {
        let battingTeam = theAtbat.team
        let displayedAtbats = atbats.contains(where: { $0.ident == theAtbat.ident }) ? atbats : atbats + [theAtbat]
        let operationIdentity = operationIdentityForOrdinarySubmission(result)
        let submission = liveScoringCoordinator.submitScoringAction(
            legacyResult: result,
            targetAtbat: theAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: com.onresults + com.outresults,
            save: { try modelContext.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: modelContext.container),
            modelContext: modelContext
        )
        let requiresAdditionalChoice = com.recOuts.contains(result) || theAtbat.outAt != "Safe"
        let presentation = liveScoringShellPresentation.presentSubmissionResult(
            submission,
            requiresAdditionalChoice: requiresAdditionalChoice
        )

        hasChanged = presentation.shouldMarkChanged
        if presentation.shouldDismissScoringSheet {
            showingScoring = false
            isCorrectionEntry = false
            resetScoringOperationIdentity()
        }
        refreshLiveScoringWorkflow()

        if let message = presentation.message {
            #if DEBUG
            print(message)
            #endif
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
            #if DEBUG
            print(message)
            #endif
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
            save: { try modelContext.save() },
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: modelContext.container),
            modelContext: modelContext
        )
        let presentation = liveScoringShellPresentation.presentSubmissionResult(
            submission,
            requiresAdditionalChoice: false
        )

        hasChanged = presentation.shouldMarkChanged
        if presentation.shouldDismissScoringSheet {
            showingScoring = false
            isCorrectionEntry = false
            resetScoringOperationIdentity()
        }
        refreshLiveScoringWorkflow()

        if let message = presentation.message {
            #if DEBUG
            print(message)
            #endif
        }

        return presentation
    }

    private func operationIdentityForOrdinarySubmission(_ result: String) -> UUID {
        let intentKey = [
            game.ident.uuidString.lowercased(),
            theAtbat.ident.uuidString.lowercased(),
            LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            result
        ].joined(separator: "|")
        if ordinaryScoringIntentKey == intentKey, let ordinaryScoringOperationIdentity {
            return ordinaryScoringOperationIdentity
        }
        let identity = UUID()
        ordinaryScoringIntentKey = intentKey
        ordinaryScoringOperationIdentity = identity
        return identity
    }

    private func resetScoringOperationIdentity() {
        ordinaryScoringIntentKey = nil
        ordinaryScoringOperationIdentity = nil
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
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ScoreKeepVisualStyle.elevatedSurface.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ScoreKeepVisualStyle.separator, lineWidth: 1))
            .position(x: min(size.width - 120, max(120, size.width * 0.5)), y: 18)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityValue(presentation.accessibilityValue)
            .accessibilityAddTraits(.isStaticText)
    }

    private func announce(_ message: String?) {
        guard let message, !message.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}


struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct InvalidScorecardSelectionBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ScoreKeepVisualStyle.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("invalid_scorecard_selection_banner")
    }
}

struct ScorecardCellView: View {
    let atbat: Atbat
    let ind: Int
    let bSiz: CGFloat
    let cellId: String
    let isHighlighted: Bool
    let cellPresentation: LiveScoringShellPresentation.EnabledActionPresentation
    let action: () -> Void

    static func invalidGuidanceBorderVerticalOffset(for cellSize: CGFloat) -> CGFloat {
        0
    }

    static func invalidGuidanceCueVerticalOffset(for cellSize: CGFloat) -> CGFloat {
        cellSize / 2 - 25
    }

    var body: some View {
        let invalidGuidanceBorderVerticalOffset = Self.invalidGuidanceBorderVerticalOffset(for: bSiz)
        let invalidGuidanceCueVerticalOffset = Self.invalidGuidanceCueVerticalOffset(for: bSiz)

        Button(action: action) {
            Image("field").resizable().scaledToFit()
        }
        .frame(width: bSiz, height: bSiz)
        .buttonStyle(GlowButtonStyle())
        .disabled(!cellPresentation.isEnabled)
        .accessibilityLabel(cellPresentation.accessibilityLabel)
        .accessibilityValue(cellPresentation.accessibilityValue ?? "")
        .accessibilityHint(cellPresentation.accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(cellId)
        .id(cellId)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.yellow, lineWidth: isHighlighted ? 3 : 0)
                .offset(y: isHighlighted ? invalidGuidanceBorderVerticalOffset : 0)
        )
        .overlay(
            Group {
                if isHighlighted {
                    Text("Next at-bat")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.yellow.opacity(0.9))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .offset(y: invalidGuidanceCueVerticalOffset)
                }
            }
        )
    }
}

struct ScorecardScrollViewObserver: UIViewRepresentable {
    let controller: ScorecardScrollController

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.controller = controller
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {
        uiView.controller = controller
        uiView.attachToEnclosingScrollViewSoon()
    }

    final class ObserverView: UIView {
        var controller: ScorecardScrollController?
        private weak var observedScrollView: UIScrollView?
        private var contentSizeObservation: NSKeyValueObservation?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            attachToEnclosingScrollViewSoon()
        }

        func attachToEnclosingScrollViewSoon() {
            DispatchQueue.main.async { [weak self] in
                self?.attachToEnclosingScrollView()
            }
        }

        private func attachToEnclosingScrollView() {
            guard let scrollView = firstEnclosingScrollView() else { return }
            guard scrollView !== observedScrollView else { return }

            contentSizeObservation?.invalidate()
            observedScrollView = scrollView
            controller?.attach(scrollView)
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.initial, .new]) { [weak self, weak scrollView] _, _ in
                guard let self, let scrollView else { return }
                self.controller?.recordLayoutChange(scrollView)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let observedScrollView {
                controller?.recordLayoutChange(observedScrollView)
            }
        }

        private func firstEnclosingScrollView() -> UIScrollView? {
            var candidate = superview
            while let view = candidate {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                }
                candidate = view.superview
            }
            return nil
        }

        deinit {
            contentSizeObservation?.invalidate()
        }
    }
}

final class ScorecardScrollController {
    private weak var scrollView: UIScrollView?
    private var pendingRequestID: UUID?
    private var renderedRequestIDs: Set<UUID> = []
    private var completedRequestIDs: Set<UUID> = []

    func attach(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
        attemptPendingScroll()
    }

    func recordLayoutChange(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
        attemptPendingScroll()
    }

    func prepareForPitcherSectionScroll(requestID: UUID) {
        pendingRequestID = requestID
        attemptPendingScroll()
    }

    @discardableResult
    func markPitcherSectionRendered(for requestID: UUID) -> Bool {
        renderedRequestIDs.insert(requestID)
        return attemptPendingScroll()
    }

    func hasCompletedScroll(for requestID: UUID) -> Bool {
        completedRequestIDs.contains(requestID)
    }

    @discardableResult
    private func attemptPendingScroll() -> Bool {
        guard let requestID = pendingRequestID,
              renderedRequestIDs.contains(requestID),
              !completedRequestIDs.contains(requestID),
              let scrollView else {
            return false
        }

        let targetOffset = Self.scorecardBottomOffset(
            contentSize: scrollView.contentSize,
            boundsSize: scrollView.bounds.size,
            adjustedContentInset: scrollView.adjustedContentInset,
            currentOffset: scrollView.contentOffset
        )
        guard let targetOffset else { return false }

        completedRequestIDs.insert(requestID)
        pendingRequestID = nil
        scrollView.setContentOffset(targetOffset, animated: true)
        return true
    }

    static func scorecardBottomOffset(
        contentSize: CGSize,
        boundsSize: CGSize,
        adjustedContentInset: UIEdgeInsets,
        currentOffset: CGPoint
    ) -> CGPoint? {
        guard contentSize.height > 0, boundsSize.height > 0 else { return nil }

        let maxY = max(-adjustedContentInset.top, contentSize.height - boundsSize.height + adjustedContentInset.bottom)
        guard abs(currentOffset.y - maxY) > 0.5 else { return nil }

        return CGPoint(x: currentOffset.x, y: maxY)
    }
}
