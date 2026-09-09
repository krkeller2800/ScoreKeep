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
    @Query var players: [Player]
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
    @State private var maintainPitcherMarkersAfterScoringSubmission = false
    @State private var pendingPitcherSectionScrollRequest: LiveScoringShellPresentation.PitcherSectionScrollRequest?
    @State private var scorecardScrollController = ScorecardScrollController()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var highlightedCell: String? = nil
    @State private var invalidSelectionGuidanceToken: UUID?
    @State private var invalidSelectionBannerSize: CGSize = .zero
    @State private var scorecardCellFrames: [String: CGRect] = [:]
    @State private var pendingInvalidSelectionHintTargetID: String?
    @State private var pendingInvalidSelectionVerticalTargetID: String?
    @State private var pendingInvalidSelectionHintMessage = ""
    @State private var pendingInvalidSelectionHintToken: UUID?
    @State private var pendingInvalidSelectionScrollRequested = false
    @State private var pendingInvalidSelectionScrollRequestID: UUID?
    @State private var showingAddPlayerDraft = false
    @State private var pendingScorecardCorrectionSlot: Int?
    @State private var pendingScorecardCorrectionTeam: Team?
    private let inningHeaderPitcherSummaryClearance: CGFloat = 24
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
                let battingTeam = atbats.first?.team ?? teamForName(teamName)
                let lineupSlots = battingTeam.map {
                    LineupSlotSafetyCoordinator.resolvedSlots(
                        game: game,
                        team: $0,
                        modelContext: modelContext
                    )
                } ?? []
                let identityRailWidth = Self.scorecardIdentityRailWidth(forWidth: gWidth)
                let identityDeviceClass = Self.scorecardIdentityDeviceClass(forWidth: gWidth)
                drawIndicator(iStat:iStat,size:geometry.size,colbox:colbox,space:calcSpace(gWidth: gWidth))
                drawBoxScore(game:game,size:geometry.size)
                if let semanticScorePresentation {
                    semanticScoreLine(presentation: semanticScorePresentation, size: geometry.size)
                }
                VStack ( spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Player")
                            .frame(width: identityRailWidth, height: 15, alignment:.leading)
                            .font(.caption)
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                            .bold()
                            .padding(.leading, 5)
                        Spacer()
                    }
                    ScrollViewReader { verticalScrollProxy in
                        ScrollView() {
                            HStack {
                                VStack (spacing: 0){
                                    ForEach(Array(atbats.enumerated()), id: \.element.persistentModelID) { index, atbat in
                                        HStack(spacing: 2) {
                                            if ScorecardRenderedRows.isRenderedBattingRow(atbat) {
                                                let bSiz:CGFloat = gWidth > 1100 ? 60 : 50
                                                scorecardPlayerIdentityCell(
                                                    for: atbat,
                                                    slots: lineupSlots,
                                                    deviceClass: identityDeviceClass,
                                                    height: bSiz,
                                                    width: identityRailWidth
                                                )

                                            }
                                        }
                                        .id(Self.scorecardRowScrollTargetID(for: atbat.ident))
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
                                                        .background(
                                                            GeometryReader { cellProxy in
                                                                Color.clear.preference(
                                                                    key: ScorecardCellFramePreferenceKey.self,
                                                                    value: [cellId: cellProxy.frame(in: .named("live_scoring_root"))]
                                                                )
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
                                    guard let target = newValue else { return }
                                    if UIDevice.type == "iPhone" {
                                        handleInvalidSelectionTargetChange(
                                            targetID: target,
                                            viewportSize: geometry.size,
                                            horizontalScrollProxy: scrollProxy,
                                            verticalScrollProxy: verticalScrollProxy
                                        )
                                    } else {
                                        withAnimation {
                                            scrollProxy.scrollTo(target, anchor: .center)
                                        }
                                    }
                                }
                                .onChange(of: pendingInvalidSelectionScrollRequestID) { _, _ in
                                    guard UIDevice.type == "iPhone",
                                          let target = pendingInvalidSelectionHintTargetID else { return }
                                    handleInvalidSelectionTargetChange(
                                        targetID: target,
                                        viewportSize: geometry.size,
                                        horizontalScrollProxy: scrollProxy,
                                        verticalScrollProxy: verticalScrollProxy
                                    )
                                }
                                    }
                                }
                                .coordinateSpace(name: "scroll")
                            }
                            .background(
                                ScorecardScrollViewObserver(controller: scorecardScrollController)
                            )
                        }
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
                .overlayPreferenceValue(PitcherInningsTrackingTableBoundsPreferenceKey.self) { tableBounds in
                    GeometryReader { proxy in
                        let visibleHeight = tableBounds.map { max(0, proxy[$0].minY - inningHeaderPitcherSummaryClearance) } ?? proxy.size.height
                        drawInnings(game: game, atbats: atbats, space: calcSpace(gWidth: gWidth), offset: offset, gWidth: gWidth)
                            .allowsHitTesting(false)
                            .mask(
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .frame(height: visibleHeight)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // <5>
                .coordinateSpace(name: "live_scoring_root")
                .accessibilityIdentifier("live_scoring_root")
                .onPreferenceChange(ScorecardCellFramePreferenceKey.self) { frames in
                    scorecardCellFrames = frames
                    showPendingInvalidSelectionHintIfTargetVisible(
                        cellFrames: frames,
                        viewportSize: geometry.size
                    )
                }
                .overlayPreferenceValue(ScorecardCellFramePreferenceKey.self) { cellFrames in
                    GeometryReader { proxy in
                        if showingAlert {
                            let targetFrame = highlightedCell.flatMap { cellFrames[$0] }
                            let placement = InvalidScorecardSelectionBanner.placement(
                                for: targetFrame,
                                bannerSize: invalidSelectionBannerSize,
                                viewportSize: proxy.size
                            )
                            InvalidScorecardSelectionBanner(message: alertMessage)
                                .background(
                                    GeometryReader { bannerProxy in
                                        Color.clear.preference(
                                            key: InvalidScorecardSelectionBannerSizePreferenceKey.self,
                                            value: bannerProxy.size
                                        )
                                    }
                                )
                                .position(placement)
                                .transition(.opacity)
                                .zIndex(1)
                                .onPreferenceChange(InvalidScorecardSelectionBannerSizePreferenceKey.self) { size in
                                    invalidSelectionBannerSize = size
                                }
                        }
                    }
                }
                .onAppear() {
                    screenSize = geometry.size
                    lAtbats = atbats
                }
                .onChange(of: geometry.size) { _, newSize in
                    screenSize = newSize
                    showPendingInvalidSelectionHintIfTargetVisible(
                        cellFrames: scorecardCellFrames,
                        viewportSize: newSize
                    )
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
            .sheet(isPresented: $showingAddPlayerDraft) {
                if let pendingScorecardCorrectionTeam {
                    NavigationStack {
                        AddPlayerDraftView(team: pendingScorecardCorrectionTeam) { savedPlayer in
                            assignSavedScorecardPlayer(savedPlayer)
                        }
                    }
                    .standardAddPlayerPresentation()
                }
            }
            .onChange(of: showingAddPlayerDraft) {
                if showingAddPlayerDraft == false {
                    pendingScorecardCorrectionSlot = nil
                    pendingScorecardCorrectionTeam = nil
                }
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

        let shouldMaintainPitcherMarkers = liveScoringCoordinator.shouldMaintainPitcherMarkers(
            preparedState: preparedPresentation.preparedState,
            afterScoringSubmission: maintainPitcherMarkersAfterScoringSubmission
        )
        maintainPitcherMarkersAfterScoringSubmission = false

        let result = liveScoringCoordinator.refreshProjections(
            displayedAtbats: atbats,
            pitchers: pitchers,
            game: game,
            maintainPitcherMarkers: shouldMaintainPitcherMarkers,
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
        _players = Query(sort: [SortDescriptor(\Player.batOrder), SortDescriptor(\Player.name)])
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

    @ViewBuilder
    private func scorecardPlayerIdentityCell(
        for atbat: Atbat,
        slots: [LineupSlot],
        deviceClass: ScorecardPlayerIdentityDeviceClass,
        height: CGFloat,
        width: CGFloat
    ) -> some View {
        let player = atbat.player
        let strikeIt = containsPlayer(player, in: game.replaced)
        let isIncoming = containsPlayer(player, in: game.incomings)
        let slot = Self.scorecardLineupSlot(for: atbat, slots: slots)
        let isEditable = slot?.isEditable == true
        let isLocked = slot.map { $0.isEditable == false } ?? false
        let presentation = ScorecardPlayerIdentityPolicy.presentation(
            for: player,
            battingOrder: atbat.batOrder,
            deviceClass: deviceClass,
            isIncoming: isIncoming,
            isReplaced: strikeIt,
            isEditable: isEditable,
            isLocked: isLocked
        )

        if let slot, slot.isEditable {
            Menu {
                ForEach(scorecardPlayerMenuItems(for: slot, team: atbat.team, slots: slots)) { item in
                    switch item {
                    case .addPlayer:
                        Button {
                            beginScorecardAddPlayer(for: slot, team: atbat.team)
                        } label: {
                            Label("Add Player…", systemImage: "plus")
                        }
                    case .player(let player, let isSelected):
                        Button {
                            selectScorecardPlayer(player, for: slot, team: atbat.team)
                        } label: {
                            PlayerMenuRowLabel(player: player, isSelected: isSelected)
                        }
                    }
                }
            } label: {
                ScorecardPlayerIdentityView(
                    presentation: presentation,
                    isIncoming: isIncoming,
                    isReplaced: strikeIt,
                    showsMenuIndicator: true
                )
                .frame(width: width, height: height, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
            .accessibilityIdentifier("scorecard-player-picker-\(slot.battingOrder)")
        } else {
            ScorecardPlayerIdentityView(
                presentation: presentation,
                isIncoming: isIncoming,
                isReplaced: strikeIt,
                showsMenuIndicator: false
            )
            .frame(width: width, height: height, alignment: .leading)
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
            .accessibilityIdentifier("scorecard-player-identity-\(atbat.batOrder)")
            .accessibilityHint(isLocked ? "Locked after game participation." : "")
        }
    }

    static func scorecardLineupSlot(for atbat: Atbat, slots: [LineupSlot]) -> LineupSlot? {
        slots.first {
            $0.battingOrder == atbat.batOrder &&
                $0.placeholderAtbat.ident == atbat.ident &&
                $0.player.identifier == atbat.player.identifier
        }
    }

    private func scorecardPlayerMenuItems(for slot: LineupSlot, team: Team, slots: [LineupSlot]) -> [StartingLineupPlayerMenuItem] {
        Self.scorecardPlayerMenuItems(
            from: players,
            slots: slots,
            targetSlot: slot,
            team: team
        )
    }

    static func scorecardPlayerMenuItems(from players: [Player], slots: [LineupSlot], targetSlot: LineupSlot, team: Team) -> [StartingLineupPlayerMenuItem] {
        StartingLineupView.playerMenuItems(
            from: players,
            slots: slots,
            targetSlot: targetSlot,
            team: team,
            context: .scorecardSwapCorrection
        )
    }

    private func beginScorecardAddPlayer(for slot: LineupSlot, team: Team) {
        pendingScorecardCorrectionSlot = slot.battingOrder
        pendingScorecardCorrectionTeam = team
        showingAddPlayerDraft = true
    }

    private func selectScorecardPlayer(_ player: Player, for slot: LineupSlot, team: Team) {
        guard player.identifier != slot.player.identifier else { return }
        do {
            let slots = LineupSlotSafetyCoordinator.resolvedSlots(game: game, team: team, modelContext: modelContext)
            if let occupiedSlot = slots.first(where: { $0.battingOrder != slot.battingOrder && $0.player.identifier == player.identifier }) {
                _ = try LineupSlotSafetyCoordinator.swapPlayers(
                    in: slot.battingOrder,
                    withPlayerIn: occupiedSlot.battingOrder,
                    game: game,
                    team: team,
                    modelContext: modelContext,
                    updateTeamDefaultOrder: true
                )
            } else {
                _ = try LineupSlotSafetyCoordinator.reassignPlayer(
                    in: slot.battingOrder,
                    to: player,
                    game: game,
                    team: team,
                    modelContext: modelContext,
                    updateTeamDefaultOrder: true
                )
            }
            lAtbats = atbats
            hasChanged = true
            refreshLiveScoringWorkflow()
        } catch {
            showInvalidSelectionGuidance(message: error.localizedDescription, token: restartInvalidSelectionGuidanceTimer())
        }
    }

    private func assignSavedScorecardPlayer(_ player: Player) {
        defer {
            pendingScorecardCorrectionSlot = nil
            pendingScorecardCorrectionTeam = nil
            refreshLiveScoringWorkflow()
        }
        guard let slot = pendingScorecardCorrectionSlot,
              let team = pendingScorecardCorrectionTeam else { return }
        do {
            _ = try LineupSlotSafetyCoordinator.reassignPlayer(
                in: slot,
                to: player,
                game: game,
                team: team,
                modelContext: modelContext,
                updateTeamDefaultOrder: true
            )
            lAtbats = atbats
            hasChanged = true
        } catch {
            showInvalidSelectionGuidance(
                message: "The Player was added to the roster, but this lineup slot can no longer be changed.",
                token: restartInvalidSelectionGuidanceTimer()
            )
        }
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
                let guidanceToken = restartInvalidSelectionGuidanceTimer()
                let targetId = invalidSelectionGuidanceTargetID(for: presentation)

                if let targetId {
                    highlightedCell = targetId
                }

                let canLocateTargetFrame = presentation.renderedTarget != nil || targetId.flatMap { scorecardCellFrames[$0] } != nil
                if UIDevice.type == "iPhone", let targetId, canLocateTargetFrame {
                    if Self.scorecardCellFrameIsFullyVisible(scorecardCellFrames[targetId], in: screenSize) {
                        showInvalidSelectionGuidance(message: message, token: guidanceToken)
                    } else {
                        pendingInvalidSelectionHintTargetID = targetId
                        pendingInvalidSelectionVerticalTargetID = invalidSelectionGuidanceVerticalTargetID(for: presentation)
                        pendingInvalidSelectionHintMessage = message
                        pendingInvalidSelectionHintToken = guidanceToken
                        pendingInvalidSelectionScrollRequested = false
                        pendingInvalidSelectionScrollRequestID = UUID()
                        showingAlert = false
                    }
                } else {
                    showInvalidSelectionGuidance(message: message, token: guidanceToken)
                }
            }
        }

        return presentation
    }

    private func invalidSelectionGuidanceTargetID(
        for presentation: LiveScoringShellPresentation.SelectionPresentation
    ) -> String? {
        if let renderedTarget = presentation.renderedTarget {
            return renderedTarget.uiIdentifier
        }

        if let targetCell = presentation.targetCell {
            return targetCell.uiIdentifier
        }

        if let targetAction = presentation.targetAction,
           case .scorecardCell(let column, let battingOrder) = targetAction {
            return "scorecard_cell_\(battingOrder)_\(column)"
        }

        return nil
    }

    private func invalidSelectionGuidanceVerticalTargetID(
        for presentation: LiveScoringShellPresentation.SelectionPresentation
    ) -> String? {
        guard let renderedTarget = presentation.renderedTarget else { return nil }
        return Self.scorecardRowScrollTargetID(for: renderedTarget.renderedRowIdentity)
    }

    static func scorecardRowScrollTargetID(for rowIdentity: UUID) -> String {
        "scorecard_rendered_row_\(rowIdentity.uuidString)"
    }

    private func handleInvalidSelectionTargetChange(
        targetID: String,
        viewportSize: CGSize,
        horizontalScrollProxy: ScrollViewProxy,
        verticalScrollProxy: ScrollViewProxy
    ) {
        guard pendingInvalidSelectionHintTargetID == targetID else { return }

        if Self.scorecardCellFrameIsFullyVisible(scorecardCellFrames[targetID], in: viewportSize) {
            showPendingInvalidSelectionHintIfTargetVisible(
                cellFrames: scorecardCellFrames,
                viewportSize: viewportSize
            )
            return
        }

        guard !pendingInvalidSelectionScrollRequested else { return }
        pendingInvalidSelectionScrollRequested = true
        let scrollAxes = Self.invalidSelectionRecoveryScrollAxes(
            for: scorecardCellFrames[targetID],
            in: viewportSize
        )
        withAnimation {
            if scrollAxes.horizontal {
                horizontalScrollProxy.scrollTo(targetID, anchor: .center)
            }
            if scrollAxes.vertical {
                verticalScrollProxy.scrollTo(pendingInvalidSelectionVerticalTargetID ?? targetID, anchor: .center)
            }
        }
    }

    private func showPendingInvalidSelectionHintIfTargetVisible(
        cellFrames: [String: CGRect],
        viewportSize: CGSize
    ) {
        guard let targetID = pendingInvalidSelectionHintTargetID,
              let token = pendingInvalidSelectionHintToken,
              Self.scorecardCellFrameIsFullyVisible(cellFrames[targetID], in: viewportSize) else {
            return
        }

        let message = pendingInvalidSelectionHintMessage
        pendingInvalidSelectionHintTargetID = nil
        pendingInvalidSelectionVerticalTargetID = nil
        pendingInvalidSelectionHintMessage = ""
        pendingInvalidSelectionHintToken = nil
        pendingInvalidSelectionScrollRequested = false
        showInvalidSelectionGuidance(message: message, token: token)
    }

    static func scorecardCellFrameIsFullyVisible(_ frame: CGRect?, in viewportSize: CGSize) -> Bool {
        guard let frame,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return false
        }

        return CGRect(origin: .zero, size: viewportSize).contains(frame)
    }

    static func scorecardIdentityRailWidth(forWidth width: CGFloat) -> CGFloat {
        width > 1100 ? 190 : 180
    }

    static func scorecardIdentityDeviceClass(forWidth width: CGFloat) -> ScorecardPlayerIdentityDeviceClass {
        width > 1100 ? .iPadLandscape : .iPhoneLandscape
    }

    static func invalidSelectionRecoveryScrollAxes(
        for frame: CGRect?,
        in viewportSize: CGSize
    ) -> ScorecardRecoveryScrollAxes {
        guard let frame,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return ScorecardRecoveryScrollAxes(horizontal: true, vertical: true)
        }

        let viewport = CGRect(origin: .zero, size: viewportSize)
        return ScorecardRecoveryScrollAxes(
            horizontal: frame.minX < viewport.minX || frame.maxX > viewport.maxX,
            vertical: frame.minY < viewport.minY || frame.maxY > viewport.maxY
        )
    }

    private func restartInvalidSelectionGuidanceTimer() -> UUID {
        let token = UUID()
        invalidSelectionGuidanceToken = token
        return token
    }

    private func showInvalidSelectionGuidance(message: String, token: UUID) {
        guard invalidSelectionGuidanceToken == token else { return }
        alertMessage = message
        showingAlert = true
        hideInvalidSelectionGuidance(after: .now() + 5, token: token)
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
        pendingInvalidSelectionHintTargetID = nil
        pendingInvalidSelectionVerticalTargetID = nil
        pendingInvalidSelectionHintMessage = ""
        pendingInvalidSelectionHintToken = nil
        pendingInvalidSelectionScrollRequested = false
        pendingInvalidSelectionScrollRequestID = nil
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
        maintainPitcherMarkersAfterScoringSubmission = submission.disposition == .accepted
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
        maintainPitcherMarkersAfterScoringSubmission = submission.disposition == .accepted
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

struct ScorecardCellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct InvalidScorecardSelectionBannerSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ScorecardRecoveryScrollAxes: Equatable {
    let horizontal: Bool
    let vertical: Bool
}

struct InvalidScorecardSelectionBanner: View {
    let message: String

    static func placement(
        for targetFrame: CGRect?,
        bannerSize: CGSize,
        viewportSize: CGSize,
        margin: CGFloat = 12,
        cellSpacing: CGFloat = 8
    ) -> CGPoint {
        let resolvedBannerSize = CGSize(
            width: bannerSize.width > 0 ? bannerSize.width : min(320, max(0, viewportSize.width - margin * 2)),
            height: bannerSize.height > 0 ? bannerSize.height : 72
        )
        let halfWidth = resolvedBannerSize.width / 2
        let halfHeight = resolvedBannerSize.height / 2
        let minX = margin + halfWidth
        let maxX = max(minX, viewportSize.width - margin - halfWidth)
        let minY = margin + halfHeight
        let maxY = max(minY, viewportSize.height - margin - halfHeight)

        guard let targetFrame else {
            return CGPoint(
                x: min(max(viewportSize.width / 2, minX), maxX),
                y: minY
            )
        }

        let preferredY = targetFrame.minY - cellSpacing - halfHeight
        let fallbackY = targetFrame.maxY + cellSpacing + halfHeight
        let y = preferredY >= minY ? preferredY : min(max(fallbackY, minY), maxY)
        let x = min(max(targetFrame.midX, minX), maxX)

        return CGPoint(x: x, y: y)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .foregroundColor(.accentColor)
                .font(.title3)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ScoreKeepVisualStyle.elevatedSurface)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
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
    private var deferredScrollRequestIDs: Set<UUID> = []

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
        guard scrollView.window == nil || deferredScrollRequestIDs.contains(requestID) else {
            deferredScrollRequestIDs.insert(requestID)
            DispatchQueue.main.async { [weak self] in
                _ = self?.attemptPendingScroll()
            }
            return true
        }
        scrollView.layoutIfNeeded()

        let targetOffset = Self.scorecardBottomOffset(
            contentSize: scrollView.contentSize,
            boundsSize: scrollView.bounds.size,
            adjustedContentInset: scrollView.adjustedContentInset,
            currentOffset: scrollView.contentOffset
        )
        guard let targetOffset else { return false }

        completedRequestIDs.insert(requestID)
        deferredScrollRequestIDs.remove(requestID)
        pendingRequestID = nil
        scrollView.setContentOffset(targetOffset, animated: false)
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
