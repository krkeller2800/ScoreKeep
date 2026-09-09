//
//  StartingLineupView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 6/4/25.
//

import SwiftUI
import SwiftData

struct StartingLineupView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var team: Team
    @State var game: Game
    @State var lineup: Lineup
    @Binding var showingDetail: Bool
    @State var numOfHitters = 9
    @State var updDateLineup = false
    @State private var editMode: EditMode = .active
    @State var linePlayers: [Player] = []
    @State private var lineupSlots: [LineupSlot] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State var searchText: String = ""
    @State private var isSearching = false
    @State private var showingAddPlayerDraft = false
    @State private var pendingAddPlayerSlot: Int?
    @State var navigationPath: NavigationPath = NavigationPath()

    @Query var atbats: [Atbat]
    @Query var lineups: [Lineup]
    @Query var players: [Player]

    var body: some View {
        GeometryReader { geometry in
            NavigationStack(path: $navigationPath) {
                List {
                    let nameWidth = geometry.size.width / 4
                    let smallWidth = geometry.size.width / 11
                    Text(instructionText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(UIDevice.type == "iPad" ? .title3 : .callout)
                        .foregroundStyle(ScoreKeepVisualStyle.primaryText)

                    HStack {
                        scorebookHeaderCell("Order")
                            .frame(width: smallWidth)
                        scorebookHeaderCell("Name")
                            .frame(width: nameWidth)
                        scorebookHeaderCell("Num")
                            .frame(width: smallWidth)
                        scorebookHeaderCell("Pos")
                            .frame(width: smallWidth)
                        scorebookHeaderCell("Dir")
                            .frame(width: smallWidth)
                        Text("").frame(width: 45)
                    }

                    ForEach(lineupSlots) { slot in
                        HStack {
                            Text(Double(slot.battingOrder), format: .number.rounded(increment: 1.0))
                                .frame(width: smallWidth, alignment: .center)
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                .bold()
                                .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            playerCell(for: slot, width: nameWidth)
                                .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                .padding(.leading, 0)
                            Text(slot.player.number)
                                .frame(width: smallWidth, alignment: .center)
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                .bold()
                                .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(slot.player.position)
                                .frame(width: smallWidth, alignment: .center)
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                .bold()
                                .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(slot.player.batDir)
                                .frame(width: smallWidth, alignment: .center)
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                .bold()
                                .overlay(Divider().background(ScoreKeepVisualStyle.separator), alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text("").frame(width: 25)
                        }
                        .moveDisabled(canReorderLineup == false)
                        .accessibilityHint(accessibilityHint(for: slot))
                    }
                    .onMove(perform: moveSlots)
                }
                .environment(\.editMode, $editMode)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onChange(of: sortOrder) {
                    refreshSlots(materializeIfNeeded: false)
                }
                .onChange(of: searchText) {
                    refreshSlots(materializeIfNeeded: false)
                }
                .onChange(of: players) {
                    handleRosterPlayersChanged()
                }
                .onAppear {
                    configureLineupMode()
                    refreshSlots(materializeIfNeeded: true)
                }
                .alert("Starting Lineup", isPresented: $showingAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("\(team.name) Lineup")
                            .font(.title2)
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name (A-Z)")
                                    .tag([SortDescriptor(\Player.name)])
                                Text("Name (Z-A)")
                                    .tag([SortDescriptor(\Player.name, order: .reverse)])
                                Text("Order (1-99)")
                                    .tag([SortDescriptor(\Player.batOrder)])
                                Text("Number (1-99)")
                                    .tag([SortDescriptor(\Player.number)])
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(updDateLineup ? "Upd Lineup" : "Save Lineup") {
                            finishLineup()
                        }
                        .frame(maxWidth: 135, maxHeight: 30, alignment: .center)
                        .background(ScoreKeepVisualStyle.selectedFill)
                        .border(ScoreKeepVisualStyle.separator)
                        .cornerRadius(10)
                        .accentColor(ScoreKeepVisualStyle.primaryText)
                        .padding(.horizontal, 10)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if UIDevice.type == "iPhone" {
                            Button(action: {
                                withAnimation {
                                    isSearching.toggle()
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if UIDevice.type != "iPhone" {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Player name or number", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .frame(width: 260)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Player name or number")
                        }

                        Button("Add Player", systemImage: "plus", action: addPlayers)
                            .accessibilityLabel("Add player")
                    }
                }
                .searchable(if: UIDevice.type == "iPhone" && isSearching, text: $searchText, placement: .automatic, prompt: "Player name or number")
                .sheet(isPresented: $showingAddPlayerDraft) {
                    NavigationStack {
                        AddPlayerDraftView(team: team) { savedPlayer in
                            assignSavedPlayer(savedPlayer, toPendingSlot: pendingAddPlayerSlot)
                        }
                    }
                    .standardAddPlayerPresentation()
                }
                .onChange(of: showingAddPlayerDraft) {
                    if showingAddPlayerDraft == false {
                        pendingAddPlayerSlot = nil
                    }
                }
                .onAppear {
                    isSearching = false
                }
                Spacer()
            }
        }
    }

    private var instructionText: String {
        if canReorderLineup {
            return "Hold and drag Players before scoring to change the batting order. Use the Player menu to correct an eligible lineup slot or add a new Player."
        }
        return "Players who have participated are locked. Use Replacement for substitutions."
    }

    private var canReorderLineup: Bool {
        Self.canReorder(slots: lineupSlots)
    }

    @ViewBuilder
    private func playerCell(for slot: LineupSlot, width: CGFloat) -> some View {
        if slot.isEditable {
            Menu {
                ForEach(playerMenuItems(for: slot)) { item in
                    switch item {
                    case .addPlayer:
                        Button {
                            pendingAddPlayerSlot = slot.battingOrder
                            showingAddPlayerDraft = true
                        } label: {
                            Label("Add Player…", systemImage: "plus")
                        }
                    case .player(let player, let isSelected):
                        Button {
                            selectPlayer(player, for: slot)
                        } label: {
                            PlayerMenuRowLabel(
                                player: player,
                                isSelected: isSelected
                            )
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(slot.player.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(width: width, alignment: .leading)
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .bold()
            }
            .accessibilityIdentifier("lineup-player-picker-\(slot.battingOrder)")
            .accessibilityLabel("Player for batting order \(slot.battingOrder)")
        } else {
            Text(slot.player.name)
                .frame(width: width, alignment: .leading)
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("lineup-player-locked-\(slot.battingOrder)")
        }
    }

    private func configureLineupMode() {
        if lineup.everyoneHits || game.everyOneHits {
            numOfHitters = 99
        } else {
            numOfHitters = 9
        }
    }

    private func refreshSlots(materializeIfNeeded: Bool) {
        do {
            if materializeIfNeeded {
                let result = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
                    game: game,
                    team: team,
                    modelContext: modelContext
                )
                lineup = result.lineup
                lineupSlots = result.slots
                updDateLineup = true
            } else {
                lineupSlots = LineupSlotSafetyCoordinator.resolvedSlots(
                    game: game,
                    team: team,
                    modelContext: modelContext
                )
                if let existingLineup = game.lineups.first(where: { $0.game.ident == game.ident && $0.team.ident == team.ident }) {
                    lineup = existingLineup
                    updDateLineup = true
                }
            }
            linePlayers = lineupSlots.map(\.player)
        } catch {
            lineupSlots = LineupSlotSafetyCoordinator.resolvedSlots(
                game: game,
                team: team,
                modelContext: modelContext
            )
            linePlayers = lineupSlots.map(\.player)
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func finishLineup() {
        if canReorderLineup {
            saveCurrentSlotOrder()
        } else {
            refreshSlots(materializeIfNeeded: false)
        }
        dismiss()
    }

    private func moveSlots(from indices: IndexSet, to newOffset: Int) {
        guard canReorderLineup else {
            alertMessage = "Batting order is locked after scoring begins."
            showingAlert = true
            return
        }
        lineupSlots.move(fromOffsets: indices, toOffset: newOffset)
        saveCurrentSlotOrder()
    }

    private func saveCurrentSlotOrder() {
        for (index, slot) in lineupSlots.enumerated() {
            let battingOrder = index + 1
            slot.player.batOrder = battingOrder
            slot.placeholderAtbat.batOrder = battingOrder
            slot.placeholderAtbat.seq = battingOrder
        }
        lineup.players = lineupSlots.map(\.player)
        do {
            try modelContext.save()
            refreshSlots(materializeIfNeeded: false)
        } catch {
            alertMessage = "ScoreKeep could not save this lineup order."
            showingAlert = true
        }
    }

    private func selectPlayer(_ player: Player, for slot: LineupSlot) {
        guard player.identifier != slot.player.identifier else { return }
        do {
            if canReorderLineup, let occupiedSlot = lineupSlots.first(where: { $0.battingOrder != slot.battingOrder && $0.player.identifier == player.identifier }) {
                try Self.swapPregamePlayers(
                    targetSlot: slot,
                    occupiedSlot: occupiedSlot,
                    lineup: lineup,
                    modelContext: modelContext
                )
            } else {
                if canReorderLineup {
                    _ = try Self.replacePregamePlayer(
                        in: slot,
                        to: player,
                        game: game,
                        team: team,
                        modelContext: modelContext
                    )
                } else {
                    _ = try LineupSlotSafetyCoordinator.reassignPlayer(
                        in: slot.battingOrder,
                        to: player,
                        game: game,
                        team: team,
                        modelContext: modelContext
                    )
                }
            }
            refreshSlots(materializeIfNeeded: false)
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
            refreshSlots(materializeIfNeeded: false)
        }
    }

    private func assignSavedPlayer(_ player: Player, toPendingSlot slot: Int?) {
        defer {
            pendingAddPlayerSlot = nil
            refreshSlots(materializeIfNeeded: false)
        }
        guard let slot else { return }
        do {
            let result = try LineupSlotSafetyCoordinator.reassignPlayer(
                in: slot,
                to: player,
                game: game,
                team: team,
                modelContext: modelContext
            )
            if canReorderLineup {
                result.incomingPlayer.batOrder = slot
                result.outgoingPlayer.batOrder = 99
                try modelContext.save()
            }
        } catch {
            alertMessage = "The Player was added to the roster, but this lineup slot can no longer be changed."
            showingAlert = true
        }
    }

    private func selectableRosterPlayers(for slot: LineupSlot) -> [Player] {
        Self.selectableRosterPlayers(from: players, slots: lineupSlots, targetSlot: slot, team: team)
    }

    private func playerMenuItems(for slot: LineupSlot) -> [StartingLineupPlayerMenuItem] {
        Self.playerMenuItems(from: players, slots: lineupSlots, targetSlot: slot, team: team, context: .startingLineupEditor)
    }

    static func playerMenuItems(
        from players: [Player],
        slots: [LineupSlot],
        targetSlot: LineupSlot,
        team: Team,
        context: StartingLineupPlayerMenuContext = .startingLineupEditor
    ) -> [StartingLineupPlayerMenuItem] {
        [.addPlayer] + selectableRosterPlayers(from: players, slots: slots, targetSlot: targetSlot, team: team, context: context).map { player in
            .player(player, isSelected: player.identifier == targetSlot.player.identifier)
        }
    }

    static func selectableRosterPlayers(
        from players: [Player],
        slots: [LineupSlot],
        targetSlot: LineupSlot,
        team: Team,
        context: StartingLineupPlayerMenuContext = .startingLineupEditor
    ) -> [Player] {
        let assignedPlayerIdentities = Set(slots
            .filter { $0.battingOrder != targetSlot.battingOrder }
            .map { $0.player.identifier })
        return players
            .filter { player in
                guard player.team?.ident == team.ident else { return false }
                switch context {
                case .startingLineupEditor:
                    return true
                case .scorecardSwapCorrection:
                    return true
                case .scorecardCorrection:
                    return player.identifier == targetSlot.player.identifier || assignedPlayerIdentities.contains(player.identifier) == false
                }
            }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.batOrder < $1.batOrder
            }
    }

    static func swapPregamePlayers(
        targetSlot: LineupSlot,
        occupiedSlot: LineupSlot,
        lineup: Lineup,
        modelContext: ModelContext
    ) throws {
        guard targetSlot.isEditable, occupiedSlot.isEditable else {
            throw LineupSlotSafetyError.slotLocked(.placeholderNotPristine)
        }

        let targetPlayer = targetSlot.player
        let occupiedPlayer = occupiedSlot.player
        targetSlot.placeholderAtbat.player = occupiedPlayer
        occupiedSlot.placeholderAtbat.player = targetPlayer
        occupiedPlayer.batOrder = targetSlot.battingOrder
        targetPlayer.batOrder = occupiedSlot.battingOrder

        let swappedSlots = LineupSlotSafetyCoordinator.resolvedSlots(
            game: lineup.game,
            team: lineup.team,
            modelContext: modelContext
        )
        lineup.players = swappedSlots.map(\.player)
        try modelContext.save()
    }

    static func replacePregamePlayer(
        in slot: LineupSlot,
        to player: Player,
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) throws -> LineupSlotReassignmentResult {
        let result = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: slot.battingOrder,
            to: player,
            game: game,
            team: team,
            modelContext: modelContext
        )
        result.incomingPlayer.batOrder = slot.battingOrder
        result.outgoingPlayer.batOrder = 99
        try modelContext.save()
        return result
    }

    static func canReorder(slots: [LineupSlot]) -> Bool {
        slots.isEmpty == false && slots.allSatisfy(\.isEditable)
    }

    private func accessibilityHint(for slot: LineupSlot) -> String {
        switch slot.editability {
        case .editable:
            return "Player identity can still be corrected for this lineup slot."
        case .locked:
            return lockExplanation(for: slot)
        }
    }

    private func lockExplanation(for slot: LineupSlot) -> String {
        switch slot.editability {
        case .editable:
            return ""
        case .locked(let reason):
            return Self.userVisibleLockExplanation(for: reason)
        }
    }

    static func userVisibleLockExplanation(for reason: LineupSlotLockReason) -> String {
        switch reason {
        case .placeholderNotPristine, .playerHasOtherAtbat, .acceptedScoringEvidence, .substitutionParticipation, .pitcherParticipation:
            return "This Player has participated in the game and can no longer be corrected as lineup entry."
        case .incomingPlayerUnavailable:
            return "That Player is already used in this game lineup."
        case .missingPlaceholder, .ambiguousLineupState, .duplicateLineupSlot, .duplicatePlayerAssignment, .persistenceEvidenceUnavailable:
            return "This lineup slot cannot be safely changed."
        }
    }

    static func resolvedLineupPlayers(savedLineup: Lineup?, atbats: [Atbat], fallbackPlayers: [Player], team: Team, game: Game) -> [Player] {
        if let savedPlayers = savedLineup?.players.sorted(by: { $0.batOrder < $1.batOrder }), !savedPlayers.isEmpty {
            return savedPlayers
        }
        let atbatPlayers = atbats
            .filter { $0.team == team && $0.game == game && $0.inning <= 1 && $0.col == 1 && $0.batOrder != 99 }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.seq < $1.seq
                }
                return $0.batOrder < $1.batOrder
            }
            .map { $0.player }
        if !atbatPlayers.isEmpty {
            return atbatPlayers
        }
        return fallbackPlayers.sorted(by: { $0.batOrder < $1.batOrder })
    }

    func addPlayers() {
        pendingAddPlayerSlot = nil
        showingAddPlayerDraft = true
    }

    init(showingDetail: Binding<Bool>, passedGame: Game, passedTeam: Team, theTeam: String = "", searchString: String = "", sortOrder: [SortDescriptor<Player>] = []) {
        _team = State(initialValue: passedTeam)
        _game = State(initialValue: passedGame)
        _lineup = State(initialValue: Lineup(everyoneHits: false, game: passedGame, team: passedTeam, inning: 1))
        _showingDetail = showingDetail
        _searchText = State(initialValue: searchString)
        if sortOrder.isEmpty == false {
            _sortOrder = State(initialValue: sortOrder)
        }
        let teamIdentity = passedTeam.ident
        _players = Query(filter: #Predicate { player in
            player.team?.ident == teamIdentity
        }, sort: self.sortOrder)
    }

    private func handleRosterPlayersChanged() {
        refreshSlots(materializeIfNeeded: false)
    }
}

enum StartingLineupPlayerMenuItem: Identifiable {
    case addPlayer
    case player(Player, isSelected: Bool)

    var id: String {
        switch self {
        case .addPlayer:
            return "add-player"
        case .player(let player, _):
            return player.identifier.uuidString
        }
    }
}

enum StartingLineupPlayerMenuContext {
    case startingLineupEditor
    case scorecardSwapCorrection
    case scorecardCorrection
}
