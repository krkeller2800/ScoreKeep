//
//  PlayersOnTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/22/25.
//
import SwiftUI
import SwiftData

struct PlayersOnTeamView: View {
    @Environment(\.modelContext) var modelContext

    @State var showHeader: Bool
    @State var pName: String = ""
    @State var pNum: String = ""
    @State var pPos: String = ""
    @State var pDir: String = ""
    @State var team: Team
    @State var pOrder: Int = 0
    @State var pTeam: Team?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var playerName = ""
    @State private var prevPName = ""
    @State private var dups = false
    @State private var checkForDups = true
    @State private var likelyDuplicatePlayer: Player?
    @State private var showingDuplicatePlayerAlert = false
    @State private var showingAddPlayerDraft = false
    let usesStandardPlayerAdd: Bool

    enum FocusField: Hashable {case field}

    @FocusState private var focusedField: FocusField?

    @Query var players: [Player]

    var body: some View {
        GeometryReader { geometry in
            List {
                let nameWidth =  geometry.size.width/4
//                let smallWidth =  geometry.size.width/12
                let mediumWidth =  geometry.size.width/9

                Section {
                    HStack {
                        scorebookHeaderCell("Order")
                            .frame(width:mediumWidth)
                        scorebookHeaderCell("Name")
                            .frame(width:nameWidth)
                        scorebookHeaderCell("Num")
                            .frame(width:mediumWidth)
                        scorebookHeaderCell("Pos")
                            .frame(width:mediumWidth)
                        scorebookHeaderCell("Dir")
                            .frame(width:mediumWidth)
                        Text("")
                            .frame(width:20)
                    }

                    if usesStandardPlayerAdd {
                        Button {
                            showingAddPlayerDraft = true
                        } label: {
                            Label("Add Player", systemImage: "plus")
                        }
                        .accessibilityLabel("Add player")
                    } else {
                        HStack {
                            Picker("Bat Order", selection: $pOrder) {
                                let orders = ["?","1st","2nd","3rd","4th",
                                              "5th","6th","7th","8th","9th",
                                              "10th","11th","12th","13th","14th",
                                              "15th","16th","17th","18th","19th"]
                                ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                                    Text(order).tag(index)
                                }
                                Text("Not Hitting").tag(99)
                            }
                            .frame(width:mediumWidth).labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent).lineLimit(1)
                                .minimumScaleFactor(0.5).padding(.leading,10)
                            TextField(" ", text: $pName, onEditingChanged: { (editingChanged) in
                                if !editingChanged {
                                    checkForDup(pname:pName)
                                }})
                            .frame(width: nameWidth)
                            .textFieldStyle(.roundedBorder).scorebookInputField().scorebookNameField()
                            .scorebookInputPromptOverlay("Player", isVisible: pName.isEmpty)
                            .accessibilityLabel("Player")
                            .focused($focusedField, equals: .field)
                            //                        .onAppear {self.focusedField = .field}
                            .textContentType(.name)
                            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                            TextField("(00)", text: $pNum, prompt: scorebookInputPrompt("(00)")).frame(width:mediumWidth)
                                .textFieldStyle(.roundedBorder).scorebookInputField()
                            TextField("(1B)", text: $pPos, prompt: scorebookInputPrompt("(1B)")).frame(width:mediumWidth)
                                .textFieldStyle(.roundedBorder).scorebookInputField()
                                .autocapitalization(.none)
                                .textContentType(.none)
                            TextField("(L)", text: $pDir, prompt: scorebookInputPrompt("(L)")).frame(width:mediumWidth)
                                .textFieldStyle(.roundedBorder).scorebookInputField()
                                .autocapitalization(.none)
                                .textContentType(.none)
                            HStack {
                                Spacer(minLength: 10)

                                Button {
                                    addPlayerCheckingForLikelyDuplicate()
                                } label: {
                                    Image(systemName: "plus")
                                }
                            }
                            .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                            .alert("Possible Duplicate Player", isPresented: $showingDuplicatePlayerAlert, presenting: likelyDuplicatePlayer) { matchedPlayer in
                                Button("Use Existing Player") {
                                    clearPendingPlayer()
                                }
                                Button("Update Existing Player") {
                                    updateExistingPlayer(matchedPlayer)
                                }
                                Button("Create New Player Anyway") {
                                    createPendingPlayer()
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: { player in
                                Text("A similar player already exists on \(team.name): \(duplicatePlayerSummary(player)).")
                            }

                        }
                    }
                    ForEach(players) { player in
                        NavigationLink(value: player) {
                            HStack {
                                Text(Double(player.batOrder), format: .number.rounded(increment: 1.0)).frame(width:mediumWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                    .scorebookTrailingSeparator().lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.name).frame(width: nameWidth, alignment: .leading).foregroundStyle(ScoreKeepVisualStyle.primaryText).lineLimit(1).minimumScaleFactor(0.5)
                                    .scorebookTrailingSeparator().padding(.leading, 0)
                                Text(player.number).frame(width:mediumWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                    .scorebookTrailingSeparator().lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.position).frame(width:mediumWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                    .scorebookTrailingSeparator().lineLimit(1).minimumScaleFactor(0.5)
                                Text(player.batDir).frame(width:mediumWidth, alignment: .center).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                                    .scorebookTrailingSeparator().lineLimit(1).minimumScaleFactor(0.5)
                                Spacer(minLength: 5)
                            }

                            .padding(.vertical, 0)
                        }
                        .onChange(of: player.batOrder) {
                            renumOrder(players: players.sorted{($0.batOrder < $1.batOrder)}, player: player, order: player.batOrder)
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
                header: {
                    if players.count > 0 && showHeader {
                        Text("Select a Player to edit").frame(maxWidth:.infinity, alignment:.leading).font(UIDevice.type == "iPhone" ? .callout : .title3).foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    }
                }
            }
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .background(ScoreKeepVisualStyle.background)
            .sheet(isPresented: $showingAddPlayerDraft) {
                NavigationStack {
                    AddPlayerDraftView(team: team)
                }
            }
        }
    }


    init(showHeader: Bool = true, team: Team, searchString: String = "", sortOrder: [SortDescriptor<Player>] = [], usesStandardPlayerAdd: Bool = false) {

        self.showHeader = showHeader
        self.team = team
        self.usesStandardPlayerAdd = usesStandardPlayerAdd
        let teamName = team.name
          _players = Query(filter: #Predicate { player in
              if searchString.isEmpty {
                  player.team?.name == teamName
              } else {
                  player.team?.name == teamName &&
                  (player.name.localizedStandardContains(searchString)
                  || player.number.localizedStandardContains(searchString))
              }
          },  sort: sortOrder)
      }

    func deletePlayer(at offsets: IndexSet) {
        for offset in offsets {
            let player = players[offset]
            if playedInGame(player: player) {
                showingAlert = true
                alertMessage = "\(player.name) is associated with game(s). Cannot delete."
            } else if pitchedInGame(player:player) {
                showingAlert = true
                alertMessage = "\(player.name) has pitched in a game. Cannot delete."
            } else {
                team.players.removeAll(where: {$0 == player})
                modelContext.delete(player)
            }
        }
        do {
            try modelContext.save()
        }
        catch {
            alertMessage = "Error deleting player: \(error.localizedDescription)"
            showingAlert = true
            print("Error deleting player: \(error.localizedDescription)")
        }
    }
    func playedInGame(player:Player)->Bool {


        var exist = false
        let pName = player.name

        if !pName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Atbat>()

            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existAtbats = try self.modelContext.fetch(fetchDescriptor)
                if existAtbats.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Atbats: \(error)")
            }
        }
        return exist
    }

    func pitchedInGame(player:Player)->Bool {

        var exist = false
        let pName = player.name

        if !pName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Pitcher>()

            fetchDescriptor.predicate = #Predicate { $0.player.name == pName }

            do {
                let existPitcher = try self.modelContext.fetch(fetchDescriptor)
                if existPitcher.first != nil {
                    exist = true
                } else {
                    exist = false
                }
            } catch {
                print("SwiftData Error fetching Games: \(error)")
            }
        }
        return exist
    }
    func checkForDup(pname:String) {

        if prevPName == pname {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let teamName = pTeam?.name ?? ""
        let playName = pname
        prevPName = playName

        if checkForDups {
            if !teamName.isEmpty && !playName.isEmpty {

                var fetchDescriptor = FetchDescriptor<Player>()

                fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName && $0.name == playName}

                do {
                    let existPlayers = try self.modelContext.fetch(fetchDescriptor)

                    if existPlayers.first != nil {
                        dups = true
                    } else {
                        dups = false
                    }
                } catch {
                    print("SwiftData Error: \(error)")
                }
            } else {
                if teamName.isEmpty && !playName.isEmpty {
                    showingAlert = true
                    alertMessage = "Please select a team so we can check if \(playName) is on already on it."
                }
            }
        }
    }

    func addPlayerCheckingForLikelyDuplicate() {
        guard !pName.isEmpty else {
            alertMessage = "Be sure to input a name for the new player."
            showingAlert = true
            return
        }

        if let likelyDuplicate = RosterImportReconciler.likelyMatchingPlayer(name: pName, number: pNum, in: players) {
            likelyDuplicatePlayer = likelyDuplicate
            showingDuplicatePlayerAlert = true
            return
        }

        createPendingPlayer()
    }

    func createPendingPlayer() {
        let maxOrder = players.map { $0.batOrder }.filter { $0 < 99 }.max() ?? 0
        let orderToAssign = pOrder == 0 ? maxOrder + 1 : pOrder
        let thisPlayer = Player(name: pName, number: pNum, position: CanonicalDefensivePosition.normalizedDisplayValue(for: pPos), batDir: pDir, batOrder: orderToAssign, team: team)
        modelContext.insert(thisPlayer)

        var currentPlayers = players
        if !currentPlayers.contains(where: { $0.id == thisPlayer.id }) {
            currentPlayers.append(thisPlayer)
        }

        try? self.modelContext.save()
        renumOrder(players: currentPlayers.sorted { $0.batOrder < $1.batOrder }, player: thisPlayer, order: orderToAssign)
        clearPendingPlayer()
    }

    func updateExistingPlayer(_ matchedPlayer: Player) {
        RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: matchedPlayer,
            name: pName,
            number: pNum,
            position: CanonicalDefensivePosition.normalizedDisplayValue(for: pPos),
            batDir: pDir,
            preserveHistoricalEvidence: false
        )
        try? self.modelContext.save()
        clearPendingPlayer()
    }

    func clearPendingPlayer() {
        pName = ""
        pOrder = 0
        pNum = ""
        pDir = ""
        pPos = ""
        dups = false
        likelyDuplicatePlayer = nil
    }

    func duplicatePlayerSummary(_ player: Player) -> String {
        let number = player.number.isEmpty ? "no number" : "#\(player.number)"
        let position = player.position.isEmpty ? "no position" : player.position
        return "\(player.name), \(number), \(position)"
    }

    func renumOrder(players:[Player], player:Player,order:Int) {
        for (index, oldPlayer) in players.enumerated() {
            if index+1 == order && oldPlayer.batOrder < 99 {
                oldPlayer.batOrder = index+2
            } else if index+1 > order && oldPlayer.batOrder < 99 {
                oldPlayer.batOrder = index+1
            }
            if oldPlayer.id == player.id {
                oldPlayer.batOrder = order
            }
        }
    }
}
